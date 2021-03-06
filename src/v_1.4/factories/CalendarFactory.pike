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
inherit "/factories/RoomFactory";

#include <macros.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <events.h>

object execute(mapping vars)
{
    object obj;
    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(vars["name"], CLASS_NAME_CALENDAR, 0,vars["attributes"],
	    	vars["attributesAcquired"], vars["attributesLocked"]); 
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj->this();
}
 
string get_identifier() { return "Calendar.factory"; }
string get_class_name() { return CLASS_NAME_CALENDAR;} // Name der zugehörigen Klasse. Muss identisch mit classes.h sein.
int get_class_id() { return CLASS_CALENDAR; } // STEAM BIT Klassenbit classes.h
