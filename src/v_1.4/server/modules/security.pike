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
inherit "/kernel/module";

#include <macros.h>
#include <access.h>
#include <assert.h>
#include <attributes.h>
#include <roles.h>
#include <database.h>
#include <classes.h>
#include <events.h>

//! The security module handles all security issues in sTeam. It
//! listens to almost any event globally and tries to block events
//! if permission checks fail.

#define CACHE_AVAILABLE (SECURITY_CACHE && objectp(obj))

private static array(string) sRegisteredPermissions;
private static mapping       mValidObjects = ([ ]);

/**
 * Load this security module and add all global events which
 * are relevant for security. E.g. should have callback functions
 * in this module.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
static void load_module()
{
    add_global_event(EVENT_MOVE, access_move, PHASE_BLOCK);
    add_global_event(EVENT_GET_INVENTORY, access_read, PHASE_BLOCK);
    add_global_event(EVENT_ATTRIBUTES_CHANGE, access_attribute_change, 
		     PHASE_BLOCK);
    add_global_event(EVENT_ATTRIBUTES_ACQUIRE, access_attribute_acquire,
		     PHASE_BLOCK);
    add_global_event(EVENT_ATTRIBUTES_LOCK, access_attribute_lock,
		     PHASE_BLOCK);
    add_global_event(EVENT_DOWNLOAD, access_read, PHASE_BLOCK);
    add_global_event(EVENT_DUPLICATE, access_read, PHASE_BLOCK);
    add_global_event(EVENT_UPLOAD, access_write, PHASE_BLOCK);
    add_global_event(EVENT_ATTRIBUTES_QUERY,access_read_attribute,PHASE_BLOCK);
    add_global_event(EVENT_DELETE, access_delete, PHASE_BLOCK);
    add_global_event(EVENT_REGISTER_ATTRIBUTE, access_register_attribute, 
		     PHASE_BLOCK);
    add_global_event(EVENT_EXECUTE, access_execute, PHASE_BLOCK);
    add_global_event(EVENT_REMOVE_MEMBER, access_group_remove_member, 
		     PHASE_BLOCK);
    add_global_event(EVENT_ADD_MEMBER, access_group_add_member, PHASE_BLOCK);
    add_global_event(EVENT_GRP_ADD_PERMISSION, access_group_add_permission,
		     PHASE_BLOCK);
    add_global_event(EVENT_GRP_ADDMUTUAL, access_group_addmutual, PHASE_BLOCK);
    add_global_event(EVENT_USER_CHANGE_PW, access_change_password, 
		     PHASE_BLOCK);
    add_global_event(EVENT_SANCTION, access_sanction_object, PHASE_BLOCK);
    add_global_event(EVENT_SANCTION_META, access_sanction_object_meta, 
		     PHASE_BLOCK);
    add_global_event(EVENT_ANNOTATE, access_annotate, PHASE_BLOCK);
    add_global_event(EVENT_ARRANGE_OBJECT, access_arrange, PHASE_BLOCK);
    
    sRegisteredPermissions = allocate(16);
    for ( int i = 0; i < 16; i++ )
	sRegisteredPermissions[i] = "free";
    sRegisteredPermissions[8] = "sanction";
    sRegisteredPermissions[0] = "read";
    sRegisteredPermissions[1] = "execute";
    sRegisteredPermissions[2] = "move";
    sRegisteredPermissions[3] = "write";
    sRegisteredPermissions[4] = "insert";
    sRegisteredPermissions[5] = "annotate";
}

/**
 * This is a callback function called from the master() object when this
 * module is upgraded. The master() object is a concept of the pike 
 * programming language. Upgrading is a key concept of sTeam.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
void upgrade()
{
    if ( CALLER != master() ) 
	return;
    remove_global_events();
}

/**
 * check if the given object is a valid proxy
 *  
 * @param obj - the object to check
 * @return if valid or not
 * @author Thomas Bopp (astra@upb.de) 
 * @see valid_object
 * @see valid_user
 * @see valid_group
 */
bool valid_proxy(object obj)
{
    object o;

    if ( obj == 0 || !functionp(obj->get_object) )
	return false;

    o = obj->get_object();
    if ( !objectp(o) )
	return true;

    return o->trust(obj);
}

/**
 * check if the given object is a valid user
 *  
 * @param obj - the object to check
 * @return if object is valid user or not
 * @author Thomas Bopp (astra@upb.de) 
 * @see valid_object
 * @see valid_user
 * @see valid_group
 */
bool valid_user(object obj)
{
    if ( valid_proxy(obj) )
	obj = obj->get_object();

    program pUser = (program)"/classes/User.pike"; // cache User

    if ( object_program(obj) == pUser ) {
	SECURITY_LOG("["+obj->get_identifier()+"] is valid user !");
	return true;
    }
    return false;
}

/**
 * check if the object is a valid object, that is inherits access.pike
 *  
 * @param obj - the object to check
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see valid_object
 * @see valid_user
 * @see valid_group
 */
bool valid_object(object obj)
{
    program pObject, pAccess, prg;

    prg = object_program(obj);
    if ( mValidObjects[prg] )
	return true;

    if ( valid_proxy(obj) ) {
	obj = obj->get_object();
	prg = object_program(obj);
    }


    pObject = (program)"/classes/Object.pike";
    pAccess = (program)"/base/access.pike";
    /* see if it inherits the access object to make sure
     * access functions are from the right place
     * or if the object is /classes/Object.pike clone itself */
    if ( Program.inherits(prg, pAccess) || prg == pObject ) {
	mValidObjects[prg] = true;
	return true;
    }
    return false;
}

/**
 * see if the object is a valid group, that is clone of Group.pike
 *  
 * @param obj - the object to check
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see valid_object
 * @see valid_user
 * @see valid_group
 */
bool valid_group(object obj)
{
    if ( valid_proxy(obj) ) obj = obj->get_object();
    program pGroup = (program)"/classes/Group.pike";
    if ( object_program(obj) == pGroup )
	return true;

    return false;
}


/**
 * check role permission of user groups recursively
 *  
 * @param grp - the group that wants to write
 * @param accessRole - the role that the group must feature
 * @return if successfull or not
 * @author Thomas Bopp 
 * @see try_access_object
 */
final bool
check_role_permission(object grp, int roleBit)
{
    object parentGroup;
    object     obj = 0;
    
    if ( roleBit == 0 ) // no special role permission granted
	return false;

    grp = grp->get_object();
    if ( !objectp(grp) ) 
	return false;

    ASSERTINFO(valid_group(grp), "Group:" + grp->get_identifier() +
	       " is not a valid group");
    SECURITY_LOG("Checking role permissions on " + 
		 grp->get_identifier() + 
		 "(permission="+grp->get_permission()+")");
    
    if ( grp->features(roleBit) ) 
	return true; // group has permission itself
    
    array(object) grp_groups = grp->get_groups();
    foreach( grp_groups, object member ) {
	LOG("Accessing indirectly by " + member->get_identifier());
	if ( objectp(member) && valid_group(member) ) {
	    if ( check_role_permission(member, roleBit) )
		return true;
	}
    }
    /* check the parent group for permission otherwise */
    return false;
}

/**
 * try to access an object by one of the users groups
 *  
 * @param obj - the object accessed
 * @param user - the active user
 * @param accessBit - the access Bit used
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see check_access
 */
private static bool 
check_access_user(object obj, object user, int accBit, int roleBit,bool meta)
{
    int                i;
    array(object) groups;

    int userAcc  = ACCESS_GRANTED;
    int groupAcc = ACCESS_GRANTED;
    
    SECURITY_LOG("check_access_user("+
		 (objectp(obj) ? obj->get_identifier()+"["+
		  obj->get_object_id()+"]," : "null,") +
		 user->get_identifier()+","+
		 accBit + ","+ roleBit+","+ meta+")");
    
    if ( CACHE_AVAILABLE && !meta ) {
	if ( SECURITY_CACHE->get_permission(obj, user) & 
	     (accBit<<SANCTION_SHIFT_DENY) ) 
	    return false;
	else if ( SECURITY_CACHE->get_permission(obj, user) & accBit ) {
	    return true;
	}
    }
    if ( objectp(obj) ) 
    {
	userAcc = obj->try_access_object(user, accBit, meta);
	if ( userAcc == ACCESS_GRANTED ) {
	    if ( CACHE_AVAILABLE ) {
		SECURITY_CACHE->add_permission(obj, user, accBit);
	    }
	    return true;
	}
    }
    
    groups = user->get_groups();

    SECURITY_LOG("Checking access for " + sizeof(groups) + 
		 " groups (accessbit="+accBit+",rolebit="+roleBit+")!");
    /* go through all groups and see if the general roleBit works
     * or if the group is able to access the object */
    for ( i = sizeof(groups) - 1; i >= 0; i-- ) {
	if ( !objectp(groups[i]) ) 
	    THROW("User is in 0-group - this should not happen !", E_ERROR);
	
	if ( roleBit > 0 ) {
	    if ( check_role_permission(groups[i], roleBit) ) {
		SECURITY_LOG("Role permission success !");
		if ( CACHE_AVAILABLE && !meta )
		    SECURITY_CACHE->add_permission(obj, user, accBit);
		return true;
	    }
	}
	/* if user/group access is once blocked only the above role
	 * permission might work
	 * this is to still have the admin groups do everything
	 */
	if ( accBit > 0 && userAcc != ACCESS_BLOCKED )
	    // &&groupAcc != ACCESS_BLOCKED )  - no more group blocking
	{
	    groupAcc = obj->try_access_object_group(groups[i], accBit, meta);
	    if ( groupAcc == ACCESS_GRANTED ) {
		if ( CACHE_AVAILABLE && !meta )
		    SECURITY_CACHE->add_permission(obj, user, accBit);
		SECURITY_LOG("Group direct access !");
		return true;
	    }
	}
    }    
    if ( CACHE_AVAILABLE && !meta )
	SECURITY_CACHE->add_permission(obj,user,accBit<<SANCTION_SHIFT_DENY);
    return false;
}

/**
 * check on some accessBit/roleBit. Object can be null when just 
 * the roleBit of an user should be checked.
 *  
 * @param obj - the object accessed (must be proxy)
 * @param caller - the calling object (must be the proxy or socket)
 * @param accessBit - the bit used for access
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see check_access_group
 */
bool 
check_access(object obj, object caller, int accessBit, int roleBit, bool meta)
{
    object         read_user;
    object        call_owner;
    string         sanctions;
    int                    i;
     
    sanctions = " for ("+roleBit+"), ";
    for ( i = 0; i <= 8; i++ )
	if ( accessBit & (1<<i) )
	    sanctions += sRegisteredPermissions[i] + ",";
    
    SECURITY_LOG("----------------------------------------------------------"+
		 "\n--- Access checking "+sanctions+ " by " + 
		 function_name(backtrace()[-3][2]) + "() on " +ctime(time()));

    if ( objectp(obj) )
	SECURITY_LOG("Checking access on ["+obj->get_identifier() + ","+
	    obj->get_object_id()+"]");
    if ( !objectp(caller) )
	THROW("No Caller found ???!!!", E_ERROR);
    
    if ( trust(caller) )
	return true;    // some objects are allowed to do everything
    SECURITY_LOG("CALLER:" + master()->stupid_describe(object_program(caller),255));
    SECURITY_LOG("CALLER-ID:"+caller->get_object_id());
    
    // access for world-user-group, no login required
    object grp = _WORLDUSER;
    if ( objectp(obj) && objectp(grp) &&
	 obj->try_access_object(grp, accessBit, meta) ) 
    {
	SECURITY_LOG("Access granted################################\n");
        return true;
    }
    if ( IS_SOCKET(caller) ) {
	// socket objects are connected to one user object, check user instead
	caller = caller->get_user_object();
    }
    
    if ( !valid_proxy(caller) )
	caller = caller->this(); // get the real object from proxy
    if ( !valid_object(caller->get_object()) )
	THROW("Caller is no valid object !", E_ACCESS);
    
    if ( !objectp(caller) ) 
	THROW("No calling object for checking access !", E_ACCESS);

    if ( caller == obj )
	return true; // caller and object are identical

    read_user = this_user();
    if ( !objectp(read_user) )
	return true; // the server is rebooting, so no active user

    SECURITY_LOG("CALLER:" + master()->stupid_describe(caller,255)+","+
		 caller->get_identifier());
    SECURITY_LOG("ACTIVE:" + master()->stupid_describe(read_user, 255)+","+
		 read_user->get_identifier());
    
    if ( caller == read_user ) {
	// direct call from the user object
	SECURITY_LOG("User-Check for permissions...");
	if ( check_access_user(obj, read_user, accessBit, roleBit, meta) )
	    return true;
    }
    else {
	if ( !functionp(caller->get_creator) ) 
	    THROW("Access denied - caller has no creator !", E_ACCESS);

	/* otherwise creator of an object is relevant, since objects
	 * itself are usually not sanctioned by other objects */
	// if we get a Script, we need to use the corresponding DocLPC
	if ( caller->get_object_class() & CLASS_SCRIPT ) {
	  caller = caller->get_source_object();
	  if ( !objectp(caller) )
	    error("Error while checking script access! No source object.");
	}
	call_owner = caller->get_creator();

	ASSERTINFO(objectp(call_owner), "Object ["+caller->get_identifier()+
		   ","+caller->get_object_id()+"] has no creator !");
	ASSERTINFO(valid_user(call_owner), "Invalid owner of calling object:"+
		   call_owner->get_identifier());

	/* caller and read_user must be allowed to access the object */
	if ( check_access_user(obj, read_user, accessBit, roleBit, meta) &&
	     check_access_user(obj, call_owner, accessBit, roleBit,meta) )
	    return true;
	
    }
    SECURITY_LOG("Access denied.");
    THROW("Access denied !", E_ACCESS);
    return false;
}

/**
 * check for read access
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_write
 */
bool access_read(object obj, object caller)
{
    return check_access(obj, caller, SANCTION_READ, ROLE_READ_ALL, false);
}

/**
 * check for write access
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_read
 */
bool access_write(object obj, object caller)
{
    return check_access(obj, caller, SANCTION_WRITE, ROLE_WRITE_ALL, false);
}

/**
 * Check whether an object is able to set the creator of object obj.
 * Usually the creator is only set when the object is created, but
 * export/import functionality requires to change such values.
 *  
 * @param object obj - the object with a new creator
 * @param object caller - the calling object
 * @return true or throws an error.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool access_set_creator(object obj, object caller)
{
    if ( _Server->is_a_factory(CALLER) )
	return true;
    return check_access(obj, caller, SANCTION_ALL, ROLE_ALL_ROLES, true);
}

/**
 * check access for deleting objects. Same as write access currently.
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
bool access_delete(object obj, object caller)
{
    return check_access(obj, caller, SANCTION_WRITE, ROLE_WRITE_ALL, false);
}

/**
 * check access for deleting objects. Same as write access currently.
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
bool access_register_module(object obj, object caller)
{
    return check_access(0, caller, 0, ROLE_REGISTER_MODULES, false);
}
/**
 * check access for deleting objects. Same as write access currently.
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
bool access_register_class(object obj, object caller)
{
    return check_access(0, caller, 0, ROLE_REGISTER_CLASSES, false);
}

/**
 * access_move
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @param dest - destination of movement
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_read
 */
bool access_move(object obj, object caller, object from, object dest)
{
#if 0
    if ( caller == obj->get_environment() )
	return true;
#endif

    /* if the caller is the object, then the user moves herself !
     * otherwise check insert access */
    LOG("CALLER is user ?:"+valid_user(caller));

    if ( !valid_user(obj) ) {
      // Inserting objects into a room requires insert permissions
      if (!check_access(dest, caller, SANCTION_INSERT, ROLE_INSERT_ALL, false))
	return false;
    }
    else {
      // moving the user somewhere only requires permissions for the user
      if (!check_access(dest, obj, SANCTION_READ, ROLE_READ_ALL, false))
        return false;
    }
    
    object env = obj->get_environment();
#if 0
    if ( !check_access(dest, caller, SANCTION_READ, ROLE_READ_ALL, false) )
	return false;
#endif

    // if the user/caller is able to move the room, she can move the 
    // object in the container/room too
    if ( objectp(env) ) {
	mixed err = catch { 
	    if ( check_access(env, caller,SANCTION_MOVE,ROLE_MOVE_ALL,false) ) {
		if ( CACHE_AVAILABLE ) {
		    SECURITY_CACHE->remove_permission(obj);
		}
		return true;
	    }
	};
    }
    if ( !check_access(obj, caller, SANCTION_MOVE, ROLE_MOVE_ALL, false) )
	return false;
#if 0
    if ( !check_access(dest, caller, SANCTION_READ, ROLE_READ_ALL, false) )
	return false;
#endif
    if ( CACHE_AVAILABLE )
	SECURITY_CACHE->remove_permission(obj);
    return true;
}

/**
 * Check if a user/object is able to annotated an object.
 *  
 * @param object obj - the object to annotate
 * @param object caller - the calling object
 * @param annotation - the added annotation
 * @return true or throws an error
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
bool access_annotate(object obj, object caller, object annotation)
{
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory
    if ( !check_access(obj, caller, SANCTION_ANNOTATE, 
		       ROLE_ANNOTATE_ALL, false) )
	return false;
    return true;
}

/**
 * Check if arranging an object is allowed.
 *  
 * @param object obj - the object to arrange
 * @param object caller - the calling object
 * @param float x - the new x position
 * @param float y - the new y position
 * @param float z - the new z position
 * @param bool locked - is the position already locked (returns false)
 * @return true or false or throws an error
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool access_arrange(object obj, object caller, float x, float y, float z, 
		    bool locked)
{
    if ( locked ) return false;
    return true;
    if ( !check_access(obj, caller, SANCTION_WRITE, ROLE_WRITE_ALL, false) )
	return false;
    return true;
}

/**
 * check access for creating an object
 *  
 * @param caller - the calling object
 * @return true or false 
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_create_group
 */
bool access_create_object(object caller)
{
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory
    if ( caller->get_object_class() & CLASS_DOCLPC ) {
	// in general means its a factory,but only for the object to be created
	if ( object_program(CALLER) == caller->get_program() )
	    if ( check_access(caller, caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL, false) )
		return true; // need access on the DocLPC in this case !
    }
    object factory = _Server->get_factory(caller->get_object_class());
    if ( !objectp(factory) ) 
	factory = _Server->get_factory(CLASS_DOCUMENT);
    if ( !check_access(factory, caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL, false) )
	return false;
    return true;
}

/**
 * Check if its valid to add an object to the group grp.
 *  
 * @param grp - the group to add someone to
 * @param caller - the calling object
 * @param add - the group/user to add
 * @param bool pw - group password check was done and successfull
 * @return true or false or throws an error
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_group_add_member(object grp, object caller, object add, bool pw)
{
    if ( pw ) {
	if ( SECURITY_CACHE )
	    SECURITY_CACHE->remove_permission_user(add);
	return true;
    }
    
    if ( _Server->is_a_factory(caller) ) {
	if ( SECURITY_CACHE )
	    SECURITY_CACHE->remove_permission_user(add);
	return true;   
    }

    if ( !check_access(grp, caller, SANCTION_INSERT, ROLE_INSERT_ALL, false) )
	return false;
    if ( SECURITY_CACHE )
	SECURITY_CACHE->remove_permission_user(add);
    return true;
	
}

/**
 * Check if a user is allowed to add users to all groups in a
 * mutual exclusive group cluster.
 *
 * @param grp - the group to add "add" to
 * @param caller - the calling object
 * @add   add - the group to add to "grp"
 * @return true - access is granted
 *         false - access denied
 *         throws an error according to check_access
 * @see    check_access
 * @author Ludger Merkens (balduin@upb.de)
 */
bool access_group_addmutual(object grp, object caller, object add)
{
    if (!valid_group(grp) || !valid_group(add))
        return false;
    array(object) need_access = grp->get_mutual_list();

    foreach(need_access, object g)
        if (!check_access(g, caller, SANCTION_INSERT,
                          ROLE_INSERT_ALL, true))
            return false;
    return check_access(add, caller, SANCTION_INSERT, ROLE_INSERT_ALL, true);
}

/**
 * Check if the calling object and the current user are
 * allowed to create a new group.
 *  
 * @param object caller - the calling object
 * @return true or false or throws an access error
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_create_group(object caller)
{
    if ( _Server->is_a_factory(caller) )
	return true;
    object factory = _Server->get_factory(CLASS_GROUP);
    if ( !check_access(factory, caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL, false))
	return false;
    return true;
}

/**
 * Check whether a calling object and the current user 
 * are able to create a new user. Usually this is allowed since 
 * people are able to register their user themself.
 *  
 * @param object caller - the calling object
 * @return true or false or throws access error
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_create_user(object caller)
{
    if ( _Server->is_a_factory(caller) )
	return true;
    object factory = _Server->get_factory(CLASS_USER);
    if ( !check_access(factory, caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL , false))
	return false;
    return true;
}

/**
 * Check if the calling object is allowed to create a new document.
 *  
 * @param object caller - the calling object
 * @return true or false or throws an access error.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_create_document(object caller)
{
    if ( _Server->is_a_factory(caller) )
	return true;
    object factory = _Server->get_factory(CLASS_DOCUMENT);
    if ( !check_access(factory, caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL , false))
	return false;
    return true;
}

/**
 * Check if meta sanction is changeable by caller.
 *  
 * @param object obj - the object to change meta sanction access
 * @param object caller - the calling object
 * @param object grp - the group to sanction
 * @param int p - the meta access persmissions
 * 
 * @return true, false or throw access
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool access_sanction_object_meta(object obj, object caller, object grp, int p)
{
    if ( _Server->is_a_factory(caller) )
	return true;
    check_access(obj, caller, p, ROLE_SANCTION_ALL, false);
    check_access(obj, caller, SANCTION_SANCTION, ROLE_SANCTION_ALL, true);
    check_access(obj, caller, p, ROLE_SANCTION_ALL, true);
}

/**
 * Check if caller has permissions to sanction group grp with access
 * 'p'.
 *  
 * @param object obj - the object to change meta sanction access
 * @param object caller - the calling object
 * @param object grp - the group to sanction
 * @param int p - the access persmissions
 * @return true or false or throw access error
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool access_sanction_object(object obj, object caller, object grp, int p)
{
    if ( _Server->is_a_factory(caller) )
	return true;

    check_access(obj, caller, p|SANCTION_SANCTION, ROLE_SANCTION_ALL, true);
    check_access(obj, caller, p|SANCTION_SANCTION, ROLE_SANCTION_ALL, false);
    if ( CACHE_AVAILABLE )
	SECURITY_CACHE->remove_permission(obj);
}

/**
 *
 * Check if the calling object has permission to listen to events on obj.
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_read
 */
bool access_event_listen(object obj, object caller)
{
    return check_access(obj, caller, SANCTION_READ, ROLE_READ_ALL, false);
}

/**
 * Check if calling object is able to change data in object 'obj'. This
 * usually means changing a documents content.
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_read
 */
bool access_data_change(object obj, object caller, mixed id, mixed data)
{
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory

    if ( !access_write(obj, caller) )
	THROW("No Access to change data !", E_ACCESS);
    return true;
}

/**
 * Check if caller is able to change attributes in object 'obj'.
 *  
 * @param object obj - the object to change an attribute.
 * @param object caller - the calling object.
 * @param attr - the attribute to change
 * @return true or false or throw access error
 * @author Thomas Bopp (astra@upb.de) 
 */
bool 
access_attribute_change(object obj, object caller, mixed attr)
{
    //    LOG("Access for changing the attribute ?");
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory
    //    LOG("not a factory ");
    
    if ( !access_write(obj, caller) )
	THROW("No Access to change attributes !", E_ACCESS);
    return true;
}

/**
 * Check whether an object has permissions to lock attributes in object 'obj'.
 *  
 * @param object obj - the object to lock attributes in.
 * @param object caller - the calling object.
 * @param bool l_or_ul - lock or unlock attributes.
 * @return true or false or throw an access error.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool access_attribute_lock(object obj, object caller, bool l_or_ul)
{
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory
    if ( !access_write(obj, caller) )
	THROW("No Access to lock/unlock attributes !", E_ACCESS);
    return true;
}

/**
 * Check if caller is able to change acquiring setting for an attribute.
 *  
 * @param object obj - the object.
 * @param object caller - the calling object.
 * @param mixed key - the attribute to change acquiring for.
 * @param mixed acquire - new acquiring setting.
 * @return true or false or throw access error.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool 
access_attribute_acquire(object obj, object caller, mixed key, mixed acquire)
{
    if ( objectp(acquire) && !valid_proxy(acquire) )
	THROW("Acquring must point to proxy !", E_ERROR);
    
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory

    
    if ( !access_write(obj, caller) )
	THROW("No Access to write data !", E_ACCESS);
    return true;
}

/**
 * Check if the caller is able to read an attribute.
 *  
 * @param object obj - the object to read.
 * @param object caller - the calling object.
 * @param mixed key - the attribute to read.
 * @return true or false or throw access denied.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool 
access_read_attribute(object obj, object caller, mixed key)
{
    if ( !access_read(obj, caller) )
	THROW("No Access to read data !", E_ACCESS);
    return true;
}

/**
 * Check whether the calling object is able to register attributes.
 *  
 * @param object obj - the object to register an attribute.
 * @param object caller - the calling object.
 * @param mixed key - the attribute to register.
 * @return true or false or throw access denied.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool 
access_register_attribute(object obj, object caller, mixed key)
{
    object factory = _Server->get_factory(obj->get_object_class());
    if ( caller == factory ) return true;

    if ( !access_write(obj, caller) )
	THROW("No Access to register data !", E_ACCESS);
    return true;
}

/**
 * access_execute
 *  
 * @param obj - the object accessed
 * @param caller - the calling object
 * @return true or false
 * @author Thomas Bopp (astra@upb.de) 
 * @see access_read
 */
bool access_execute(object obj, object caller)
{
    if ( _Server->is_a_factory(caller) ) // trust any factory for creation
	return true; // ok, for any factory
    
    LOG("Checkign execution access on " + master()->describe_object(obj));
    return check_access(obj,caller, SANCTION_EXECUTE, ROLE_EXECUTE_ALL, false);
}

/**
 * Check if the caller is able to add permissions to the group 'grp'.
 *  
 * @param object grp - the group to add permissions.
 * @param object caller - the calling object.
 * @param int permission - permissions to add.
 * @return true or false or throw access denied.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool 
access_group_add_permission(object grp, object caller, int permission)
{
    ASSERTINFO(valid_group(grp), "No valid group in group_add_permission()");
    if ( !check_access(0, caller, 0, ROLE_GIVE_ROLES, false) )
	return false;
    if ( !check_access(grp, caller, SANCTION_WRITE, ROLE_WRITE_ALL, false) )
	return false;
    return true;
}

/**
 * add a user or list of users to a group
 *  
 * @param object grp - the group to remove a member
 * @param object caller - the calling object.
 * @param object user - the user or group to remove.
 * @return number of users successfully added
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_group_remove_member(object grp, object caller, object user)
{
    if ( !check_access(grp, caller, SANCTION_INSERT, ROLE_INSERT_ALL, false) )
	return false;
    if ( SECURITY_CACHE )
	SECURITY_CACHE->remove_permission_user(user);
    return true;
}

/**
 * set acquiring object for object "obj"
 *  
 * @param obj - the object that acquires
 * @param from - the object to acquire from
 * @return successfully or not
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_acquire(object obj, object caller, object from)
{
    object factory = _Server->get_factory(obj->get_object_class());
    if ( caller == factory )
	return true;
    if ( !check_access(obj, caller, SANCTION_WRITE, ROLE_WRITE_ALL, false) )
	return false;
    if ( CACHE_AVAILABLE )
	SECURITY_CACHE->remove_permission(obj);
    return true;
}


/**
 * Check if caller has permissions to change password for user.
 *  
 * @param object user - the user object.
 * @param object caller - the calling object.
 * @return true or false or throw access denied.
 * @author Thomas Bopp (astra@upb.de) 
 */
bool access_change_password(object user, object caller)
{
    object factory = _Server->get_factory(user->get_object_class());
    LOG("Caller:"+master()->describe_object(caller) + ", Factory:"+
	master()->describe_object(factory));
    if ( caller == factory ) return true;

    if ( caller != user && 
	 (!IS_SOCKET(caller) || user != caller->get_user_object()) && 
	 !check_access(user, caller, 0, ROLE_CHANGE_PWS, false) )
	return false;
    return true;
}

/**
 * Get the identifier string for this module.
 *  
 * @return The module identifier.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string get_identifier()
{
    return "security";
}

/**
 * The function returns if some object is especially trusted.
 *  
 * @param object obj - the object to check.
 * @return true or false.
 * @author Thomas Bopp (astra@upb.de) 
 */
final bool trust(object obj)
{
    int              i;
    array(string) inds;
    
    if ( ::trust(obj) ) return true;
    if ( obj == this_object() ) return true;
    if ( obj == master() ) return true;
    if ( obj == _Database ) return true;
    if ( obj == _Server ) return true;
    if ( obj == _FILEPATH ) return true;

    return false;
}

/**
 * Check if a user is allowed to access the given objects.
 *  
 * @param array(object) objs - an array of objects to check access for.
 * @return Mapping with object:permissions of current user.
 * @author Thomas Bopp (astra@upb.de) 
 * @see check_access
 */
mapping 
check(array(object) objs)
{
    int   i, sz;
    object user;
    mixed   err;
    mapping   m;

    user = this_user()->this();
    foreach(objs, object obj) {
	m[obj] = 0;
	for ( i = sizeof(sRegisteredPermissions) - 1 ; i >= 0; i-- ) {
	    if ( check_access_user(obj->this(), user, 1<<i, 1<<i, false) )
		m[obj] |= 1<<i;
	}
    }
    return m; 
}

/**
 * Check access for a given user for accessBit and roleBit.
 *  
 * @param object obj - the object to check.
 * @param object user - the user to check access for.
 * @param int accBit - the access bit to check.
 * @param int roleBit - the roleBit to check.
 * @param bool meta - if normal or meta permissions are to check.
 * @return true or false or throw an access error.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool 
check_user_access(object obj, object user, int accBit, int roleBit, bool meta)
{
    if ( !objectp(user) )
	THROW("User undefined !", E_ACCESS);
    return check_access_user(obj->this(), user->this(),accBit,roleBit, meta);
}

/**
 * Get the meta access of object 'obj' for user 'user'.
 *  
 * @param object obj - the object to get meta access for.
 * @param object user - the user to get meta access for.
 * @return the meta access bit string.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_meta_access(object obj, object user)
{
    int meta = obj->query_meta_sanction(user);
    for ( int i = 0; i < 16; i++ )
	if ( check_user_access(obj, user, 1<<i,1<<i, true) )
	    meta |= (1<<i);
    return meta;
}



/**
 * Get an array of string descriptions for permissions.
 *  
 * @return array of string descriptions.
 * @author Thomas Bopp (astra@upb.de) 
 */
array(string) get_sanction_strings()
{
    return sRegisteredPermissions;
}

/**
 * Get the user permissions for object 'obj' and user 'user' with
 * access mask 'mask'.
 *  
 * @param object obj - the object to get user permissions for.
 * @param object user - object user.
 * @param int mask - the access mask.
 * @return user permission bit string.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_user_permissions(object obj, object user, int mask)
{
    int res = SECURITY_CACHE->get_permission(obj, user);
    int a, b, r;

    a = res & mask;
    b = (res & ( mask<<SANCTION_SHIFT_DENY)) >> SANCTION_SHIFT_DENY;
    r = ( a | b );
    if ( r == mask ) {
	return res;
    }
    // not all permissions are cached here !
    for ( int i = 0; i < SANCTION_SHIFT_DENY; i++ ) {
	if ( ((1<<i) & mask) && !(r & (1<<i)) )
	    check_access_user(obj->this(), user->this(), 1<<i, 1<<i, 0);
    }
    return SECURITY_CACHE->get_permission(obj, user);
}
