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
inherit "/classes/Object" : __object;
inherit "/base/member"    : __member;

#include <macros.h>
#include <roles.h>
#include <assert.h>
#include <classes.h>
#include <events.h>
#include <access.h>
#include <database.h>
#include <attributes.h>
#include <types.h>

private int              iGroupRoles; /* special privileges of the group */
private static string     sGroupName; /* the groups name */
private static string       sGroupPW; /* password for the group */
static  array(object) aoGroupMembers; /* members of the group */
static  array(object)      aoInvites; /* invited users */
static  array               aPending; /* waiting users */
static  array      aoExclusiveGroups; /* groups with mutual exclusive members*/
static  object               oParent; /* the groups parent */

object this() { return __object::this(); }

#define GROUP_ADMIN_ACCESS (SANCTION_INSERT|SANCTION_MOVE|SANCTION_WRITE)

/**
 * Initialization of the object. 
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create_object
 */
static void init()
{
    ::init();
    ::init_member(); // groups are also group members !
    aoGroupMembers = ({ });
    aoInvites      = ({ });
    aPending       = ({ });
    sGroupPW = "";
    add_data_storage(retrieve_group_data, restore_group_data);
}

/**
 * Constructor of the group.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see duplicate
 */
static void
create_object()
{
    ::create_object();
    iGroupRoles  = 0;
    sGroupName = "";
}

/**
 * Create a duplicate of this object.
 *  
 * @return the duplicate object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see create_object
 */
object duplicate()
{
    object dup_obj = ::duplicate();
    foreach( aoGroupMembers, object member ) {
	dup_obj->add_member(member);
    }
    return dup_obj;
}

/**
 * Set the parent group of this group.
 *  
 * @param object grp - the new parent
 * @see get_parent
 */
void set_parent(object grp)
{
    if ( _SECURITY->is_factory(CALLER) ) {
	oParent = grp;
	require_save();
    }
}

/**
 * Get the parent group. The group is identified by 
 * (parent->identifier).(groups name)
 *  
 * @return the parent group or zero
 */
object get_parent()
{
    foreach ( get_groups(), object grp ) {
	return grp; // any one group the group is a member of
    }
    return oParent;
}

array get_sub_groups()
{
  array subgroups =  ({ });
  foreach(get_members(), object member)
    if ( objectp(member) && member->status() >= 0 && 
	 member->get_object_class() & CLASS_GROUP )
      subgroups += ({ member });
  return subgroups;
}

/**
 * Called when created to register the group in the database.
 *  
 * @param string name - register as name
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void database_registration(string name)
{
    sGroupName = name;
    ASSERTINFO(MODULE_GROUPS->register(name, this()), 
	       "Registration of group " + name + " failed !");
    require_save();
}

/**
 * Set the groups name.
 *  
 * @param string name - the new name of the group
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void set_group_name(string name)
{
    if ( CALLER != _Server->get_factory(CLASS_GROUP) )
	THROW("Invalid call to set_group_name !", E_ACCESS);
    sGroupName = name;
    require_save();
}

/**
 * The destructor of the group object. Removes all members for instance.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see create
 */
static void 
delete_object()
{
    object member;
    mixed     err;

    foreach(aoGroupMembers, member) {
	member->leave_group(this());
	object wr  = member->query_attribute(USER_WORKROOM);
	object gwr = query_attribute(GROUP_WORKROOM);
	if ( objectp(wr) ) {
	    array inv = wr->get_inventory();
	    foreach(inv, object o) {
		if ( objectp(o) && o->get_object_class() & CLASS_EXIT &&
		     o->get_exit() == gwr )
		{
		    err = catch {
			// delete all exits of members to groups workroom
			o->delete();
		    };
		}
	    }
	}
    }
    MODULE_GROUPS->unregister(sGroupName);
    __object::delete_object();
    __member::delete_object();
}


/**
 * Checks if the group features some special privileges.
 *  
 * @param permission - does the group feature this permission?
 * @return true or false
 * @author Thomas Bopp 
 * @see add_permission
 */
nomask bool
features(int permission)
{
    if ( iGroupRoles & permission )
	return true;
    return false;
}

/**
 * Returns an integer describing the special privileges of the group.
 *  
 * @return permissions of the group
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_permission
 */
final int
get_permission()
{
    return iGroupRoles;
}

/**
 * Add special privileges to the group.
 *  
 * @param permission - add the permission to roles of group
 * @author Thomas Bopp 
 * @see features
 */
final bool
add_permission(int permission)
{
    try_event(EVENT_GRP_ADD_PERMISSION, CALLER, permission);
    iGroupRoles |= permission;
    require_save();
    run_event(EVENT_GRP_ADD_PERMISSION, CALLER, permission);
    return true;
}

/**
 * Set new default permissions for the group. These are role permissions
 * like read-everything,write-everything,etc. which is usually only
 * valid for the ADMIN gorup.
 *  
 * @param int permission - permission bit array.
 * @return true or throw and error.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_permission
 */
final bool
set_permission(int permission)
{
    try_event(EVENT_GRP_ADD_PERMISSION, CALLER, permission);
    iGroupRoles = permission;
    require_save();
    run_event(EVENT_GRP_ADD_PERMISSION, CALLER, permission);
    return true;
}

/**
 * Check if a given user is member of this group.
 *  
 * @param user - the user to check
 * @return true of false
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_member
 * @see remove_member
 */
final bool 
is_member(object user)
{
    int i;
    ASSERTINFO(IS_PROXY(user), "User is not a proxy !");
    for ( i = sizeof(aoGroupMembers) - 1; i >= 0; i-- ) {
	if ( aoGroupMembers[i] == user )
	    return true;
    }
    return false;
}

/**
 * See if a user is admin of this group. It doesnt require
 * membership in the group.
 *  
 * @param user - the user to check for admin
 * @return true of false
 * @author Thomas Bopp (astra@upb.de) 
 * @see is_member
 */
final bool 
is_admin(object user)
{
    int i;
    if ( !objectp(user) )
	return false;
    ASSERTINFO(IS_PROXY(user), "User is not a proxy !");
    return (query_sanction(user)&GROUP_ADMIN_ACCESS) == GROUP_ADMIN_ACCESS;
}

/**
 * Get all admins of a group. Other groups might be admins of a group
 * too.
 *  
 * @return array of admin objects (Users)
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see is_admin
 */
final array(object) get_admins()
{
  array(object) admins = ({ });

  foreach( aoGroupMembers, object member) {
      if ( is_admin(member) ) {
	  if ( member->get_object_class() & CLASS_GROUP )
	      admins += member->get_admins();
	  admins += ({ member });
      }
  }
  return admins;
}


/**
 * Add a new member to this group. Optionally a password can be 
 * passed to the function so the user joins with a password directly.
 *  
 * @param user - new member
 * @param string|void pass - the group password
 * @author Thomas Bopp (astra@upb.de) 
 * @see remove_member
 * @see is_member
 * @return 1 - ok, 0 - failed, -1 pending, -2 pending failed
 */
final bool 
add_member(object user, string|void pass)
{
    int    i;

    ASSERTINFO(IS_PROXY(user), "User is not a proxy !");
    if ( is_member(user) || user == this() )
	return false;

    LOG("PWCHECK:"+sGroupPW+":"+pass);

    /* run the event
     * Pass right password to security...
     * The user may add himself to the group with the appropriate password.
     * Invited users may also join
     */
    try_event(EVENT_ADD_MEMBER, CALLER, user, 
	      user == this_user() &&
	      (search(aoInvites, user) >= 0 ||
	       (stringp(pass) && strlen(sGroupPW) != 0 && pass == sGroupPW)));


    // make sure there wont be any loops
    if ( _SECURITY->valid_group(user) ) {
	array(object)  grp;
	array(object) mems;

	grp = ({ user });
	i   = 0;
	while ( i < sizeof(grp) ) {
	    mems = grp[i]->get_members();
	    foreach(mems, object m) {
		LOG("Member:"+m->get_identifier()+"\n");
		if ( m == this() ) 
		    THROW("add_member() recursion detected !", 
			  E_ERROR|E_LOOP);
		if ( _SECURITY->valid_group(m) )
		    grp += ({ m });
	    }
	    i++;
	}
    }
    // kick user from all exclusive parent groups sub-groups of this group ;)
    foreach( get_groups(), object group) {
	// user joins a subgroup
	LOG("Group to check:" + group->get_identifier()+"\n");
	if ( group->query_attribute(GROUP_EXCLUSIVE_SUBGROUPS) == 1 ) {
	    foreach ( group->get_members(), object xgroup ) 
		if ( xgroup->get_object_class() & CLASS_GROUP &&
		     xgroup->is_member(user) )
		    xgroup->remove_member(user);
	}
    }
    int size = query_attribute(GROUP_MAXSIZE);
    if (!size ||( user->get_object_class() & CLASS_GROUP) || 
	count_members() < size )
    {
        if ( !user->join_group(this()) ) 
            return false;
        aoGroupMembers += ({ user });

        remove_membership_request(user);
        if ( arrayp(aoInvites) )
            aoInvites -= ({ user });
    
        /* Users must be able to read the group for tell and say events */
        set_sanction(user, query_sanction(user)|SANCTION_READ);
    
        require_save();
        run_event(EVENT_ADD_MEMBER, CALLER, user);
        return true;
    } else
        return add_pending(user, pass);
}

/**
 * Get the number of members (users only)
 *  
 * @return the number of member users of this group
 */
int count_members()
{
    int cnt = 0;
    foreach(aoGroupMembers, object member)
	if ( member->get_object_class() & CLASS_USER )
	    cnt++;
    return cnt;
}



/**
 * Add a request to become member to this group. That is the current
 * use will become member of the group.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
void
add_membership_request()
{
    object user = this_user();
    
    do_append_attribute(GROUP_MEMBERSHIP_REQS, user);
}

/**
 * Check whether a given user requested membership for this group.
 *  
 * @param object user - the user to check
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool requested_membership(object user)
{
    return !arrayp(do_query_attribute(GROUP_MEMBERSHIP_REQS)) ||
        search(do_query_attribute(GROUP_MEMBERSHIP_REQS), user) >= 0;
}

/**
 * Remove a request for membership from the list of membership
 * requests of this group.
 *  
 * @param object user - remove the request of the user.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see add_membership_request
 */
static void remove_membership_request(object user)
{
    remove_from_attribute(GROUP_MEMBERSHIP_REQS, user);
}

/**
 * Get the array (copied) of membership requests for this group.
 *  
 * @return array of user objects requesting membership.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(object) get_requests()
{
    return copy_value(do_query_attribute(GROUP_MEMBERSHIP_REQS));
}

/**
 * Invite a user to join this group. If the current user has the
 * appropriate permissions the given user will be marked as invited
 * and may join for free.
 *  
 * @param object user - the user to invite.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see is_invited
 */
void invite_user(object user)
{
  try_event(EVENT_ADD_MEMBER, CALLER, user, 0);
  if ( search(aoInvites, user) >= 0 )
    THROW("Failed to invite user - user already invited !", E_ERROR);
  aoInvites += ({ user });
  require_save();
  run_event(EVENT_ADD_MEMBER, CALLER, user);
}

void remove_invite(object user)
{
  try_event(EVENT_REMOVE_MEMBER, CALLER, user);
  if ( search(aoInvites, user) == -1 )
    THROW("Failed to remove invitation for user - user not invited !", E_ERROR);
  aoInvites -= ({ user });
  require_save();
  run_event(EVENT_REMOVE_MEMBER, CALLER, user);
}

/**
 * Check if a given user is invited to join this group.
 *  
 * @param object user - the user to check.
 * @return true of false.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see invite_user
 */
bool is_invited(object user)
{
    if ( !arrayp(aoInvites) )
        aoInvites = ({ });

    return search(aoInvites, user) >= 0;
}


/**
 * Get all invited users of this group.
 *  
 * @return array of invited users
 */
array(object) get_invited()
{
    return copy_value(aoInvites);
}


/**
 * remove a member from the group.
 *  
 * @param user - the member to remove
 * @return if successfully
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_member
 */
final bool 
remove_member(object user)
{
    LOG("remove_member");
    ASSERTINFO(IS_PROXY(user), "User is not a proxy !");

    if ( !is_member(user)  && !is_pending(user) )
	return false;

    if (is_pending(user))
    {
	LOG("is pending");
        remove_pending(user);
        require_save();
    }
    else
    {
        LOG("actual member?");
        try_event(EVENT_REMOVE_MEMBER, CALLER, user);
        if ( !user->leave_group(this()) ) return false;
        set_sanction(user, 0);
        aoGroupMembers -= ({ user });
        require_save();
        run_event(EVENT_REMOVE_MEMBER, CALLER, user);

        // try to fill group with first pending
        if (arrayp(aPending) && sizeof(aPending) > 0 ) 
        {
            catch {
                add_member(aPending[0][0], aPending[0][1]);
                string msg = do_query_attribute(GROUP_MSG_ACCEPT);
                if (!msg)
                    msg = "You have been accepted to group:"+
                        do_query_attribute(OBJ_NAME);
                aPending[0][0]->message(msg);
                aPending = aPending[1..];
                require_save();
            };
        }
    }
    return true;
}

/**
 * returns the groups members
 *  
 * @return the groups members
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_member
 */
final array(object)
get_members(int|void classes)
{
    if ( classes != 0 ) {
	array(object) members = ({ });
	foreach(aoGroupMembers, object o) {
	    if ( o->get_object_class() & classes )
		members += ({ o });
	}
	return members;
    }
    return copy_value(aoGroupMembers);
}


/**
 * get the class of the object
 *  
 * @return the class of the object
 * @author Thomas Bopp (astra@upb.de) 
 */
int
get_object_class()
{
    return ::get_object_class() | CLASS_GROUP;
}

/**
 * Send an internal mail to all members of this group.
 *  
 * @param string msg - the message body.
 * @param string|void subject - an optional subject.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void mail(string msg, string|void subject)
{
    foreach (aoGroupMembers, object member) {
	if ( !objectp(member) ) continue;
	member->mail(msg, subject);
    }
}

/**
 * Set a new password for this group. A password is used to
 * allow users to join the group without waiting for someone to
 * accept their membership request.
 *  
 * @param string pw - the new group password.
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool set_group_password(string pw)
{
    if ( !_SECURITY->access_write(this(), CALLER) )
	THROW("Unauthorized call to set_group_password() !", E_ACCESS);
    LOG("set_group_password("+pw+")");
    sGroupPW = pw;
    require_save();
    return true;
}

/**
 * get the data of the group for saving
 *  
 * @return array of group data
 * @author Thomas Bopp (astra@upb.de) 
 * @see restore_group_data
 */
mapping
retrieve_group_data()
{
    ASSERTINFO(CALLER == _Database,
	       "retrieve_group_data() must be called by database !");
    return ([
	"GroupMembers":aoGroupMembers, 
	"GroupRoles":iGroupRoles,
	"Groups": aoGroups,
	"GroupPassword": sGroupPW,
	"GroupInvites": aoInvites,
	"GroupName": sGroupName,
        "GroupPending": aPending,
	"Parent": oParent,
	]);
}

/**
 * restore the data of the group: must be called by Database
 *  
 * @param data - the data to restore
 * @author Thomas Bopp (astra@upb.de) 
 * @see retrieve_group_data
 */
void
restore_group_data(mixed data)
{
    ASSERTINFO(CALLER == _Database, "Caller must be database !");
    
    aoGroupMembers = data["GroupMembers"];
    iGroupRoles    = data["GroupRoles"];
    aoGroups       = data["Groups"];
    sGroupPW       = data["GroupPassword"];
    aoInvites      = data["GroupInvites"];
    sGroupName     = data["GroupName"];
    aPending       = data["GroupPending"];
    oParent        = data["Parent"];
    
    if ( !stringp(sGroupName) || sGroupName == "undefined" )
	sGroupName = get_identifier();
    if ( arrayp(aoGroupMembers) ) 
	aoGroupMembers -= ({ 0 });
}

/**
 * send a message to the group - will only call the SAY_EVENT
 *  
 * @param msg - the message to send
 * @author Thomas Bopp (astra@upb.de) 
 */
void message(string msg)
{
    try_event(EVENT_SAY, CALLER, msg);
    run_event(EVENT_SAY, CALLER, msg);
}

/**
 * add a user to the pending list, the pendnig list is a list of users
 * waiting for acceptance due to the groups size exceeding the GROUP_MAXSIZE
 *
 * @param user - the user to add
 * @param pass - optional password to pass to add_member
 * @see add_member
 * @author Ludger Merkens (balduin@upb.de)
 */
final static bool
add_pending(object user, string|void pass)
{
    int iSizePending;
    if ( is_member(user) || is_pending(user) || user == this() )
        return false;

    /*    iSizePending = query_attribute(GROUP_MAXPENDING);

    if (!iSizePending)
    return false;*/

    if (!iSizePending ||(iSizePending > sizeof(aPending)))
    {
        aPending += ({ ({ user, pass }) });
        return -1;
    }
    return -2;
}

/*
 * check if a user is already waiting for acceptance on the pending list
 * @param user - the user to check for
 * @see add_pending
 * @see add_member
 * @author
 */
final bool
is_pending(object user)
{
    if ( arrayp(aPending) ) {
	foreach( aPending, mixed pend_arr )
	    if ( arrayp(pend_arr) && sizeof(pend_arr) >= 2 )
		if ( pend_arr[0] == user )
		    return true;
    }
    return false;
}

final bool
remove_pending(object user)
{
    if (arrayp(aPending))
    {
        mixed res;
        res = map(aPending, lambda(mixed a)
                                { return a[0]->get_object_id();} );
        if (res)
        {
            int p = search(res, user->get_object_id());
            if (p!=-1)
            {
                aPending[p]=0;
                aPending -= ({0});
                return true;
            }
        }
    }
}

/*
 * get the list of users waiting to be accepted to the group, in case the
 * maximum group size is limited-
 * @return - (array)object (the users)
 * @author Ludger Merkens (balduin@upb.de)
 *
 */
final array(object) get_pending()
{
    return map(aPending, lambda(mixed a) { return a[0];} );
}


/*
 * add a group to the mutual list, A user may be only member to one
 * group of this list. Aquiring membership in one of theese groups will
 * automatically remove the user from all other groups of this list.
 * @param group - the group to add to the cluster
 * @author Ludger Merkens (balduin@upb.de)
 */
final bool add_to_mutual_list(object group)
{
    try_event(EVENT_GRP_ADDMUTUAL, CALLER, group);

    foreach(aoExclusiveGroups, object g)
        g->low_add_to_mutual_list(group);

    group->low_add_to_mutual_list( aoExclusiveGroups +({this_object()}));
    aoExclusiveGroups |= ({ group });

    require_save();
}

/*
 * this function will be called from other groups to indicate, this
 * group isn't required to inform other groups about this addition.
 * To add a group to the cluster call add_to_mutual_list
 * @param group - the group beeing informed
 * @author Ludger Merkens (balduin@upb.de)
 */
final bool low_add_to_mutual_list(array(object) group)
{
    ASSERTINFO(_SECURITY && _SECURITY->valid_group(CALLER),
               "low_add_to_mutal was called from non group object");
    //    try_event(EVENT_GRP_ADDMUTUAL, CALLER, group);
    //    this is not necessary since SECURITY knows about clusters
    aoExclusiveGroups |= group;
    require_save();
}


/*
 * get the list of groups connected in a mutual exclusive list
 * @return an array of group objects
 * @author Ludger Merkens (balduin@upb.de)
 */
final array(object) get_mutual_list()
{
    return copy_value(aoExclusiveGroups);
}

string get_identifier()
{
    if ( stringp(sGroupName) && strlen(sGroupName) > 0 )
	return sGroupName;
    return query_attribute(OBJ_NAME);
}

string parent_and_group_name()
{
    if ( objectp(get_parent()) )
	return get_parent()->query_attribute(OBJ_NAME) + "." + 
	    do_query_attribute(OBJ_NAME);
    return do_query_attribute(OBJ_NAME);
}
    
bool query_join_everyone()
{
    return ((query_sanction(_WORLDUSER) & (SANCTION_READ|SANCTION_INSERT)) ==
	(SANCTION_READ|SANCTION_INSERT));
}
