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
inherit "/factories/ObjectFactory";

#include <attributes.h>
#include <macros.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <events.h>

object execute(mapping vars)
{
    object obj,  link_to;

    link_to = vars["exit_to"];

    try_event(EVENT_EXECUTE, CALLER, obj, link_to);
    obj = ::object_create(vars["name"], CLASS_NAME_EXIT, 0, 
			  vars["attributes"]);
    if ( !objectp(link_to) ) {
	if ( zero_type(vars["exit_to"]) ) {
	    link_to = ::object_create(vars["name"], CLASS_NAME_EXIT, 0,
				      vars["attributes"]);
	    link_to->set_link_object(obj->this());
	    obj->set_link_object(link_to->this());
	}
    }
    else
	obj->set_link_object(link_to->this());

    object exit_from = vars["exit_from"];
    if ( objectp(exit_from) ) {
        obj->move(exit_from);
        obj = ::object_create(
	    vars["name"], CLASS_NAME_EXIT, 0, vars["attributes"]);
        obj->set_link_object(exit_from);
        obj->move(link_to);
    }
    run_event(EVENT_EXECUTE, CALLER, obj, link_to);
    
    return obj->this();
}

string get_identifier() { return "Exit.factory"; }
string get_class_name() { return "Exit"; }
int get_class_id() { return CLASS_EXIT; }
