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
inherit "/classes/Room";

#include <classes.h>

string describe() {
//    return "(#"+get_object_id()+","+get_status()+","+get_ip(1)+")";
	    

  object creator = get_creator();
  return "Calendar("+(objectp(creator) ? creator->get_user_name() :  "'s calendar")+")";
}

void add_entry(int kind_of_entry, int is_serial, int priority, string title, string description, mapping | void range) {

  object entry = _Server->get_factory(CLASS_ENTRY)->execute( ([
        "name"         : "entry", 
	"kind_of_entry": kind_of_entry, 
	"is_serial"    : is_serial, 
	"priority"     : priority, 
	"title"        : title, 
	"description"  : description, 
	"range"        : range 
  ]) );

entry->move(this());

}

array  get_all_entries () {
  return this()->get_inventory_by_class(CLASS_ENTRY);
 }

int get_object_class() 
{
  return ::get_object_class() | CLASS_CALENDAR;
}
