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

#include <attributes.h>
#include <macros.h>
#include <assert.h>
#include <events.h>
#include <classes.h>
#include <database.h>
#include <types.h>

private static array(object) oaInventory; // the containers inventory

/**
 * init this object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create
 */
static void
init()
{
    ::init();
    oaInventory = ({ });
    add_data_storage(store_container, restore_container);
}

/**
 * This function is called by delete to delete this object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a> 
 */
static void
delete_object()
{
    ::delete_object();
    array(object) inventory = copy_value(oaInventory);
    
    foreach( inventory, object inv ) {
	// dont delete Users !
	if ( objectp(inv) )
	{
	    mixed err;
	    if ( inv->get_object_class() & CLASS_USER) {
		err = catch {
		    inv->move(inv->query_attribute(USER_WORKROOM));
		};
	    }
	    else {
		err = catch {
		    inv->delete();
		};
	    }
	}
    }
}

/**
 * Duplicate an object - that is create a copy, the permisions are
 * not copied though.
 *  
 * @param recursive - should the container be copied recursively?
 * @return the copy of this object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create
 */
object duplicate(void|bool recursive)
{
    object dup_obj = ::duplicate();
    if ( recursive ) {
	foreach( oaInventory, object inv ) {
	    if ( inv->get_object_class() & CLASS_USER) 
		continue;
	    object new_inv, factory;
	    mixed err = catch {
		new_inv = inv->duplicate(recursive);
		new_inv->move(dup_obj);
	    };
	    if ( err != 0 ) {
		LOG("Error while duplicating recursively !\n"+
		    err[0]+"\n"+PRINT_BT(err[1]));
	    }
	}
    }
    return dup_obj;
}

/**
 * Check if it is possible to insert the object here.
 *  
 * @param object obj - the object to insert
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see insert_obj
 */
static bool check_insert(object obj)
{
    if ( obj->get_object_class() & CLASS_ROOM ) 
	return false;

    if ( obj->get_object_class() & CLASS_USER )
	return false;

    if ( obj->get_object_class() & CLASS_EXIT )
	return false;

    return true;
}

void check_environment(object env, object obj)
{
    if ( !objectp(env) )
	return;

    if ( env == obj )
	steam_error("Recursion detected in environment!");
    env = env->get_environment();
    check_environment(env, obj);
}

/**
 * Insert an object in the containers inventory. This is called by
 * the move function - don't call this function myself.
 *  
 * @param obj - the object to insert into the container
 * @return true if object was inserted
 * @author Thomas Bopp 
 * @see remove_obj
 */
bool
insert_obj(object obj)
{
    ASSERTINFO(IS_PROXY(obj), "Object is not a proxy");
    
    if ( !objectp(obj) )
	return false;

    if ( CALLER != obj->get_object() ) // only insert proxy objects
	return false;
    if ( !arrayp(oaInventory) )
	oaInventory = ({ });

    if ( !check_insert(obj) ) 
	return false; // no no no throw!

    // check for recursive structures.
    if ( obj == this() )
	steam_error("Cannot insert object into itself !");
    check_environment(get_environment(), obj);

    if ( search(oaInventory, obj) != -1 ) {
	FATAL("Inserting object twice !!!!");
        return true;
    }
	

    try_event(EVENT_ENTER_INVENTORY, obj);

    do_set_attribute(CONT_LAST_MODIFIED, time());
    oaInventory += ({ obj });

    require_save();
    run_event(EVENT_ENTER_INVENTORY, obj);
    return true;
}



/**
 * Remove an object from the container. This function can only be
 * called by the object itself and should only be called by the move function.
 *  
 * @param obj - the object to insert into the container
 * @return true if object was removed
 * @author Thomas Bopp 
 * @see insert_obj
 */
bool remove_obj(object obj)
{
    if ( !objectp(obj) ||
         (obj->get_object() != CALLER && obj->get_environment() == this()) )
	return false;

    ASSERTINFO(arrayp(oaInventory), "Inventory not initialized!");
    try_event(EVENT_LEAVE_INVENTORY, obj);
    
    do_set_attribute(CONT_LAST_MODIFIED, time());
    oaInventory -= ({ obj });
    
    require_save();
    run_event(EVENT_LEAVE_INVENTORY, obj);
    return true;
}

/**
 * Get the inventory of this container.
 *  
 * @param void|int from_obj - the starting object
 * @param void|int to_obj - the end of an object range.
 * @return a list of objects contained by this container
 * @see move
 * @see get_inventory_by_class
 */
array(object) get_inventory(int|void from_obj, int|void to_obj)
{
    oaInventory -= ({0});
    try_event(EVENT_GET_INVENTORY, CALLER);
    run_event(EVENT_GET_INVENTORY, CALLER);
    
    if ( to_obj > 0 )
	return oaInventory[from_obj..to_obj];
    else if ( from_obj > 0 )
	return oaInventory[from_obj..];
    return copy_value(oaInventory);
}

/**
 * Get the content of this container - only relevant for multi
 * language containers.
 *  
 * @return content of index file
 */
string get_content(void|string language)
{
  if ( do_query_attribute("cont_type") == "multi_language" ) {
    mapping index = do_query_attribute("language_index");
    if ( objectp(index[language]) )
      return index[language]->get_content();
    if ( objectp(index->default) )
      return index["default"]->get_content();
  }
  return 0;
}

/**
 * Get only objects of a certain class. The class is the bit id submitted
 * to the function. It matches only the highest class bit given.
 * This means get_inventory_by_class(CLASS_CONTAINER) would not return
 * any CLASS_ROOM. Also it is possible to do 
 * get_inventory_by_class(CLASS_CONTAINER|CLASS_EXIT) which would return
 * an array of containers and exits, but still no rooms or links - 
 * Room is derived from Container and Exit inherits Link.
 *  
 * @param int cl - the classid
 * @param void|int from_obj - starting object 
 * @param void|int to_obj - second parameter for an object range.
 * @return list of objects matching the given criteria.
 */
array(object) get_inventory_by_class(int cl, int|void from_obj, int|void to_obj) 
{
    array(object) arr = ({ });
    array(int)    bits= ({ });
    for ( int i = 0; i < 32; i++ ) {
        if ( cl & (1<<i) ) 
           bits += ({ 1<<i });
    }
    int cnt = 0;
    foreach(bits, int bit) {
        foreach(oaInventory, object obj) {
            int ocl = obj->get_object_class();
            if ( (ocl & bit) && (ocl < (bit<<1)) ) {
		cnt++;
		if ( from_obj < cnt && (to_obj == 0 || cnt < to_obj ) )
		    arr += ({ obj });
	    }
        }
    }
    return arr;
}

/**
 * Restore the container data. Most importantly the inventory.
 *  
 * @param data - the unserialized object data
 * @author Thomas Bopp (astra@upb.de) 
 * @see store_container
 */
void restore_container(mixed data)
{
    if (CALLER != _Database )
	THROW("Caller is not Database !", E_ACCESS);

    oaInventory = data["Inventory"];
    if ( !arrayp(oaInventory) )
	oaInventory = ({ });
    
}

/**
 * Stores the data of the container. Returns the inventory
 * of this container.
 *  
 * @return the inventory and possible other important container data.
 * @author Thomas Bopp (astra@upb.de) 
 * @see restore_container
 */
mixed store_container()
{
    if (CALLER != _Database )
	THROW("Caller is not Database !", E_ACCESS);
    
    return ([ "Inventory": oaInventory, ]);
}

/**
 * Get the content size of this object which does not make really
 * sense for containers.
 *  
 * @return the content size: -2 as the container can be seen as an inventory
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see stat
 */
int get_content_size()
{
    return -2;
}

/**
 * This function returns the stat() of this object. This has the 
 * same format as statting a file.
 *  
 * @return status array as in file_stat()
 * @author Thomas Bopp (astra@upb.de) 
 * @see get_content_size
 */
array(int) stat()
{
    int creator_id = objectp(get_creator())?get_creator()->get_object_id():0;

    return ({ 16895, get_content_size(), 
		  do_query_attribute(OBJ_CREATION_TIME),
		  do_query_attribute(CONT_LAST_MODIFIED),
		  time(),
		  creator_id, creator_id, "httpd/unix-directory" });
}

/**
  * The function returns an array of important events used by this
  * container. In order to observe the actions inside the container,
  * the events should be heared.
  *  
  * @return Array of relevant events
  */
array(int) observe() 
{
    return ({ EVENT_SAY, EVENT_LEAVE_INVENTORY, EVENT_ENTER_INVENTORY });
}

/**
 * This function sends a message to the container, which actually
 * means the say event is fired and we can have a conversation between
 * users inside this container.
 *  
 * @param msg - the message to say
 * @author Thomas Bopp (astra@upb.de) 
 */
bool message(string msg)
{
    /* does almost nothing... */
    try_event(EVENT_SAY, CALLER, msg);
    run_event(EVENT_SAY, CALLER, msg);
    return true;
}

/**
 * Called when a user enters this container as part of the login
 * procedure. The login event is fired.
 *  
 * @param object obj - the object entering the system
 */
void enter_system(object obj)
{
    run_event(EVENT_LOGIN, CALLER, obj);
}

/**
 * Called when a user logs out and just runs the logout event.
 *  
 * @param object obj - the user logging out.
 */
void leave_system(object obj)
{
    run_event(EVENT_LOGOUT, CALLER, obj);
}

/**
 * Swap the position of two objects in the inventory. This
 * function is usefull for reordering the inventory.
 * You can sort an inventory afterwards or use the order of
 * objects given in the list (array).
 *  
 * @param int|object from - the object or position "from"
 * @param int|object to   - the object or position to swap to
 * @return if successfull or not (error)
 * @see get_inventory
 * @see insert_obj
 * @see remove_obj
 */
bool swap_inventory(int|object from, int|object to)
{
    int sz = sizeof(oaInventory);

    if ( objectp(from) )
	from = search(oaInventory, from);
    if ( objectp(to) )
	to = search(oaInventory, to);
    
    ASSERTINFO(from >= 0 && from < sz && to >= 0 && to < sz && from != to,
	       "False position for inventory swapping !");
    object from_obj = oaInventory[from];
    object to_obj   = oaInventory[to];
    oaInventory[from] = to_obj;
    oaInventory[to]   = from_obj;
    require_save();
    return true;
}

/**
 * Changes the order of the inventory by passing an order array,
 * the standard pike sort function is used for this and sorts
 * the array the same way order is sorted (integer values, by numbers).
 *  
 * @param array order - the sorting order.
 * @return whether sorting was successfull or not.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool order_inventory(array order)
{
    ASSERTINFO(sizeof(order) == sizeof(oaInventory), 
	       "Sizeof order array does not match !");
    
    sort(order, oaInventory);
    require_save();
}

/**
 * Get an object by its name from the inventory of this Container.
 *  
 * @param string obj_name - the object to get
 * @return 0|object found by the given name
 * @see get_inventory
 * @see get_inventory_by_class
 */
object get_object_byname(string obj_name, object|void o)
{
    oaInventory -= ({ 0 });
    
    foreach ( oaInventory, object obj ) {
	mixed cerr;
	if ( objectp(o) && o == obj ) continue;
	    
	obj = obj->get_object();
	if ( !objectp(obj) ) continue;
	
	if ( objectp(obj) && obj_name == obj->get_identifier() ) {
	    if ( obj->get_object_class() & CLASS_EXIT )
		return obj->get_exit();
	    if ( obj->get_object_class() & CLASS_LINK ) 
		return obj->get_link_object();
	    return obj->this();
	}
    }
    return 0;
}


/**
 * Get the users present in this Room. There shouldnt be any User
 * inside a Container.
 *  
 * @return array(object) of users.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(object) get_users() 
{
    array(object) users = ({ });
    foreach(get_inventory(), object inv) {
        if ( inv->get_object_class() & CLASS_USER )
            users += ({ inv });
    }
    return users;
}

/**
 * Get the object class of Container.
 *  
 * @return the object class of container. Check with CLASS_CONTAINER.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_object_class()
{
    return ::get_object_class() | CLASS_CONTAINER;
}

/**
 * Is this an object ? yes!
 *  
 * @return true
 */
final bool is_container() { return true; }


string describe()
{
    return get_identifier()+"(#"+get_object_id()+","+
	master()->describe_program(object_program(this_object()))+","+
	get_object_class()+","+sizeof(get_inventory())+" objects)";
}


