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
inherit "/factories/ContainerFactory";

#include <macros.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <events.h>
#include <attributes.h>
#include <types.h>

static void init_factory()
{
 ::init_factory();

 init_class_attribute(ROOM_SCORM_HOME, CMD_TYPE_INT, "perhaps the home of a SCORM-Object", 0,
                               EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER, -1);
 init_class_attribute(ROOM_SCORM_VISIT, CMD_TYPE_MAPPING, "where the users have visited", 0,
                               EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER, -1);
}

object execute(mapping vars)
{
    object obj;
    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(vars["name"], CLASS_NAME_ROOM, 0,vars["attributes"],
	    	vars["attributesAcquired"], vars["attributesLocked"]); 
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj->this();
}
 
string get_identifier() { return "Room.factory"; }
string get_class_name() { return "Room";}
int get_class_id() { return CLASS_ROOM; }
