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
inherit "ObjectFactory";

#include <classes.h>
#include <macros.h>
#include <events.h>
#include <access.h>
#include <database.h>
#include <attributes.h>
#include <types.h>

static void
create_object()
{
    ::create_object();
    register_class_attribute(DRAWING_TYPE, CMD_TYPE_INT, "type",
			     0, EVENT_ATTRIBUTES_CHANGE, 0,
			     CONTROL_ATTR_CLIENT, 0);
    register_class_attribute(DRAWING_WIDTH, CMD_TYPE_FLOAT, "width",
			     0, EVENT_ARRANGE_OBJECT, 0,
			     CONTROL_ATTR_CLIENT, 0.0);
    register_class_attribute(DRAWING_HEIGHT, CMD_TYPE_FLOAT, "height",
			     0, EVENT_ARRANGE_OBJECT, 0,
			     CONTROL_ATTR_CLIENT, 0.0);
    register_class_attribute(DRAWING_COLOR, CMD_TYPE_INT, "color",
                             0, EVENT_ARRANGE_OBJECT, 0,
                             CONTROL_ATTR_CLIENT, 0);
    register_class_attribute(DRAWING_THICKNESS, CMD_TYPE_INT, "thickness",
                             0, EVENT_ARRANGE_OBJECT, 0,
                             CONTROL_ATTR_CLIENT, 0);
    register_class_attribute(DRAWING_FILLED, CMD_TYPE_INT, "filled",
                             0, EVENT_ARRANGE_OBJECT, 0,
                             CONTROL_ATTR_CLIENT, 0);
 
}

object execute(mapping vars)
{
    object                 obj;
    string name = vars["name"];
    
    try_event(EVENT_EXECUTE, CALLER, obj);
    
    obj = ::object_create(name, CLASS_NAME_DRAWING, 0, vars["attributes"]);
    obj->set_attribute(DRAWING_TYPE, vars["type"]);
    obj->lock_attribute(DRAWING_TYPE);
    
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj;
}

string get_identifier() { return "Drawing.factory"; }
string get_class_name() { return "Drawing"; }
int get_class_id() { return CLASS_DRAWING; }
