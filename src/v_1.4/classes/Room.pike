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
inherit "/classes/Container";

#include <attributes.h>
#include <events.h>
#include <macros.h>
#include <classes.h>
#include <assert.h>
#include <exception.h>
#include <database.h>

bool is_workplace()
{
    object creator = get_creator();
    if ( creator->get_object_class() & CLASS_USER )
    {
	if ( creator->query_attribute(USER_WORKROOM) == this() )
	    return true;
    }
    else {
	if ( creator->query_attribute(GROUP_WORKROOM) == this() )
	    return true;
    }
    return false;
}

bool move(object dest) 
{
    if ( is_workplace() ) 
	THROW("Cannot move workareas", E_ACCESS);
    return ::move(dest);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
static void
delete_object()
{
    if ( get_object_id() == _ROOTROOM->get_object_id() )
	THROW("Cannot delete rootroom !", E_ACCESS);
    ::delete_object();
}


/**
 * Check if its possible to insert an object.
 *  
 * @param object obj - the object to insert
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static bool check_insert(object obj)
{
    return true;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
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
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int
get_object_class()
{
    return ::get_object_class() | CLASS_ROOM;
}


/**
 * Is this an object ? yes!
 *  
 * @return true
 */
final bool is_room() { return true; }
