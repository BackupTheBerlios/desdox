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

// Wir wissen nicht wirklich welche includes werden muessen.
#include <macros.h>
#include <classes.h>
#include <database.h>
#include <assert.h>
#include <events.h>
#include <attributes.h>
#include <types.h>
#include <macros.h>


static void init_factory()
{
 ::init_factory();

init_class_attribute(ENTRY_KIND_OF_ENTRY, CMD_TYPE_UNKNOWN, "the kind of this entry", 0,
                              EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,-1);

  init_class_attribute(ENTRY_IS_SERIAL, CMD_TYPE_INT, "is this entry serial or not", 0,
                                EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,-1);

  init_class_attribute(ENTRY_PRIORITY, CMD_TYPE_INT, "the priority of this entry", 0,
                                EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,-1);

  init_class_attribute(ENTRY_TITLE, CMD_TYPE_STRING, "the title of this entry", 0,
                                EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,"");

  init_class_attribute(ENTRY_DESCRIPTION, CMD_TYPE_STRING, "the description of this entry", 0,
                                EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,"");

  init_class_attribute(ENTRY_RANGE, CMD_TYPE_OBJECT, "an mapping, which includes all the dates informations", 0,
                                EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,0);
			      
}			     

object execute(mapping vars)
{
    object obj;
    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(vars["name"], CLASS_NAME_ENTRY, 0,vars["attributes"],
	    	vars["attributesAcquired"], vars["attributesLocked"]); 
    run_event(EVENT_EXECUTE, CALLER, obj);
    
    obj->set_attribute(ENTRY_KIND_OF_ENTRY, vars ["kind_of_entry"]);

    obj->set_attribute(ENTRY_IS_SERIAL, vars ["is_serial"]);
    
    obj->set_attribute(ENTRY_TITLE, vars ["title"]);
    
    obj->set_attribute(ENTRY_DESCRIPTION, vars ["description"]);

if (mappingp( vars ["range"])) {
       object start = Calendar.Day( 
       vars ["range"] ["beginYear"],
       vars ["range"] ["beginMonth"], 
       vars ["range"] ["beginDay"])
       ->hour( vars ["range"] ["beginHour"])
       ->minute( vars ["range"] ["beginMinute"]);
       
    object end  = Calendar.Day(
       vars ["range"] ["endYear"],
       vars ["range"] ["endMonth"],
       vars ["range"] ["endDay"])
       ->hour( vars ["range"] ["endHour"])
       ->minute( vars ["range"] ["endMinute"]);
				   
    object rangeObject = start->range (end);
    
    obj->set_attribute(ENTRY_RANGE, rangeObject);
  MESSAGE ("Mapping da");
  }
  else MESSAGE ("Kein Mapping");

  return obj->this();

}
 
string get_identifier() { return "Entry.factory"; }
string get_class_name() { return CLASS_NAME_ENTRY;}
int get_class_id() { return CLASS_ENTRY; }
