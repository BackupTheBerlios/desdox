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
#include <assert.h>
#include <macros.h>
#include <database.h>
#include <exception.h>
 
       object       this();

static void require_save() { _Database->require_save(); }

static array(object) aoGroups;


/**
 * Initialize the member variables. This is only the array of groups.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void init_member()
{
    aoGroups = ({ });
}

/**
 * The function is called when the object is deleted and it
 * calls each group then and removes the member from the group.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void 
delete_object()
{
    array(object) groups = copy_value(aoGroups);
    if ( arrayp(groups) ) {
	object grp;
	foreach(groups, grp) {
	    grp->remove_member(this());
	}
    }
}

/**
 * Get an array of groups of this member.
 *  
 * @return the groups of the user
 * @author Thomas Bopp 
 * @see set_groups
 */
final array(object)
get_groups()
{
    aoGroups -= ({ 0 });
    
    return copy_value(aoGroups);
}

/**
 * Set the groups for this user. Only trusted objects are able to call this
 * function. In fact I am not sure if this is used at all.
 *  
 * @param grps - list of groups of the user
 * @author Thomas Bopp 
 * @see query_groups
 */
final void
set_groups(array(object) grps)
{
    if ( !_SECURITY->trust(CALLER) )
	THROW("Unauthorized call to set_groups()", E_ACCESS);
    aoGroups = copy_value(grps);
    require_save();
}

/**
 * join_group() should not be called - instead call group->add_member() !
 * Invalid calls are checked. The add_member() function will call this
 * one automatically.
 *  
 * @param grp - the group to join
 * @author Thomas Bopp 
 * @see leave_group
 */
final bool
join_group(object grp)
{
    ASSERTINFO(IS_PROXY(grp),"Group is not a proxy !");
    ASSERTINFO(_SECURITY->valid_group(CALLER) && grp->get_object() == CALLER,
	       "Invalid calling object in join_group()");

    aoGroups += ({ grp });
    require_save();
    return true;
}

/**
 * This function is called to remove a group from the list of groups.
 * It should not be called directly. Instead the group has to be called to
 * remove one of its members. Invalid calls are checked and thrown.
 *  
 * @param grp - the group to leave
 * @return successfully or not
 * @author Thomas Bopp (astra@upb.de) 
 * @see join_group
 */
final bool 
leave_group(object grp)
{
    ASSERTINFO(IS_PROXY(grp),"Group is not a proxy !");
    ASSERTINFO(_SECURITY->valid_group(CALLER) && grp->get_object() == CALLER,
	       "Invalid calling object in join_group(): "+
	       master()->describe_object(CALLER));
    aoGroups -= ({ grp });
    require_save();
    return true;
}
