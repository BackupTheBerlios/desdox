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
inherit "/kernel/secure_mapping.pike";

#include <macros.h>
#include <attributes.h>
#include <classes.h>

//! This module maps the name of the group to the group object.
//! Its possible to get a list of all groups inside here. Apart
//! from that its only used by the server directly.

/**
 * Get a list of groups. 
 *  
 * @return an array of groups.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(object) get_groups()
{
    array(string) index  = index();
    array(object) groups =   ({ });


    foreach ( index, string idx ) {
	object obj = get_value(idx);
	if ( objectp(obj) )
	    groups += ({ obj });
    }
    return groups;
}

void rename_group(object group, string new_name)
{
    if ( CALLER != get_factory(CLASS_GROUP) )
	steam_error("Invalid call to rename_group() !");
    set_value(group->get_identifier(), 0);
    set_value(new_name, group);
}

/**
 * Initialize the module. Only sets the description attribute.
 *  
 */
void init_module()
{
    set_attribute(OBJ_DESC, "This is the database table for lookup "+
		  "of Groups !");
}

string get_identifier() { return "groups"; }
string get_table_name() { return "groups"; }
