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

//! Each Object in sTeam is derived from this class


/** @defgroup attribute 
 *  Attribute functions
 */
    


inherit "/base/access"       : __access;
inherit "/base/events"       : __events;
inherit "/base/annotateable" : __annotateable;
inherit "/base/references"   : __references;

#include <macros.h>
#include <attributes.h>
#include <classes.h>
#include <access.h>
#include <events.h>
#include <assert.h>
#include <functions.h>
#include <database.h>
#include <types.h>

private static  mapping        mAttributes; /* attribute mapping of object */
private static  mapping mAttributesAcquire;
private static  mapping  mAttributesLocked;

static  int              iObjectID; /* Database ID of object */
static  object        oEnvironment; /* the environment of the object */
private object              oProxy; /* the corresponding pointer object */
static  string         sIdentifier; /* the identifier of the object */
private array(object)    aoTrusted; /* list of trusted objects - not used */
private static function  fGetEvent; /* cache function to get event for attr */

// temporary for conversion
static mapping m_conversion = 
([ 101:"obj:owner", 102:"obj:name", 104:"obj:description", 105:"obj:icon",
   111:"obj:keywords", 113:"obj:position:x", 114:"obj:position:y",
   115:"obj:position:z", 116:"obj:last_changed", 119:"obj:creation_time",
   207:"doc:type", 208:"doc:mimetype", 213:"doc:user_modified",
   214:"doc:last_modified", 215: "doc:last_accessed", 216: "doc:extern_url",
   217:"doc:times_read", 218:"doc:image:rotation", 219:"doc:image:thumbnail",
   220:"doc:image:sizex", 221:"doc:image:sizey",
   300:"cont:sizex", 301:"cont:sizey", 302:"cont:sizez", 
   303:"cont:exchange_links",
   401:"exit:to", 
   500:"group:membership_reqs", 501:"group:exits", 502:"group:maxsize",
   503:"group:msg_accept", 504:"group:maxpending", 800:"group:workroom",
   801:"group:exclusive_subgroups",
   611:"user:adress", 612:"user:fullname", 613:"user:mailbox", 
   614:"user:workroom", 615:"user:last_login", 616:"user:email",
   617:"user:umask", 618:"user:mode", 619:"user:mode:msg",
   620:"user:last_logout_place", 621:"user:trashbin",
   622:"user:bookmarkroom", 623:"user:forward_msg",
   700:"drawing:type", 701:"drawing:width", 702:"drawing:height",
   703:"drawing:color",704:"drawing:thickness", 705:"drawing:filled",
   900:"link:target", 
   1000:"lab:tutor", 1001:"lab:size", 1002:"lab:room", 1003:"lab:apptime",
   ]);
   

mixed set_attribute(mixed index, mixed data);

/**
 * create_object() is the real constructor, not called when object is loaded
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see create
 */
static void create_object()
{
}

/**
 * Called after the object was created. Then calls create_object() which 
 * actually is the function to be overwritten.
 *
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create
 * @see create_object
 */
final void created()
{
    if ( MCALLER != _Database && MCALLER != _Server && 
	 !(get_object_class() & CLASS_FACTORY) &&
	 !_Server->is_factory(MCALLER) &&
	 !_SECURITY->access_create_object(MCALLER) ) 
    {
	LOG("Calling object is not a factory !");
	THROW("Security violation while creating object", E_ACCESS);
    }
    create_object();
    load_object();
}


/**
 * init the object, called when object is constructed _and_ loaded
 * Notice during this function, the object ID of the object is not yet
 * valid. See load_object for a function that will be called after the
 * object id is valid.
 *
 * @author Thomas Bopp (astra@upb.de) 
 * @see create
 * @see load_object
 */
static void 
init()
{
    init_events();
    init_access();
    init_annotations();
    init_references();
    aoTrusted = ({ }); // array of trusted objects

    add_data_storage(retrieve_access_data, restore_access_data);
    add_data_storage(retrieve_data, restore_data);
    add_data_storage(retrieve_events, restore_events);
    add_data_storage(retrieve_annotations, restore_annotations);
    add_data_storage(store_references, restore_references);
}

/**
 * Called after the Database has loaded the object data.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see loaded
 */
static void load_object()
{
}


/**
 * Database calls this function after loading an object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see upgrade
 * @see init
 */
final void loaded()
{
    if ( CALLER != _Database && CALLER != _Server )
	THROW("Illegal Call to loaded() !", E_ACCESS);
    load_object();
}

/**
 * See if this object can be dropped (swapping)
 *  
 * @return can this object be swapped out or not.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool check_swap() { return true; }
bool check_upgrade() { return true; }


/**
 * Master calls this function in each instance when the class is upgraded.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 */
void upgrade()
{
}  


/** 
 * This is the constructor of the object.
 *
 * @param string|object id - the name of the object if just created,
 *                           or the proxy 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>
 */
final static void 
create(string|object id)
{
    if ( MCALLER != _Database && MCALLER != _Server && 
	 !(get_object_class() & CLASS_FACTORY) &&
	 !_Server->is_factory(MCALLER) &&
	 !_SECURITY->access_create_object(MCALLER) ) 
    {
	FATAL("-- Calling object is not a factory ! - aborting creation!");
	THROW("Security violation while creating object", E_ACCESS);
    }

    mAttributes        = ([ ]); 	
    mAttributesAcquire = ([ ]);
    mAttributesLocked  = ([ ]);

    init();

    if ( objectp(id) ) { // object is newly loaded
	oProxy = id;
	iObjectID = oProxy->get_object_id();
	sIdentifier = "object";
    }
    else 
    {
	[ iObjectID, oProxy ] = _Database->new_object();
	sIdentifier = id;
	database_registration(id);
	MESSAGE("Created as " + iObjectID);
    }
}      

/**
 * Save the object. This call is delegated to the Database singleton.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void require_save()
{
    _Database->require_save();
    mAttributes[OBJ_LAST_CHANGED] =  time();
}


/**
 * Duplicate an object - that is create a copy, the permisions are
 * not copied though.
 *  
 * @return the copy of this object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create
 */
object duplicate(void|mapping vars)
{
    try_event(EVENT_DUPLICATE, CALLER);
    object factory = _Server->get_factory(get_object_class());
    mapping attr = copy_value(mAttributes);
    foreach(indices(attr), mixed idx) {
	if ( mAttributesAcquire[idx] != 0 )
	    attr[idx] = 0;
    }
    mapping exec_vars = 
	([ "name": do_query_attribute(OBJ_NAME), "attributes":attr, 
	 "attributesAcquired": mAttributesAcquire,
	 "attributesLocked": mAttributesLocked, ]);
    if ( mappingp(vars) )
	exec_vars += vars;
    object dup_obj = factory->execute( exec_vars );

    
    run_event(EVENT_DUPLICATE, CALLER);
    return dup_obj;
}

/**
 * currently no idea what this function is good for ... maybe comment
 * directly when writing the code ?
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 */
static void database_registration(string name)
{
}

/**
 * This is the destructor of the object - the object will be swapped out.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see delete_object
 */
final void
destroy()
{
}

/**
 * Set the event for a specific attribute.
 *  
 * @param key - the key of the attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see set_attribute
 * @ingroup attribute
 */
final void 
lock_attribute(int|string key)
{
    try_event(EVENT_ATTRIBUTES_LOCK, CALLER, key, true);
    mAttributesLocked[key] = true;
    run_event(EVENT_ATTRIBUTES_LOCK, CALLER, key, true);
    require_save();
}

/**
 * Unlock all attributes. 
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see lock_attribute
 * @ingroup attribute
 */
final void unlock_attributes()
{
    try_event(EVENT_ATTRIBUTES_LOCK, CALLER, 0, true);
    mAttributesLocked = ([ ]);
    run_event(EVENT_ATTRIBUTES_LOCK, CALLER, 0, true);    
    require_save();
}

/**
 * Set the event for a specific attribute.
 *  
 * @param key - the key of the attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see set_attribute
 * @ingroup attribute
 */
final void 
unlock_attribute(int|string key)
{
    try_event(EVENT_ATTRIBUTES_LOCK, CALLER, key, false);
    m_delete(mAttributesLocked, key);
    run_event(EVENT_ATTRIBUTES_LOCK, CALLER, key, false);
    require_save();
}

/**
 * Returns whether an attribute is locked or not. Attributes can be locked
 * to keep people from moving objects around (for example coordinates)
 *  
 * @param mixed key - the attribute key to check
 * @return locked or not
 * @ingroup attribute
 */
bool is_locked(mixed key)
{
    return mAttributesLocked[key];
}

/**
 * Each attribute might cause a different event to be fired, get
 * the one for changing the attribute.
 *  
 * @param int|string key - the attribute key
 * @return the corresponding event 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @ingroup attribute
 * @see get_attributes_read_event
 */
int get_attributes_change_event(int|string key)
{
   object factory = _Server->get_factory(get_object_class());
   if ( objectp(factory) )
       return factory->get_attributes_change_event(key);
    return EVENT_ATTRIBUTES_CHANGE;
}

/**
 * Each attribute might cause a different event to be fired, get
 * the one for reading the attribute.
 *  
 * @param int|string key - the attribute key
 * @return the corresponding event 
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_attributes_read_event
 */
int get_attributes_read_event(int|string key)
{
    if ( !functionp(fGetEvent) ) {
        object factory = _Server->get_factory(get_object_class());
        if ( objectp(factory) ) {
   	    fGetEvent = factory->get_attributes_read_event;
            return fGetEvent(key);
        }
        return 0;
    }
    else
        return fGetEvent(key);
}

/**
 * Get the mapping of all registered attributes. That is only the
 * descriptions, permissions, type registration of the attributes.
 *  
 * @return mapping of all registered attributes
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see describe_attribute
 */
mapping get_attributes()
{
    object factory = _Server->get_factory(get_object_class());
    mapping attributes = factory->get_attributes();
    foreach(indices(mAttributes)+indices(mAttributesAcquire), mixed attr) {
	if ( !arrayp(attributes[attr]) )
	    attributes[attr] = ({ CMD_TYPE_UNKNOWN, (string)attr, 0,
				      EVENT_ATTRIBUTES_CHANGE, 0,
				      CONTROL_ATTR_USER, 0 });
    }
    return attributes;
}

/**
 * Get the mapping of acquired Attributes.
 *  
 * @return Mapping of acquired attributes (copy of the mapping of course)
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mapping get_acquired_attributes()
{
    return copy_value(mAttributesAcquire);
}

/**
 * Get the names of all attributes used in the object. Regardless if 
 * they are registered or not.
 *
 * @param   none
 * @return  list of names
 * @ingroup attribute
 * @author <a href="mailto:balduin@upb.de">Ludger Merkens</a>) 
 * @see get_attributes
 */
array get_attribute_names()
{
    return indices(mAttributes);
}
/**
 * Describe an attribute - call the factory of this class for it.
 * It will return an array of registration data.
 *  
 * @param mixed key - the attribute to describe
 * @return array of registration data - check attributes.h for it.
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array describe_attribute(mixed key)
{
    object factory = _Server->get_factory(this_object());
    return factory->describe_attribute(key);
}

/**
 * Check before setting an attribute. This include security checks
 * and finding out if the type of data matches the registered type.
 *  
 * @param mixed key - the attribute key 
 * @param mixed data - the new value for the attribute
 * @return true|throws exception 
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see set_attribute 
 */
static bool check_set_attribute(mixed key, mixed data)
{
    int    params, type;

    if ( mAttributesLocked[key] )
	THROW("Trying to set a locked attribute !", E_ACCESS);
    
    object factory = _Server->get_factory(this_object());
    if ( objectp(factory) ) 
	return factory->check_attribute(key, data);
    return true;
}

/**
 * This function is called when an attribute is changed in the object, 
 * that acquires an attribute from this object.
 *  
 * @param object o - the object where an attribute was changed
 * @param key - the key of the attribute
 * @param val - the new value of the attribute
 * @return false will make the acquire set to none in the calling object
 * @ingroup attribute
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool keep_acquire(object o, mixed key, mixed val)
{
    return false; // nothing is acquired from the object anymore
}

/** 
 * Sets a single attribute of an object. This function checks for acquiring
 * and possible sets the attribute in the object acquired from.
 *
 * @author Thomas Bopp
 * @param index - what attribute
 * @param data - data of that attribute
 * @return successfully or not, check attributes.h for possible results
 * @ingroup attribute
 * @see query_attribute
 **/
static bool do_set_attribute(mixed index, mixed|void data)
{
    object|function acquire;
    
    acquire = mAttributesAcquire[index];
    /* setting attributes removes acquiring settings */
    if ( functionp(acquire) ) acquire = acquire();
    if ( objectp(acquire) ) {
	/* if the attribute was changed in the acquired object we should
	 * get information about it too */
	bool acq = acquire->keep_acquire(this(), index, data);
	if ( acq ) {
	    acquire->set_attribute(index, data);
	    if ( index == OBJ_NAME )
		update_identifier(data);
	    return data;
	}
	else {
	    // set acquire to zero
	    mAttributesAcquire[index] = 0;
	}
    }

    /* OBJ_NAME requires speccial actions: the identifier (sIdentifier) must
     * be unique inside the objects current environment */
    if ( index == OBJ_NAME ) 
	update_identifier(data); 
    
    if ( zero_type(data) )
	m_delete(mAttributes, index);
    else
	mAttributes[index] = data;
    

    require_save(); /* Database need to save changes sometimes */
    return true;
}

/**
 * Set an attribute <u>key</u> to new value <u>data</u>. 
 *  
 * @param mixed key - the key of the attribute to change. 
 * @param mixed data - the new value for that attribute.
 * @return the new value of the attribute | throws and exception 
 * @ingroup attribute
 * @see query_attribute
 */
mixed set_attribute(mixed key, mixed|void data)
{
    bool free_write;
    int       event;

    check_set_attribute(key, data);
    try_event(get_attributes_change_event(key), CALLER, ([ key:data ]) );
    do_set_attribute(key, data);
    run_event(get_attributes_change_event(key), CALLER, ([ key:data ]) );
    return data;
}

static mixed do_append_attribute(mixed key, mixed data)
{
    array val = do_query_attribute(key);
    if ( mappingp(data) ) {
	if ( mappingp(val) )
	    return do_set_attribute(key, data + val);
    }
    if ( zero_type(val) || val == 0 )
	val = ({ });
    if ( !arrayp(data) ) {
	if ( search(val, data) >= 0 )
	    return val;
	data = ({ data });
    }
    return do_set_attribute(key, data + val);
    THROW("Can only append arrays on attributes !", E_ERROR);
}

static mixed remove_from_attribute(mixed key, mixed data)
{
    mixed val = do_query_attribute(key);
    if ( arrayp(val) ) {
	if ( search(val, data) >= 0 ) {
	    return do_set_attribute(key, val - ({ data }));
	}
    }
    else if ( mappingp(val) ) {
	m_delete(val, data);
	return do_set_attribute(key, val);
    }
    return val;
}


/**
 * Sets a number of attributes. The format is 
 * attr = ([ key1:val1, key2:val2,...]) and the function calls set_attribute
 * for each key.
 *  
 * @param mapping attr - the attribute mapping. 
 * @return true | throws exception 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see set_attribute 
 */
bool set_attributes(mapping attr)
{
    int                 event;
    mapping eventAttr = ([ ]);
    
    foreach(indices(attr), mixed key) {
	check_set_attribute(key, attr[key]);
	event = get_attributes_change_event(key);
	// generate packages for each event that should be fired
	if ( !mappingp(eventAttr[event]) ) 
	    eventAttr[event] = ([ ]);
	eventAttr[event][key] = attr[key];
    }
    // each attribute might run a different event, run each event individually
    // if security fails one of this the attribute-setting is canceled
    foreach( indices(eventAttr), event ) 
	try_event(event, CALLER, eventAttr[event]);
  
    // now the attributes are really set
    foreach(indices(attr), mixed key) {
	do_set_attribute(key, attr[key]);
    }
   
    // notification about the change, again for each package individually
    foreach( indices(eventAttr), event )
	run_event(event, CALLER, eventAttr[event]);

    return true;
}

/**
 * Set the object to acquire an attribute from. When querying the attribute
 * inside this object the value will actually the one set in the object
 * acquired from. Furthermore when changing the attributes value it
 * will be changed in the acquired object.
 *  
 * @param index - the attribute to set acquiring
 * @param acquire - object or function(object) for acquiring
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see set_attribute
 */
void
set_acquire_attribute(mixed index, object|function|int acquire)
{
    object acq;

    try_event(EVENT_ATTRIBUTES_ACQUIRE, CALLER, index, acquire);
    // check for possible endless loops

    // quick and dirty hack, because protocoll cannot send functions
    if ( intp(acquire) && acquire == REG_ACQ_ENVIRONMENT )
      acquire = get_environment;

    if ( functionp(acquire) ) 
	acq = acquire();
    else 
	acq = acquire;
    
    while ( objectp(acq) ) {
	array(mixed) reg;
	
	if ( functionp(acq->get_object) )
	    acq = acq->get_object();
	if ( acq == this_object() )
	    THROW("Acquire ended up in loop !", E_ERROR);
	acq = acq->get_acquire_attribute(index);
    }

    mAttributesAcquire[index] = acquire;
    require_save();
    run_event(EVENT_ATTRIBUTES_ACQUIRE, CALLER, index, acquire);
}

/**
 * Retrieve the acquiring status for an attribute.
 *  
 * @param mixed key - the key to get acquiring status for
 * @return function|object of acquiring or 0.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see set_acquire_attribute
 */
object|function get_acquire_attribute(mixed key)
{
    return mAttributesAcquire[key];
}

/** 
 * Get the value of one attribute.
 * 
 * @author Thomas Bopp
 * @param mixed key - what attribute to query.
 * @return the value of the queried attribute
 * @see set_attribute
 **/
mixed
query_attribute(mixed key)
{
    mixed val;

    int event = get_attributes_read_event(key);
    if ( event > 0 ) try_event(event, CALLER, key);

    val = do_query_attribute(key);
    
    if ( event > 0 ) run_event(event, CALLER, key );

    return copy_value(val);
}

/**
 * Query an attribute locally. This also follows acquired attributes.
 * No event is run by calling this and local calls wont have security
 * or any blocking event problem.
 *  
 * @param mixed key - the attribute to query.
 * @return value of the queried attribute
 * @see query_attribute
 */
static mixed do_query_attribute(mixed key)
{
    object|function acquire;

    acquire = mAttributesAcquire[key];
    if ( functionp(acquire) ) acquire = acquire();
    
    // if the attribute is acquired from another object query the attribute
    // there.
    if ( objectp(acquire) )
        return acquire->query_attribute(key);
    return mAttributes[key];
}


/**
 * Query the value of a list of attributes. Subsequently call
 * <a href="#query_attribute">query_attribute()</a> 
 * and returns the result as an array or, if a mapping with keys was 
 * given, the result is returned as a mapping key:value
 *  
 * @param array|mapping|void keys - the attributes to query
 * @return the result of the query as elements of an array.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see query_attribute
 */
array(mixed)|mapping
query_attributes(void|array(mixed)|mapping keys)
{
    int           i, sz;
    array(mixed) result;
	
    if ( !arrayp(keys) ) {
	if ( !mappingp(keys) )
	    keys = mkmapping(indices(mAttributes), values(mAttributes));

	foreach(indices(keys), mixed key) {
	    keys[key] = query_attribute(key);
	}
	return keys;
    }

    result = ({ });

    function qa = query_attribute;

    for ( i = 0, sz = sizeof(keys); i < sz; i++ )
	result += ({ qa(keys[i]) });
    return result;
}

/**
 * Set new permission for an object in the acl. Old permissions
 * are overwritten.
 *  
 * @param grp - the group or object to change permissions for
 * @param permission - new permission for this object
 * @return the new permission
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see sanction_object_meta
 * @see /base/access.set_sanction
 */
int sanction_object(object grp, int permission)
{
    ASSERTINFO(_SECURITY->valid_proxy(grp), "Sanction on non-proxy!");
    
    try_event(EVENT_SANCTION, CALLER, grp, permission);
    set_sanction(grp, permission);

    update_all_events();
    run_event(EVENT_SANCTION, CALLER, grp, permission);
    return permission;
}

/**
 * Sets the new meta permissions for an object. These are permissions
 * that are used for giving away permissions on this object.
 *  
 * @param grp - group or object to sanction
 * @param permission - new meta permission for this object
 * @return the new permission
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see sanction_object
 */
int
sanction_object_meta(object grp, int permission)
{
    try_event(EVENT_SANCTION_META, CALLER, grp, permission);
    set_meta_sanction(grp, permission);
    run_event(EVENT_SANCTION_META, CALLER, grp, permission);
    return permission;
}

/**
 * Add an annotation to this object. Each object in steam
 * can be annotated.
 *  
 * @param object ann - the annotation to add
 * @return successfull or not.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool add_annotation(object ann)
{
    try_event(EVENT_ANNOTATE, CALLER, ann);
    __annotateable::add_annotation(ann);
    do_set_attribute(OBJ_ANNOTATIONS_CHANGED, time());
    ann->add_reference(this());
    run_event(EVENT_ANNOTATE, CALLER, ann);
}

/**
 * Remove an annotation from this object. This only removes
 * it from the list of annotations, but doesnt delete it.
 *  
 * @param object ann - the annotation to remove
 * @return true or false
 * @see add_annotation
 */
bool remove_annotation(object ann)
{
    try_event(EVENT_REMOVE_ANNOTATION, CALLER, ann);
    __annotateable::remove_annotation(ann);
    do_set_attribute(OBJ_ANNOTATIONS_CHANGED, time());
    ann->remove_reference(this());
    run_event(EVENT_REMOVE_ANNOTATION, CALLER, ann);
}

/**
 * The persistent id of this object.
 *  
 * @return the ID of the object
 * @author Thomas Bopp 
 */
final int
get_object_id()
{
    return iObjectID;
}

/**
 * Is this an object ? yes!
 *  
 * @return true
 */
final bool is_object() { return true; }

/**
 * Sets the object id, but requires privileges in order to be successfull.
 * This actually means the caller has to be the <u>database</u> so this 
 * function is not callable for normal use.
 *  
 * @param id - the new id
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>
 */
nomask void
set_object_id(int id)
{
    if ( CALLER == _Database )
	iObjectID = id;
}

/**
 * Returns a bit array of classes and represent the inherit structure.
 *  
 * @return the class of the object
 * @author Thomas Bopp 
 */
int get_object_class()
{
    return CLASS_OBJECT;
}

/**
 * update the current identifier of the object. This must happen
 * on each movement, because there might be an object of the same
 * name in the new environment.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see get_identifier
 */
static void 
update_identifier(string name)
{
    int             i;
    object factory = get_factory(get_object_class());

    sIdentifier = replace(name, "/", "_");
    return;    

    if ( !objectp(oEnvironment) )
	return;
    ASSERTINFO(functionp(oEnvironment->get_inventory),
	       "Fatal Error: Environment is no container !");
    /* generate unique identifier for the current environment */
    object obj = oEnvironment->get_object_byname(sIdentifier, this());
    if ( objectp(obj) ) 
    {
	LOG("Found object with this identifier, making unique:"+
	    obj->get_identifier()+"("+obj->get_object_id()+")");
	sIdentifier = sIdentifier + "_" + get_object_id();
	require_save();
    }
}

/**
 * Moves the object to a destination, which requires move permission.
 *  
 * @param dest - the destination of the move operation
 * @return move successfull or throws an exception 
 * @author Thomas Bopp 
 */
bool move(object dest)
{
    ASSERTINFO(objectp(dest), "No destination of movement !");
    ASSERTINFO(IS_PROXY(dest), "Destination is not a proxy object !");
    /* Moving into an exit takes the exits location as destination */
    if ( dest->get_object_class() & CLASS_EXIT ) 
	dest = dest->get_exit();
    
    if ( dest->get_environment() == this() || dest == this() ) 
	THROW("Moving object inside itself !", E_ERROR|E_MOVE);

    LOG("Moving object from:"+(objectp(oEnvironment)?oEnvironment->get_object_id():"void")+ " to " + dest->get_object_id());
    
    if ( dest->this() == oEnvironment ) return true;
    
    try_event(EVENT_MOVE, CALLER, oEnvironment, dest);

    /* first remove object from its current environment */
    if ( objectp(oEnvironment) ) {
	if ( oEnvironment->status()<0 || !oEnvironment->remove_obj(this()) )
	    THROW("failed to remove object from environment !",E_ERROR|E_MOVE);
    }
    /* then insert object into new environment */
    if ( !dest->insert_obj(this()) ) {
	if ( objectp(oEnvironment) ) /* prevent object from being in void */
	    oEnvironment->insert_obj(this());
	THROW("failed to insert object into new environment !",E_ERROR|E_MOVE);
    }
    // finally set objects new environment 
    run_event(EVENT_MOVE, CALLER, oEnvironment, dest);
    oEnvironment = dest;
    // the identifier might has to be updated for new env 
    update_identifier(do_query_attribute(OBJ_NAME)); 

    require_save();
    return true;
}

/**
 * Get the environment of this object.
 *  
 * @return environment of the object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see move
 */
object
get_environment()
{
    return oEnvironment;
}

/**
 * Unserialize data of the object. Called when Database loads the object
 *  
 * @param str - the serialized object data
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see unserialize_access
 * @see retrieve_data
 */
final void 
restore_data(mixed data)
{
    if ( CALLER != _Database )
	THROW("Invalid call to restore_data()", E_ACCESS);

    mAttributes        = data["Attributes"];
    mAttributesLocked  = data["AttributesLocked"];
    mAttributesAcquire = data["AttributesAcquire"];
    oEnvironment       = data["Environment"];
    sIdentifier        = data["identifier"];
    
    sIdentifier = replace(mAttributes[OBJ_NAME], "/", "_");
#ifdef ATTRIBUTE_CONVERSION
    foreach ( indices(mAttributes), mixed key ) {
	if ( m_conversion[key] )
	    mAttributes[m_conversion[key]] = mAttributes[key];
    }
    require_save();
#endif
}

/**
 * serialize data of the object. Called by the Database object to save
 * the objects varibales into the Database.
 *  
 * @return the Variables of the object to be stored into database.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see restore_data
 */
final mapping
retrieve_data()
{
    if ( CALLER != _Database )
	THROW("Invalid call to retrieve_data()", E_ACCESS);
    
    return ([ 
	"identifier": sIdentifier,
	"Attributes":mAttributes, 
	"AttributesLocked":mAttributesLocked,
	"AttributesAcquire":mAttributesAcquire,
	"Environment":oEnvironment,
	]);
}

/**
 * returns the proxy object for this object, the proxy is set 
 * when the object is created.
 *  
 * @return the proxy object of this object
 * @author Thomas Bopp 
 * @see create
 */
object
this()
{
    return oProxy;
}

/**
 * trusted object mechanism - checks if an object is trusted by this object
 *  
 * @param object obj - is the object trusted
 * @return if the object is trustedd or not. 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 */
bool trust(object obj)
{
    int i;

    if ( obj == oProxy )
	return true;
    for ( i = sizeof(aoTrusted) - 1; i >= 0; i-- )
	if ( aoTrusted[i] == obj )
	    return true;
    return false;
}

/**
 * This function is called by delete to delete this object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see delete
 */
static void
delete_object()
{
    if ( objectp(oEnvironment) ) 
	oEnvironment->remove_obj(this());

    mixed err;
    err = catch {
	remove_all_events();    
    };
    err = catch {
	remove_all_annotations();
    };
}

/**
 * Call this function to delete this object. Of course this requires 
 * write permissions.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see destroy
 * @see delete_object
 */
final bool
delete()
{
    LOG("Trying to delete.... " + get_identifier());
    try_event(EVENT_DELETE, CALLER);
    delete_object();
    run_event(EVENT_DELETE, CALLER);
    _Database->delete_object(this());
    object temp = get_module("temp_objects");
    if ( objectp(temp) )
	temp->queued_destruct();
    else
	destruct(this_object());
    return true;
}

/**
 * non-documents have no content, see pike:file_stat() for sizes of 
 * directories, etc.
 *  
 * @return the content size of an object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see stat
 */
int 
get_content_size()
{
    return 0;
}

/**
 * Returns the id of the content inside the Database.
 *  
 * @return the content-id inside database
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final int get_content_id()
{
    //    int result = ::get_content_id(); <-- undefined - pike7.4 barks loud
    return 0;
}


/**
 * get the identifier of an object, this is the unique name inside 
 * the current environment of the object
 *  
 * @return the unique name
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see update_identifier
 */
string
get_identifier()
{
    return sIdentifier;
}

/**
 * file stat information about the object
 *  
 * @return the information like in file_stat() 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 */
array(int) stat()
{
    return ({ 33261, get_content_size(), 
		  mAttributes[OBJ_CREATION_TIME], time(), time(),
		  (objectp(get_creator()) ? 
		   get_creator()->get_object_id():0),
		  0,
		  "application/x-unknown-content-type", });
}

/**
 * Database is allowed to get any function pointer (for restoring object data)
 * and is the only object allowed to call this function.
 *  
 * @param string func - the function to get the pointer to.
 * @return the functionp to func
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see is_function 
 */
function get_function(string func)
{
    object t;
    if ( CALLER != _Database )
	THROW("Only database is allowed to get function pointer.", E_ACCESS);
    t = this_object();
    return t[func];
}


object get_icon()
{
    return query_attribute(OBJ_ICON);
}

/**
 * Find out if a given function is present inside this object.
 *  
 * @param string func - the function to find out about. 
 * @return is the function present ? 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 * @see get_function 
 */
bool is_function(string func)
{
    return functionp(this_object()[func]);
}

void test()
{
    // attribute testing
    set_attribute("test", "hello");
    if ( do_query_attribute("test") != "hello" )
	steam_error("Setting attribute failed");
    object icon = do_query_attribute(OBJ_ICON);
    if ( !objectp(icon) )
	steam_error("Object does not have a default icons set!");
    
    // sanction test, access
    object steam = GROUP("steam");
    if ( !objectp(steam) )
	steam_error("Something serious wrong - no steam group !");
    int val = sanction_object(steam, SANCTION_EXECUTE);
    if ( !(val & SANCTION_EXECUTE) )
	steam_error("Sanction test failed");

    // annotations
    object factory = get_factory(CLASS_DOCUMENT);
    object ann = factory->execute( ([ 
	"name":"an annotation", "mimetype":"text/html" ]) );
    if ( !(ann->get_object_class() & CLASS_DOCHTML) )
	steam_error("Annotation is not of correct class !");
    add_annotation(ann);
    if ( search(get_annotations(), ann) == -1 )
	steam_error("New annotation not in list of annotations.");
    if ( !ann->get_references()[this()] )
	steam_error("Annotation does not reference this().");
    remove_annotation(ann);
    if ( search(get_annotations(), ann) != -1 )
	steam_error("New annotation still in list of annotations.");
    if ( ann->get_references()[this()] )
	steam_error("Annotation still references me, though not annotating.");
    
    ann->delete();
}


string describe()
{
    return get_identifier()+"(#"+get_object_id()+","+
	master()->describe_program(object_program(this_object()))+","+
	get_object_class()+")";
}

string get_xml()
{
    object serialize = get_module("Converter:XML");
    string xml = "<?xml version='1.0' encoding='iso-8859-1'?>";
    mapping val = mkmapping(::_indices(1), ::_values(1));
    foreach ( indices(val), string idx ) {
	if ( !functionp(val[idx]) )
	    xml += "<"+idx+">\n" +
		serialize->compose(val[idx])+"\n</"+idx+">\n";
    }
    return xml;
}
