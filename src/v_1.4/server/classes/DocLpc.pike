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
/* this object really represents a factory if executed !
 */
inherit "/classes/Document";

#include <classes.h>
#include <access.h>
#include <database.h>
#include <attributes.h>
#include <macros.h>
#include <types.h>
#include <classes.h>
#include <events.h>
#include <exception.h>

static mapping       mRegAttributes; // registered attributes for this factory
static array(object)    aoInstances; // Instances of this class

/**
 * Initialize the document.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
init_document()
{
    mRegAttributes = ([ ]);
    aoInstances     = ({ });
    add_data_storage(retrieve_doclpc, restore_doclpc);
}

/**
 * Get the object class - CLASS_DOCLPC in this case.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
int
get_object_class()
{
    return ::get_object_class() | CLASS_DOCLPC;
}

/**
 * Destructor of this object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
delete_object()
{
    aoInstances -= ({ 0 });
    
    foreach(aoInstances, object obj)
	if ( objectp(obj) )
	    obj->delete(); // delete all instances
#if 0
    if ( arrayp(aoInstances) && sizeof(aoInstances) > 0 ) {
	THROW("Still instances of the class - cannot delete !\n", E_ERROR);
    }
#endif
    ::delete_object();
}

/**
 * Execute the DocLPC which functions as a factory class.
 * The parameters must include a name 'name' and might include
 * a 'moveto' variable to move the object.
 *  
 * @param mapping variables - execution parameters.
 * @return the newly created object.
 * @author Thomas Bopp (astra@upb.de) 
 */
mixed execute(mapping variables)
{
    if ( objectp(_CODER) && sizeof(_CODER->get_members()) > 0 ) {
	// check if User code is allowed, creator needs to be coder
	// and no other user should have write access on this script
	object creator = get_creator();
	if ( !_CODER->is_member(creator) && !_ADMIN->is_member(creator) )
	    THROW("Unauthorized Script", E_ACCESS);
	mapping sanc = get_sanction();
	foreach(indices(sanc), object grp) {
	    if ( (sanc[grp] & SANCTION_WRITE ) && !_ADMIN->is_member(grp) &&
		 !_CODER->is_member(grp) && grp != _ADMIN && grp != _CODER )
		THROW("Write access for non coder group enabled - aborting !",
		      E_ACCESS);
	}
    }

    try_event(EVENT_EXECUTE, CALLER, 0);
    if ( stringp(variables->_action) && sizeof(aoInstances) > 0 ) {
      //just call the script
      object script = aoInstances[0];
      return script->execute(variables);
    }

    //object obj = new("/DB:#"+get_object_id()+".pike", variables["name"]);
    
    object obj = ((program)("/DB:#"+get_object_id()+".pike"))(variables->name);

    register_attributes(obj);
    
    object mv = find_object((int)variables["moveto"]);
    if ( objectp(mv) )
	obj->move(mv);

    if ( !stringp(variables["name"]) )
	variables->name = "";
    obj->set_attribute(OBJ_NAME, variables["name"]);
    obj->set_attribute(OBJ_CREATION_TIME, time());
    obj->set_attribute(OBJ_SCRIPT, this());
    obj->set_acquire(obj->get_environment);
    obj->set_acquire_attribute(OBJ_ICON, _Server->get_module("icons"));
    obj->created();
    aoInstances += ({ obj->this() });
    aoInstances -= ({ 0 });
    require_save();
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj;
}

/**
 * Call this script - use first instance or create one if none.
 *  
 * @param mapping vars - normal variable mapping
 * @return execution result
 */
mixed call_script(mapping vars)
{
    array instances = aoInstances;
    if ( arrayp(instances) )
	instances -= ({ 0 });
    if ( !arrayp(instances) || sizeof(instances) == 0 ) {
	object e = master()->ErrorContainer();
	master()->set_inhibit_compile_errors(e);
	mixed err = catch {
	    object o = execute((["name":"temp", ]));
	    o->set_acquire(this());
	};
	master()->set_inhibit_compile_errors(0);
	if ( err != 0 ) {
	    return 0;
	}
    }
    object script = aoInstances[0];
    return script->execute(vars);
}

/**
 * register all attributes for an object
 *  
 * @param obj - the object to register attributes
 * @author Thomas Bopp (astra@upb.de) 
 * @see register_class_attribute
 */
private static void
register_attributes(object obj)
{
    object factory = _Server->get_factory(obj->get_object_class());
    if ( !objectp(factory) )
	factory = _Server->get_factory(CLASS_OBJECT);
    
    mapping mClassAttr = factory->get_attributes() + mRegAttributes;
    foreach ( indices(mClassAttr), mixed key ) 
    {
	/* if attribute is not registered, or format changed - re-register */
	obj->set_attribute(key, mClassAttr[key][REGISTERED_DEFAULT]);
	
	if ( obj->get_acquire_attribute(key) == 0 ) 
	{
	    if ( mClassAttr[key][REGISTERED_ACQUIRE] == REG_ACQ_ENVIRONMENT )
		obj->set_acquire_attribute(key, obj->get_environment);
	    else 
		obj->set_acquire_attribute(
		   key, mClassAttr[key][REGISTERED_ACQUIRE]);
	}
    }
}

/**
 * register attributes for the class(es) this factory creates.
 * each newly created object will have the attributes registered here.
 *  
 * @param key - the key of the attribute
 * @param type - the attributes type (see types.h)
 * @param desc - the attributes description
 * @param cntrl - who controls the attribute
 * @param perm - the attributes permission
 * @param def - the default value
 * @param acq - acquiring information
 * @author Thomas Bopp (astra@upb.de) 
 * @see classes/Object.register_attribute
 * @see _register_class_attribute
 */
void 
register_attribute(mixed key, int type, string desc, int event_read,
		   int event_write, void|object|int acq, int cntrl, mixed def,
		   void|function conversion)
{
    try_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
    register_class_attribute(
	key, type, desc, event_read, event_write, acq, cntrl, def, conversion);

    run_event(EVENT_REGISTER_ATTRIBUTE, CALLER, key);
}

/**
 * register_class_attribute is called by register_attribute,
 * this function is local and does no security checks
 *  
 * @param key - the key of the attribute
 * @param type - the attributes type (see types.h)
 * @param desc - the attributes description
 * @param cntrl - who controls the attribute
 * @param perm - the attributes permission
 * @param def - the default value
 * @param acq - acquiring information
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
static void
register_class_attribute(mixed key, int type, string desc, 
			 int event_read, int event_write, 
			 void|object|int acq, int cntrl, mixed def,
			 void|function conversion)
{
    foreach(aoInstances, object instance) {
	if ( functionp(conversion) )
	    conversion(instance);
	else {
	    if ( !zero_type(def) ) {
		instance->set_attribute(key, def);
	    }
	    if ( acq == REG_ACQ_ENVIRONMENT )
		instance->set_acquire_attribute(key,instance->get_environment);
	    else 
		instance->set_acquire_attribute(key, acq);
	}
    }
    mRegAttributes[key] = ({ type, desc, event_read, event_write, acq,
				 cntrl, def });
    require_save();
}

/**
 * get the registration information for one attribute of this class
 *  
 * @param mixed key - the attribute to describe.
 * @return array of registered attribute data.
 * @author Thomas Bopp (astra@upb.de) 
 */
array describe_attribute(mixed key)
{
    return copy_value(mRegAttributes[key]);
}

/**
 * Check the new data for a registered attribute.
 *  
 * @param mixed key - the attributes key.
 * @param mixed data - the new value for the attribute.
 * @return true or false.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool check_attribute(mixed key, mixed data)
{
    object factory = _Server->get_factory(CLASS_OBJECT);
    if ( arrayp(mRegAttributes[key]) )
        return factory->check_attribute(
              key, data, mRegAttributes[key][REGISTERED_TYPE]);
    else
	return factory->check_attribute(key, data);
}

/**
 * Get the source code of the doclpc, used by master().
 *  
 * @return the content of the document.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string get_source_code()
{
    return ::_get_content();
}

/**
 * Get the compiled program of this objects content.
 *  
 * @return the pike program.
 */
final program get_program() 
{ 
    return master()->lookup_program("/DB:#"+get_object_id()+".pike");
}

/**
 * Get an Array of Error String description.
 *  
 * @return array list of errors from last upgrade.
 */
array(string) get_errors()
{
    return master()->get_error("/DB:#"+get_object_id()+".pike");
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void upgrade()
{
    mixed res = master()->upgrade(get_program());
    if ( stringp(res) )
	steam_error(res);
}

static void content_finished()
{
    ::content_finished();
    mixed err = catch(upgrade());
    if ( err != 0 ) 
	werror("Error upgrading program...."+err[0]+"\n");
}

/**
 * Retrieve the DocLPC data for storage in the database.
 *  
 * @return the saved data mapping.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final mapping
retrieve_doclpc()
{
    if ( CALLER != _Database )
	THROW("Invalid call to retrieve_data()", E_ACCESS);
    
    return ([ 
	"RegAttributes":mRegAttributes, 
	"Instances": aoInstances,
	]);
}

/**
 * Restore the data of the LPC document.
 *  
 * @param mixed data - the saved data.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void 
restore_doclpc(mixed data)
{
    if ( CALLER != _Database )
	THROW("Invalid call to restore_data()", E_ACCESS);
    mRegAttributes = data["RegAttributes"];
    aoInstances = data["Instances"];
    if ( !arrayp(aoInstances) )
	aoInstances = ({ });
}

/**
 * Get the existing instances of this pike program.
 *  
 * @return array of existing objects.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(object) get_instances()
{
  array instances = ({ });

  for ( int i = 0; i < sizeof(aoInstances); i++ ) {
    if ( objectp(aoInstances[i]) &&
	 aoInstances[i]->status() != PSTAT_FAIL_DELETED )
      instances += ({ aoInstances[i] });
  }
  return instances;
}

string describe()
{
    return get_identifier()+"(#"+get_object_id()+","+
	master()->describe_program(object_program(this_object()))+","+
	get_object_class()+","+do_query_attribute(DOC_MIME_TYPE)+","+
	sizeof(aoInstances) +" Instances)";
}
