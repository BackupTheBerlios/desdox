/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */
#include <macros.h>
#include <events.h>
#include <access.h>
#include <assert.h>
#include <database.h>
#include <config.h>

#ifdef EVENT_DEBUG
#define DEBUG_EVENT(s, args...) werror(s+"\n", args)
#else
#define DEBUG_EVENT(s)
#endif

private static mapping   mEvents; // list of event listening objects
private static mapping mMyEvents; // list of events this object listens to
private static int           iID; // current id (will be used for next event)

private static int activity, activityNow, activitySegment;

object                   this();
object        get_environment();
int             get_object_id();
static void      require_save();
object         get_annotating();


/**
 * init_events() need to be called by create() in the inheriting object.
 * The function only initializes the event mappings.
 *  
 * @author Thomas Bopp 
 */
final static void 
init_events()
{
    iID       =     1;
    mEvents   = ([ ]);
    mMyEvents = ([ ]);
}

/**
 * This private function runs the event, called for phase-block and 
 * phase-notify separately.
 *  
 * @param listeners - the array of event-listeners
 * @return EVENT_BLOCK or EVENT_OK
 * @author Thomas Bopp 
 * @see event
 */
private final array(mixed)
run_events(int event, array(mixed) listeners, int phase, mixed args)
{
    int                i;
    string          call;
    object        caller;
    array(mixed) newlist;

    args = ({ this() }) + args;

    /* iterate through all listeners and notify about the event */
    newlist = ({ });
    for ( i = sizeof(listeners) - 1; i >= 0; i-- ) {
	if ( sizeof(listeners[i]) != 4 ) {
	    DEBUG_EVENT("Incorrect listener inside run_events() !");
	    continue;
	}
        
	if ( listeners[i][_EVENT_PHASE] == phase ) {
	    function f;

            DEBUG_EVENT("Listener match:"+i+"("+sprintf("%O",listeners[i])+")");
	    call   = listeners[i][_EVENT_FUNC];
	    caller = listeners[i][_EVENT_OBJECT];
	    if ( !objectp(caller) ) continue;
	    if ( !mappingp(caller->get_my_event(event, this())) ) {
		FATAL("Lost event ["+event+
		      "] in run_events() inside "+ get_object_id());
		continue;
	    }

	    f = caller->get_object()[call];
	    if ( !functionp(f) ) {
		DEBUG_EVENT("Event: function="+call + " not found inside " + 
		    caller->get_object_id()+"!");
		continue;
	    }
	    newlist += ({ listeners[i] });
	    if ( phase == PHASE_BLOCK ) {
		/* need write access to block event */
		if ( f(event, @args) == EVENT_BLOCKED ) {
		    DEBUG_EVENT("Event blocked...");
		    throw( ({ "Event blocked!", backtrace() }) );
		}
	    }
	    else {
		/* need read access to hear event */
		mixed err = catch {
		    f(event, @args);
		}; // no throw in listening
		if ( err != 0 ) {
		    MESSAGE("Error while listening to event:\n"+
			    err[0]+"\n"+PRINT_BT(err));
		}
	    }
	}
	else {
	    newlist += ({ listeners[i] });
	}
    }
    return newlist;
}

/**
 * A function calls event() to define a new event. Other objects are then
 * able to listen or block this event. Callback functions always include
 * the event-type as first parameter, because it is possible to use
 * one event function for several events. This function is to be used
 * in own program code to allow other objects to block actions which 
 * are currently taking place. 
 * The try_event() call should be before the action actually took place, 
 * because there is no rollback functionality.
 *  
 * @param event - the type of the event, all events are located in events.h
 * @param args - number of arguments for that event
 * @return ok or blocked
 * @see add_event
 * @see run_events
 * @see run_event
 */
final static void
try_event(int event, mixed ... args)
{
    array(mixed) listeners;

    if ( event == 0 ) return;
    if ( !objectp(this()) ) return; // object not ready yet (eg being created)

    listeners = mEvents[event];
    _Server->run_global_event(event, PHASE_BLOCK, this(), args);
    if ( !arrayp(listeners) ) return;

    DEBUG_EVENT("Event:"+event+" /Listeners="+ sizeof(listeners));
    /* first all blocking events must run */
    mEvents[event] = run_events(event, listeners, PHASE_BLOCK, args);
    require_save();
}

/**
 * Call this function to run an event inside this object. The integer
 * event type is the first argument and each event has a diffent number
 * of arguments. The difference to try_event is that run_event cannot be
 * blocked. This function is to be used in own program code. It makes
 * add_event possible for other objects to be notified about the action
 * which currently takes place.
 *  
 * @param int event - the event to fire
 * @param mixed ... args - a list of arguments for this individual event
 * @see try_event
 * @see run_events
 */
final static void
run_event(int event, mixed ... args)
{
    array(mixed) listeners;

    if ( event == 0 ) return;
    if ( !objectp(this()) ) return; // object no ready yet !

    listeners = mEvents[event];
    _Server->run_global_event(event, PHASE_NOTIFY, this(), args);  

    DEBUG_EVENT("Event:"+event+" /Listeners="+ 
		(arrayp(listeners)?sizeof(listeners): ""));
    /* now the listeners can be notified */
    if ( arrayp(listeners) )
	mEvents[event] = run_events(event, listeners, PHASE_NOTIFY, args);
    require_save();
    //let the environment be notified about the event,if not allready monitored
    object env = get_environment();
    //if ( !(event & EVENTS_MONITORED ) && objectp(env) )
    if ( objectp(env) )
	env->monitor_event(event, this(), @args);
    
    // for our annotating object also monitor...
    object annotates = this_object()->get_annotating();
    if ( objectp(annotates) )
	annotates->monitor_event(event, this(), @args);
}

/**
  * this functions monitors the attributes of the objects in
  * the containers inventory and fires a EVENT_ATTRIBUTES|EVENTS_MONITORED
  * event.
  *  
  * @param obj - the monitored object
  * @param caller - the object calling set_attribute in 'obj'
  * @param args - some args, like key and value
  * @author Thomas Bopp (astra@upb.de) 
  */
void monitor_event(int event, object obj, object caller, mixed ... args)
{
    if ( !functionp(obj->get_object_id) ||
	 CALLER->get_object_id() != obj->get_object_id() ) 
	return;

    if ( event & EVENTS_MONITORED )
        run_event(event, obj, @args);
    else	
        run_event(event|EVENTS_MONITORED, this(), obj, @args);
}



/**
 * Add a new event to this object. The listener object needs to define
 * a callback function. The call will then include some parameters of which
 * the first will always be the event-type.
 * Do not call this function yourself. Call add_event instead, otherwise
 * the data structure that connects listener object and event object will
 * be invalid.
 *  
 * @param type - the event type to add
 * @param callback - the function to call when event happens
 * @return id of the event or FAIL (-1)
 * @author Thomas Bopp 
 * @see remove_event
 */
final int 
listen_event(int event, int phase, function callback)
{
    if ( !functionp(callback) )
        return 0;
    string fname = function_name(callback);
    object obj = function_object(callback);

    try_event(EVENT_LISTEN_EVENT, CALLER, event, phase);
    obj = obj->this(); // get proxy
    
    DEBUG_EVENT("new event.... = "+ event + " on "+get_object_id());
    iID++;
    if ( !arrayp(mEvents[event]) )
	mEvents[event] = ({ });
    foreach( mEvents[event], array edata ) {
      if ( edata[0] == fname && edata[2] == phase && edata[3] == obj ) {
	// already in event list
	run_event(EVENT_LISTEN_EVENT, CALLER, event, phase);
	return 0;
      }
    }
    mEvents[event] += ({ ({ fname, iID, phase, obj }) });

    run_event(EVENT_LISTEN_EVENT, CALLER, event, phase);
    require_save();
    return iID;
}

/**
 * This is the most central function to be used for subscribing events.
 * Add an event to object obj, the event will be stored in the local 
 * event list. The callback function will be called with the event-id
 * (in case there is one callback function used for multiple events),
 * then the object is provided where the event took place and a number
 * of parameters are passed depending on the event.
 * callback(event-id, object, params)
 *  
 * @param obj - the object to listen to
 * @param event - the event type
 * @param phase - notify or block phase
 * @param callback - the callback function
 *
 * @return event id or fail (-1), but usually will throw an exception
 * @see listen_event
 */
static int 
add_event(object obj, int event, int phase, function callback)
{
    int         res;
    mixed     edata;
    string     func;
    object func_obj;

    if ( phase == PHASE_BLOCK )
	_SECURITY->access_write(this_object(), CALLER);
    else
	_SECURITY->access_read(this_object(), CALLER);

    func = function_name(callback);
    func_obj = function_object(callback);
    func_obj = func_obj->this();

    ASSERTINFO(func_obj->is_function(func),
	       "No add_event() on private functions");
    ASSERTINFO(_SECURITY->valid_proxy(obj), "No add event on non proxies !");

    /* the key for mMyEvents is event/obj/callback */
    if ( !mappingp(mMyEvents[event]) )
	mMyEvents[event] = ([ ]);
    if ( !mappingp(mMyEvents[event][obj]) )
	mMyEvents[event][obj] = ([ ]);

    /* mMyEvents contains all objects and events this object listens to */
    edata = mMyEvents[event][obj][func];

    array obj_event_arr = obj->get_event(event);
    if ( arrayp(edata) ) {
	// check destination!
	foreach(obj_event_arr, array d) {
	    if ( d[_EVENT_PHASE] == phase && d[_EVENT_OBJECT] == this() ) {
	        res = obj->listen_event(event, phase, callback);
		edata[1]++; // one more event on same callback function
		require_save();
		return edata[0];
	    }
	}
	mMyEvents[event][obj] = ([ ]);
    }

    if ( arrayp(obj_event_arr) ) {
        foreach(obj_event_arr, array oed) {
            if ( !arrayp(oed) ) continue;

            if ( oed[_EVENT_PHASE] == phase && oed[_EVENT_OBJECT] == this() ) 
	    {
	       mMyEvents[event][obj][func] = ({ oed[_EVENT_ID], 1 });
	       res = obj->listen_event(event, phase, callback);
               return oed[_EVENT_ID];
            }
        }
    }
                 
    res = obj->listen_event(event, phase, callback);

    if  ( res != FAIL ) {
	/* new event/obj/callback combination, set only once (1) */
	mMyEvents[event][obj][func] = ({ res, 1 });
    }
    require_save();
    return res;
}

/**
 * remove an event, it is removed from the object and this object
 * only the local function for remove and add should be called.
 * Event-type, function and object are the identifier for an object.
 * No object should listen to an event through one callback function twice.
 * 
 *  
 * @param obj - the object to listen to
 * @param event - the type of event
 * @param id - function or identifier
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see ignore_event
 */
final static bool remove_event(object obj, int event, function|int id) 
{
    bool            res;
    int               i;
    int         eventID;
    mixed         edata;
    string         func;

    /* event does not exists */
    if ( !mappingp(mMyEvents[event]) || !mappingp(mMyEvents[event][obj]) )
	return false;

    /* remove by function pointer, if no functionp is given search
     * it by the given event-id */
    if ( functionp(id) ) {
	func = function_name(id);
    }
    else {
	array(string) f_index;
	f_index = indices(mMyEvents[event][obj]);
	for ( i = sizeof(f_index) - 1; i >= 0; i-- ) {
	    if ( mMyEvents[event][obj][func] == id ) 
		break;
	    func = 0;
	}
    }
    if ( !stringp(func) )
	return false; // at this point cb must be a valid functionp
    edata = mMyEvents[event][obj][func];
    if ( !arrayp(edata) )
	return false;

    /* see if it is the last reference to event/obj/callback */
    if ( --edata[_MY_EVENT_NUM] == 0 ) {
	/* in this case remove the key completely */
	eventID = mMyEvents[event][obj][func][_MY_EVENT_ID];
	m_delete(mMyEvents[event][obj], func);
	res = obj->ignore_event(event, eventID);
	if ( sizeof(mMyEvents[event][obj]) == 0 )
	    m_delete(mMyEvents[event], obj); // delete the object from map
	
	require_save();
	return res;
    }
    require_save();
    return true;
}

/**
 * remove all events of the object. This function exists only for
 * debug purposes.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see remove_event
 */
final static void
remove_all_events()
{
    int             i, j, k;
    int                  id;
    array(int)       events;
    array(object) eventObjs;
    array(string)       cbs;
    
    if ( !mappingp(mMyEvents) )
	return; 
    events = indices(mMyEvents);
    for ( i = sizeof(events) - 1; i >= 0; i-- ) {
	eventObjs = indices(mMyEvents[events[i]]);
	for ( j = sizeof(eventObjs) - 1; j >= 0; j-- ) {
            if ( !objectp(eventObjs[j]) ) continue;
	    cbs = indices(mMyEvents[events[i]][eventObjs[j]]);
	    for ( k = sizeof(cbs) - 1; k >= 0; k-- ) {
		id = mMyEvents[events[i]][eventObjs[j]][cbs[k]][_EVENT_ID];
		eventObjs[j]->ignore_event(events[i], id);
	    }
	}
    }
    mMyEvents = ([ ]);
    require_save();
}

/**
 * Listener object removes an event. The event id is what add_event()
 * returns. Usually the function shouldnt be called. It is called
 * automatically, when the function remove_event() is called.
 *  
 * @param event - the type of event
 * @return true or false
 * @author Thomas Bopp 
 * @see add_event
 * @see remove_event
 */
final bool ignore_event(int event, int id)
{
    int         i;
    string   call;
    object caller;

    if ( event == 0 )
	return false;

    if ( !arrayp(mEvents[event]) )
	return false;
    try_event(EVENT_IGNORE_EVENT, CALLER, event, id);

    /* remove the event by the event-id */
    for ( i = sizeof(mEvents[event]) - 1; i >= 0; i-- ) {
	if ( mEvents[event][i][_EVENT_ID] == id ) {
	    call   = mEvents[event][i][_EVENT_FUNC];
	    caller = mEvents[event][i][_EVENT_OBJECT];

	    if ( !_SECURITY->access_write(caller, CALLER) )
		return false;
	    mEvents[event] -= ({ mEvents[event][i] });

	    run_event(EVENT_IGNORE_EVENT, CALLER, event, id);
	    require_save();
	    return true;
	}
    }
    return false;
}

/**
 * The function updates the events of this object, remove wrong events
 * and events that failed to have read- or write-access. This situation
 * might occure, when the ACL changes. 
 *  
 * @param event - what event to update
 * @author Thomas Bopp (astra@upb.de) 
 */
void update_events(int event)
{
    int                            i;
    array      new_listeners = ({ });
    array listeners = mEvents[event];
    object                    caller;
    string                      call;
    function                       f;
    
    if ( !arrayp(listeners) )
	return;

    for ( i = sizeof(listeners) - 1; i >= 0; i-- ) {
	if ( sizeof(listeners[i]) == 4 ) {
	    call   = listeners[i][_EVENT_FUNC];
	    caller = listeners[i][_EVENT_OBJECT];
	    if ( !objectp(caller) ) continue;
	    if ( !functionp(caller->find_function) ) continue;
	    
	    f = caller->find_function(call);
	    if ( functionp(f) ) {
		if ( listeners[i][_EVENT_PHASE] == PHASE_BLOCK ) {
		    /* need write access to block event */
		    if ( _SECURITY->access_write(this_object(), caller) )
			new_listeners += ({ listeners[i] });
		}
		else {
		    if ( _SECURITY->access_read(this_object(), caller) )
			new_listeners += ({ listeners[i] });
		}
	    }
	}
    }
    mEvents[event] = new_listeners;
    require_save();
}

/**
 * This function updates all events and calls the update_events()
 * function for every event bit.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see update_events
 */
static void update_all_events()
{
    for ( int i = 0; i < 32; i++ )
	update_events((1<<i));
}

/**
 * Get a list of listening objects. The returned mapping is in the form
 * event: array of listening objects.
 *  
 * @return list of listening objects
 * @author Thomas Bopp (astra@upb.de) 
 * @see get_my_events
 */
final mapping get_events()
{
    foreach(indices(mEvents), int event) {
	array(mixed) listeners = mEvents[event];
	array(mixed) nlisteners = ({ });
	
	for ( int i = 0; i < sizeof(listeners); i++ )
	    if ( sizeof(listeners[i]) > 0 )
		nlisteners += ({ listeners[i] });
	mEvents[event] = copy_value(nlisteners);
    }

    return copy_value(mEvents);
}

/**
 * Returns the mapping entry for a given event. For example the function
 * could be called with get_event(EVENT_MOVE). Check the file include/events.h
 * for a list of all events.
 *  
 * @param int event - the event to return
 * @return array of listening objects
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_events
 */
final array get_event(int event)
{
    return copy_value(mEvents[event]);
}


/**
 * Get a list of events this object listens to. 
 *  
 * @return list of events this objects listens to
 * @author Thomas Bopp (astra@upb.de) 
 * @see get_events
 */
final mapping get_my_events()
{
    return copy_value(mMyEvents);
}

/**
 * Get the mapping of events subscribed on object 'where' or 0 if there is
 * no entry of 'event'.
 *  
 * @param int event - the event
 * @param object where - The object to check for subscription
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
final mapping get_my_event(int event, object where)
{
    if ( !mappingp(mMyEvents[event]) )
	return 0;
    return copy_value(mMyEvents[event][where]);
}

/**
 * restore the events of an object
 *  
 * @param data - the event data for the object
 * @author Thomas Bopp (astra@upb.de) 
 * @see retrieve_events
 */
final void
restore_events(mixed data)
{
    ASSERTINFO(CALLER == _Database, "Invalid call to restore_data()");
    
    
    mEvents   = data["Events"];
    mMyEvents = data["MyEvents"];
    iID       = data["ID"];
    require_save();
}


/**
 * retrieve the event data of the object
 *  
 * @return the events of the object
 * @author Thomas Bopp (astra@upb.de) 
 * @see restore_events
 */
final mapping
retrieve_events()
{
    ASSERTINFO(CALLER == _Database, "Invalid call to retrieve_events()");
    return ([
	"Events":mEvents,
	"MyEvents":mMyEvents,
	"ID":iID, 
	]);
}

