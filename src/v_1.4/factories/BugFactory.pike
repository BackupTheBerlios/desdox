/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens, Martin Baehr
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

#include <classes.h>
#include <macros.h>
#include <events.h>
#include <access.h>
#include <database.h>
#include <attributes.h>

#include <types.h>

/**
 * The execute function - create a new instance of type "Bug"
 *  
 * @param mapping vars - variables like name and description
 *                'name' - the name
 *                'attributes' - default attributes
 * @return the newly created object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object execute(mapping vars)
{
    object obj;

    string name = vars["name"];
    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(name, get_class_name(), 0, 
			  vars["attributes"], vars["attributesAcquired"],
			  vars["attributesLocked"]);
    if ( stringp(vars["description"]) )
	obj->set_attribute(OBJ_DESC, vars["description"]);
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj->this();
}

static void create_object()
{
    ::create_object();
    register_attribute("status", CMD_TYPE_STRING, "bug status",
                             0, EVENT_ATTRIBUTES_CHANGE,0,
                             CONTROL_ATTR_SERVER, "new" );
}

static void init_factory()
{
   ::init_factory();         // Calling the parent function.
   // new attributes could be registered here too
    register_attribute("status", CMD_TYPE_STRING, "bug status",
                             0, EVENT_ATTRIBUTES_CHANGE,0,
                             CONTROL_ATTR_SERVER, "new" );

}

string get_identifier() { return "Bug.factory"; }
string get_class_name() { return "Bug"; }
int get_class_id() { return CLASS_BUG; }
