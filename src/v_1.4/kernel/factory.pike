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
inherit "/classes/Object";

#include <macros.h>
#include <roles.h>
#include <assert.h>
#include <attributes.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <types.h>
#include <events.h>
#include <exception.h>

#define WRONG_TYPE(key) THROW("Wrong value to attribute "+ key +" !", E_ERROR)

static mapping mRegAttributes;

static void init_factory() { }
bool check_swap() { return false; }
bool check_upgrade() { return false; }


/**
 * Init callback function sets a data storage.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
init()
{
    ::init();
    add_data_storage(retrieve_attr_registration, restore_attr_registration);
}

/**
 * A factory calls initialization of factory when it is loaded.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void load_object()
{
    init_factory();
}

/**
 * Object constructor. Here the Attribute registration mapping is initialized.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
static void create_object()
{
    mRegAttributes = ([ 
	OBJ_NAME:        ({ CMD_TYPE_STRING, "object name", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0, 
			    CONTROL_ATTR_USER, "" }),
	OBJ_DESC:        ({ CMD_TYPE_STRING, "description", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0,
			    CONTROL_ATTR_USER, 
			    "" }),
	OBJ_ICON:        ({ CMD_TYPE_OBJECT, "icon", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0,
			    CONTROL_ATTR_USER, 0 }),
	OBJ_LINK_ICON:        ({ CMD_TYPE_OBJECT, "link icon", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0,
			    CONTROL_ATTR_USER, 0 }),
	OBJ_KEYWORDS:    ({ CMD_TYPE_ARRAY, "keywords", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0,
			    CONTROL_ATTR_USER, ({ }) }),
	OBJ_COMMAND_MAP: ({ CMD_TYPE_MAPPING, "execute:accept", 
			    0, EVENT_ATTRIBUTES_CHANGE, 0,
			    CONTROL_ATTR_USER, ([ ]) }),
        OBJ_POSITION_X:  ({ CMD_TYPE_FLOAT, "x-position",
                            0, EVENT_ARRANGE_OBJECT, 0,
                            CONTROL_ATTR_CLIENT, 0.0 }),
        OBJ_POSITION_Y:  ({ CMD_TYPE_FLOAT, "y-position",
                            0, EVENT_ARRANGE_OBJECT, 0,
                            CONTROL_ATTR_CLIENT, 0.0 }),
        OBJ_POSITION_Z:  ({ CMD_TYPE_FLOAT, "z-position",
                            0, EVENT_ARRANGE_OBJECT, 0,
                            CONTROL_ATTR_CLIENT, 0.0 }),
	]);
    init_factory();
    require_save();
}

/**
 * See if a given name is valid for objects created by this factory.
 *  
 * @param string name - the name of the object
 */
void valid_name(string name)
{
    if ( !stringp(name) )
	steam_error("The name of an object must be a string !");
    if ( search(name, "/") >= 0 )
	steam_error("/ is not allowed in Object Names...");
}


/**
 * create a new object of 'doc_class'
 *  
 * @param name - the name of the new object
 * @param doc_class - the class of the new object
 * @param env - the env the object should be moved to
 * @return pointer to the new object
 * @author Thomas Bopp (astra@upb.de) 
 */
static object
object_create(string name, string doc_class, object env, int|mapping attr,
	      void|mapping attrAcq, void|mapping attrLock)
{
    object obj, user;
    int          res;

    user = this_user();
    doc_class = CLASS_PATH + doc_class + ".pike";
    SECURITY_LOG("New object of class:" + doc_class + " at " + ctime(time()));

#ifdef RESTRICTED_NAMES
    valid_name(name);
#endif
    
    obj = new(doc_class, name);
    if ( !objectp(obj) )
	THROW("Failed to create object !", E_ERROR);

    register_attributes(obj);

    if ( !stringp(name) || name == "" ) 
        THROW("No name set for object !", E_ERROR);

    if ( mappingp(attr) )
	obj->set_attributes(attr);

    obj->set_attribute(OBJ_NAME, name);
    obj->set_attribute(OBJ_CREATION_TIME, time());

    obj->set_acquire_attribute(OBJ_ICON, _Server->get_module("icons"));

    
    if ( !stringp(obj->query_attribute(OBJ_NAME)) || 
         obj->query_attribute(OBJ_NAME) == "" )
       THROW("Strange error - attribute name setting failed !", E_ERROR);
    
    SECURITY_LOG("Object " + obj->get_object_id() + " name set on " +
		 ctime(time()));
    
    if ( !objectp(user) )
	user = MODULE_USERS->lookup("root");
    obj->set_creator(user);
    
    if ( user != MODULE_USERS->lookup("root") && 
	 user != MODULE_USERS->lookup("guest") )
    {
	obj->sanction_object(user, SANCTION_ALL);
	obj->sanction_object_meta(user, SANCTION_ALL);
    }
    if ( objectp(user) ) {
	mapping umask = user->query_attribute(USER_UMASK);
	if ( mappingp(umask) ) {
	    foreach(indices(umask), object um) {
		if ( objectp(um) && intp(umask[um]) ) {
		    obj->sanction_object(um, umask[um]);
		}
	    }
	}
    }
    obj->set_acquire(obj->get_environment);
    ASSERTINFO(obj->get_acquire() == obj->get_environment,
	       "Acquire not on environment, huh?");

    obj->created();

    if ( objectp(env) ) obj->move(env->this());

    return obj->this();
}

/**
 * register all attributes for an object
 *  
 * @param obj - the object to register attributes
 * @author Thomas Bopp (astra@upb.de) 
 * @see register_class_attribute
 */
static void register_attributes(object obj, int|void onlyKey)
{
    mixed err;
    if ( onlyKey != 0 ) {
	if ( !arrayp(mRegAttributes[onlyKey]) )
	    return;
	err = catch {
	    obj->set_attribute(
		onlyKey, mRegAttributes[onlyKey][REGISTERED_DEFAULT]);
	    if ( mRegAttributes[onlyKey][REGISTERED_ACQUIRE] == REG_ACQ_ENVIRONMENT )
	        obj->set_acquire_attribute(onlyKey, obj->get_environment);
	    else 
	        obj->set_acquire_attribute(
		    onlyKey, mRegAttributes[onlyKey][REGISTERED_ACQUIRE]);
	    return;
	};
    }
    foreach (indices(mRegAttributes), mixed key) 
    {
	/* if attribute is not registered, or format changed - re-register */
	err = catch {
	    obj->set_attribute(key, mRegAttributes[key][REGISTERED_DEFAULT]);
	    if ( mRegAttributes[key][REGISTERED_ACQUIRE]==REG_ACQ_ENVIRONMENT)
	        obj->set_acquire_attribute(key, obj->get_environment);
	    else {
		obj->set_acquire_attribute(
		    key, mRegAttributes[key][REGISTERED_ACQUIRE]);
	    }
	};
    }
}

/**
 * register attributes for the class(es) this factory creates.
 * each newly created object will have the attributes registered here.
 *  
 * @param key - the key of the attribute
 * @param type - the attributes type (see types.h)
 * @param desc - the attributes description
 * @param event_read - the read-event to fire
 * @param event_write - the event to fire when the attribute is changed
 * @param acq - acquiring information
 * @param cntrl - who controls the attribute
 * @param def - the default value
 * @param void|function conversion - conversion function for all objects
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see classes/Object.set_attribute
 */
void 
register_attribute(mixed key, int type, string desc, int event_read,
		   int event_write, void|object|int acq, int cntrl, mixed def,
		   void|function conversion)
{
    try_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
    register_class_attribute(
	key, type, desc, event_read, event_write, acq, cntrl, def, conversion);

    // register on all dependent factories too
    array(object) factories = values(_Server->get_classes());
    foreach ( factories, object factory ) {
	factory = factory->get_object();
	if ( factory->get_object_id() == get_object_id() )
	    continue;
	if ( search(Program.all_inherits(object_program(factory)),
		    object_program(this_object())) >= 0 )
	{
	    factory->register_attribute(
		key, type, desc, event_read, event_write, acq, cntrl, def,
		conversion);
	}
    }
    run_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
}

/**
 * Change the registration of an attribute.
 *  
 * @param mixed key - the attribute to re-register
 * @param int reg - which registration value to change
 * @param mixed val - the new value for the attribute
 * @param void|bool|function conv - update all instances, might be a
 *                                  conversion function
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void 
re_register_attribute(mixed key, int reg, mixed val, void|bool|function conv)
{
    try_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
    if ( zero_type(mRegAttributes[key]) )
	THROW("Trying to re-register unregistered attribute!", E_ERROR);
    mRegAttributes[key][reg] = val;
    require_save();
    if ( functionp(conv) )
	update_instances(key, mRegAttributes[key][REGISTERED_DEFAULT],
			 mRegAttributes[key][REGISTERED_ACQUIRE],
			 conv);
    else if ( conv == true )
	update_instances(key, mRegAttributes[key][REGISTERED_DEFAULT],
			 mRegAttributes[key][REGISTERED_ACQUIRE]);
    array(object) factories = _Server->get_factories();
    foreach(factories, object factory) {
	if ( factory->get_class_id() > get_class_id() )
	    factory->re_register_attribute(key, reg, val, false);
    }
    run_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
}

/**
 * Update instances of objects created by this factory when a new 
 * attribute is registered. This sets the new default value for the attribute
 * and the basic acquiring.
 *  
 * @param mixed key - the attribute key.
 * @param mixed def - default value for the attribute.
 * @param void|object|int acq - acquires value from ...
 * @param function|void conv - the conversion function.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
update_instances(mixed key, mixed def, void|object|int acq, function|void conv)
{

    array(object) instances = _Database->get_all_objects();
    foreach(instances, object instance) {
	if ( !objectp(instance) || !functionp(instance->get_object_class) ||
	     !(instance->get_object_class() & get_class_id()) )
	    continue;
        if ( functionp(conv) ) {
	    conv(instance);
	}
	else {
	    if ( !zero_type(def) ) {
		mixed err = catch {
		    instance->set_attribute(key, def);
		};
		// might be locked
	    }
	    if ( acq == REG_ACQ_ENVIRONMENT )
		instance->set_acquire_attribute(key,instance->get_environment);
	    else if ( acq != instance ) 
		instance->set_acquire_attribute(key, acq);
            else
	        instance->set_acquire_attribute(key, 0);
	}
    }
}


/**
 * Register_class_attribute is called by register_attribute,
 * this function is local and does no security checks. All instances
 * of this class are set to the default value and acquiring settings.
 *  
 * @param mixed key - the attribute key to register.
 * @param int type - the type for the attribute
 * @param string desc - the attributes description
 * @param int event_read - event to call when reading the attribute.
 * @param int event_write - event when writing the attribute.
 * @param void|object|int acq - where to acquire attributes value.
 * @param int cntrl - who or what is controling the attribute.
 * @param mixed def - the default value.
 * @param void|function conversion - conversion function.
 * @author Thomas Bopp (astra@upb.de) 
 * @see register_attribute
 */
static void
register_class_attribute(mixed key, int type, string desc, 
			 int event_read, int event_write, 
			 void|object|int acq, int cntrl, mixed def,
			 void|function conversion)
{
    array prevReg = ({ 0, desc, event_read, event_write, 0, 0, -1 });
    if ( !zero_type(mRegAttributes[key]) ) {
	prevReg = copy_value(mRegAttributes[key]);
    }

    
    mRegAttributes[key] = ({ type,desc,event_read,event_write,acq,cntrl,def });
    require_save();

    if (!_Server->is_a_factory(this_object()) || _Server->is_a_factory(CALLER)) 
	return; // initial creation of this object or CALLER already converted

    if ( prevReg[REGISTERED_DEFAULT]!=def || prevReg[REGISTERED_ACQUIRE]!=acq )
	update_instances(key, def, acq, conversion);
}


/*
 * Init an attribute of this class calls registration function.  
 *
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see register_class_attribute
 */
static void 
init_class_attribute(mixed key, int type, string desc, 
		     int event_read, int event_write, 
		     void|object|int acq, int cntrl, mixed def)
{
    if ( !arrayp(mRegAttributes[key]) )
	register_class_attribute(key, type, desc, event_read,
				 event_write, acq, cntrl, def);
}

/**
 * Check if an attributes value is going to be set correctly.
 * An objects set_attribute function calls this check and
 * throws an error if the value is incorrect.
 *  
 * @param mixed key - the attributes key.
 * @param mixed data - the new value of the attribute.
 * @param int|void regType - registration data to check, if void use factories.
 * @return true or false.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool check_attribute(mixed key, mixed data, int|void regType)
{

    if ( !arrayp(mRegAttributes[key]) ) 
	return true;


    // see if our factory has something about this attribute
    if ( zero_type(data) )
	register_attributes(CALLER, key);
    

    // value 0 should be ok
    if ( data == 0 ) return true;

    if ( regType == 0 )
	regType = mRegAttributes[key][REGISTERED_TYPE];
    
    switch(regType) {
	case CMD_TYPE_INT:
	    if ( !intp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_FLOAT:
	    if ( !floatp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_STRING:
	    if ( !stringp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_OBJECT:
	    if ( !objectp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_ARRAY:
	    if ( !arrayp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_MAPPING:
	    if ( !mappingp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_PROGRAM:
	    if ( !programp(data) ) WRONG_TYPE(key);
	    break;
	case CMD_TYPE_FUNCTION:
	    if ( !programp(data) ) WRONG_TYPE(key);
	    break;
    }
    return true;
}

/**
 * Get the registration information for one attribute of this class.
 *  
 * @param mixed key the attributes key.
 * @return The array of registered data.
 * @author Thomas Bopp (astra@upb.de) 
 */
array describe_attribute(mixed key)
{
    return copy_value(mRegAttributes[key]);
}

/**
 * Get all registered attributes for this class.
 *  
 * @return the mapping of registered attributes for this class
 * @author Thomas Bopp (astra@upb.de) 
 * @see register_class_attribute
 */
mapping get_attributes()
{
    return copy_value(mRegAttributes);
}

/**
 * Get the event to fire upon reading the attribute.
 *  
 * @param mixed key - the attributes key.
 * @return read event or zero.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_attribute_change_event
 */
int get_attributes_read_event(mixed key)
{
    if ( !arrayp(mRegAttributes[key]) )
	return 0;
    return mRegAttributes[key][REGISTERED_EVENT_READ];
}

/**
 * Get the event to fire upon changing an attribute.
 *  
 * @param mixed key - the attributes key.
 * @return change event or zero.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_attributes_read_event
 */
int get_attributes_change_event(mixed key)
{
    if ( !mappingp(mRegAttributes) || !arrayp(mRegAttributes[key]) )
	return EVENT_ATTRIBUTES_CHANGE;
    return mRegAttributes[key][REGISTERED_EVENT_WRITE];
}

/**
 * Get an attributes default value and acquiring.
 *  
 * @param mixed key - the attributes key.
 * @return array of default value and acquiring setting.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array get_attribute_default(mixed key) 
{
    return ({ mRegAttributes[key][REGISTERED_DEFAULT],
		  mRegAttributes[key][REGISTERED_ACQUIRE] });
}

/**
 * Called by the _Database to get the registered attributes (saved data)
 * for this factory.
 *  
 * @return mapping of registered attributes.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final mapping
retrieve_attr_registration()
{
    if ( CALLER != _Database )
	THROW("Invalid call to retrieve_data()", E_ACCESS);
    
    return ([ 
	"RegAttributes":mRegAttributes, 
	]);
}

/**
 * Called by _Database to restore the registered attributes data.
 *  
 * @param mixed data - restore data.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void 
restore_attr_registration(mixed data)
{
    if ( CALLER != _Database )
	THROW("Invalid call to restore_data()", E_ACCESS);
    mRegAttributes = data["RegAttributes"];
}

string get_identifier() { return "factory"; }
int get_object_class() { return ::get_object_class() | CLASS_FACTORY; }
string get_class_name() { return "undefined"; }
int get_class_id() { return CLASS_OBJECT; }
