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

//#define PROFILING
 
#include <macros.h>
#include <exception.h>
#include <database.h>
#include <events.h>

//private int PROFILING;
private static object oSteamObj, eventLog;
public  object oNext, oPrev;
private static int iOID;
private static int iStatus;
//private static int tStamp;

/*
 * @function create
 *           create a proxy for a sTeam-Object
 * @returns  void (is a constructor)
 * @args     int _id     - the object ID of the associated object
 *           int init    - create proxy only, or create new object
 *           string prog - class for the associated object
 */
final void create(int _id, object|void oTrue)
{
    iStatus = PSTAT_DISK;
    iOID = _id;
    if (objectp(oTrue))
    {
	oSteamObj = oTrue;
	iStatus = PSTAT_SAVE_OK;
    }
    master()->append(this_object());
    //    tStamp = time();

#ifdef PROFILING
    eventLog =_Server->get_module("event_log");
    if ( objectp(eventLog) ) eventLog = eventLog->get_object();
#endif

}

/**
 * @function get_object_id
 * @returns  int (the object id to the associated object)
 */
final int get_object_id()
{
    return iOID;
}

final void set_steam_obj(object o)
{
    if (CALLER == _Database && !objectp(oSteamObj))
	oSteamObj = o;
}

/*int get_access_time()
{
    return tStamp;
}
*/

/**
 * set the status of the proxy. Changes can only be done by the server
 * and database object.
 *
 * @param int _status - new status to set
 * @see status
 * @author Ludger Merkens 
 */
final void set_status(int _status)
{
    if (CALLER == _Database || CALLER == _Server)
	iStatus = _status;
    //LOG_DB("status set to:"+iStatus+" by "+CALLERCLASS);
}

private static int i_am_in_backtrace()
{
    foreach(backtrace(), mixed preceed)
    {
        if (function_object(preceed[2]) == oSteamObj)
            return 1;
    }
    return 0;
}

/**
 * Drop the corresponding steam object.
 *  
 * @return 0 or 1 depending if the drop is successfull.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final int drop()
{
    // if (iDirty)
    //    _Database->low_save_object ...
    //if ( (CALLER != _Database) && (CALLER!=master()))
    //	THROW("Drop can only be called by database !", E_ACCESS);
    if ( !objectp(oSteamObj) || iStatus == PSTAT_SAVE_PENDING)
    {
        LOG(sprintf("didn't drop %d because PSTAT_SAVE_PENDING\n", iOID));
        return 0;
    }
#if 1
    if ( i_am_in_backtrace()) // don't drop an object wich is a caller
    {
        LOG("rejected object "+iOID+" because it was in backtrace.\n");
        return 0;
    }
#endif
    // the object should also be removed from memory ?!
    destruct(oSteamObj);
    oSteamObj = 0;
    master()->got_dropped(this_object());
    iStatus = PSTAT_DISK;
    return 1;
}

/**
 * Find a function inside the proxy object.
 *  
 * @param string fun - the function to find
 * @return a functionp of the function or 0
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final function find_function (string fun)
{
    return (objectp(oSteamObj) ? oSteamObj[fun] : 0);
}

mapping (string:mixed) fLocal = ([
    "get_object_id" : get_object_id,
    "set_status": set_status,
    "drop" : drop,
    "find_function" : find_function,
    "set_steam_obj": set_steam_obj,
    "destroy": destroy,
    "status" : status,
    "get_object" : get_object,
    //    "get_access_time": get_access_time,
]);
    
/**
 * `->() The indexing operator is replaced in proxy.pike to redirect function
 * calls to the associated object.
 * @param  string func - the function to redirect
 * @return mixed - usually the function pointer to the function in question
 *                 __null() in case of error
 * @see    __null
 * @see    find_function
 * @author Ludger Merkens 
 */
final mixed `->(string func)
{
    function    f;
    mapping mData;
    string   line;
    mixed catched;

    
    if (!oSteamObj) {
	mixed load;

        if ((f = fLocal[func]) && (func!="get_object")){
	  return f;
	}

        load = _Database->load_object(iOID);

	if ( load == 1 )
	{
	    iStatus = PSTAT_FAIL_COMPILE;
	    LOG(" !! Failed to load object: " + iOID);
	}
	else if ( load == 0 )
	{
	    iStatus = PSTAT_FAIL_DELETED;
	    LOG("Object ("+iOID+") not present in Database - deleted !\n");
	}
        else if (load == 2)
        {
            //destruct(this_object());
            iStatus = PSTAT_FAIL_COMPILE;
            //            return 0;
        }
	if (!objectp(oSteamObj)) {
	    return __null;
	}
	//LOG("loaded "+iOID+" "+oSteamObj->get_identifier());
	iStatus = PSTAT_SAVE_OK;
        master()->got_loaded(this_object());
        if ( func == "get_object" )
            return get_object;
    }
    if (f = fLocal[func])
        return f;

    //    tStamp = time();
    if ( !(f = oSteamObj[func]) )
    {
	LOG("Calling undefined function: "+func+" in " + 
	    master()->describe_object(oSteamObj) +"("+iOID+")" );
	return __null;
    }

#ifdef PROFILING
    /*profiling code by psycho@upb.de*/
    array trace_line;
    array bt = backtrace();
    
    if(objectp(eventLog)){
      foreach( bt , trace_line ) {
	if( function_object(trace_line[2]) == eventLog ) 
	    return f;
      }
	eventLog->profile(this_object(), func, Thread.this_thread());
    }

    /*profiling code end*/
#endif

    if (func == "get_identifier")
        master()->front(this_object());
    return f;
}

/**
 * dummy function, replacing a broken function, in case of error
 * @param none
 * @return 0
 * @see   `->() 
 * @author Ludger Merkens 
 */
final mixed __null()
{
    return 0;
}

/**
 * get the associated Object from this proxy
 * @param   none
 * @return  object | 0
 * @see    set_steam_obj
 * @see    _Database.load_object
 * @author Ludger Merkens 
 */
final object get_object()
{
    return oSteamObj;
}

/**
 * Called when the object including the proxy are destructed.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void destroy()
{
    master()->remove(this_object());
}

/**
 * 
 * The function returns the status of the proxy, which is actually
 * the status of the corresponding object.
 *
 * @param  none
 * @return PSTAT_DISK             ( 0) - on disk
 *         PSTAT_SAVE_OK          ( 1) - in memory
 *         PSTAT_SAVE_PENDING     ( 2) - in memory, but dirty (not implemented)
 *         PSTAT_FAIL_COMPILE     (-1) - failed to load (compilation failure)
 *         PSTAT_FAIL_UNSERIALIZE (-2) - failed to load (serialization failure)
 *         PSTAT_FAIL_DELETED     (-3) - failed to load (deleted from database)
 * @see    database.h for PSTAT constants.
 * @author Ludger Merkens 
 */
final int status()
{
    if (iStatus <0)
	return iStatus;
    if (!objectp(oSteamObj))
	return 0;
    
    return iStatus;
}

string _sprintf()
{
    return "/kernel/proxy.pike("+iOID+"/"+
        ({ "PSTAT_FAIL_DELETED", "PSTAT_FAIL_UNSERIALIZE" ,
           "PSTAT_FAIL_COMPILE", "PSTAT_DISK", "PSTAT_SAVE_OK",
           "PSTAT_SAVE_PENDING" })[iStatus+3]+")";
}
