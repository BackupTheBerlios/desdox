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

#include <macros.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <events.h>
#include <attributes.h>
#include <types.h>

static void
create_object()
{
    ::create_object();
    register_class_attribute(CONT_SIZE_X, CMD_TYPE_FLOAT, "x-size",
			     0, EVENT_ATTRIBUTES_CHANGE, 0,
			     CONTROL_ATTR_CLIENT, 0.0);
    register_class_attribute(CONT_SIZE_Y, CMD_TYPE_FLOAT, "y-size",
			     0, EVENT_ATTRIBUTES_CHANGE, 0,
			     CONTROL_ATTR_CLIENT, 0.0);
    register_class_attribute(CONT_SIZE_Z, CMD_TYPE_FLOAT, "z-size",
			     0, EVENT_ATTRIBUTES_CHANGE, 0,
			     CONTROL_ATTR_CLIENT, 0.0);
    register_class_attribute(CONT_EXCHANGE_LINKS,
			     CMD_TYPE_INT,
			     "exchange links", 0, 
			     EVENT_ATTRIBUTES_CHANGE, 
			     REG_ACQ_ENVIRONMENT,
			     CONTROL_ATTR_USER, 0);
}

/**
 * Execute this Container factory to get a new container object.
 * The vars mapping takes indices: "name", "attributes","attributesAcquired",
 * and "attributesLocked".
 *  
 * @param mapping vars - execute vars, especially the containers name.
 * @return proxy of the newly created container.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object execute(mapping vars)
{
    object obj;
    string name = vars["name"];
    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(
	name, CLASS_NAME_CONTAINER, 0, vars["attributes"],
	vars["attributesAcquired"], vars["attributesLocked"]);
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj->this();
}

string get_identifier() { return "Container.factory"; }
string get_class_name() { return "Container"; }
int get_class_id() { return CLASS_CONTAINER; }


