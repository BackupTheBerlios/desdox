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
#include <roles.h>
#include <database.h>
#include <events.h>
#include <attributes.h>
#include <types.h>
#include <exception.h>

static array(string) sReservedNames = ({ "steam", "admin", "everyone", "privgroups" });

static void 
create_object()
{
    ::create_object();
    register_class_attribute(GROUP_MEMBERSHIP_REQS, CMD_TYPE_ARRAY, 
			     "request membership", 
			     EVENT_ATTRIBUTES_QUERY, EVENT_ATTRIBUTES_CHANGE,0,
			     CONTROL_ATTR_USER, ({ }));
    register_class_attribute(GROUP_WORKROOM, CMD_TYPE_OBJECT, "workroom", 
			     0, EVENT_ATTRIBUTES_CHANGE, 0,
			     CONTROL_ATTR_USER, 0);
    register_class_attribute(GROUP_MAXSIZE, CMD_TYPE_INT,
                             "Groups Maximum Size", 0, EVENT_ATTRIBUTES_CHANGE,
                             0, CONTROL_ATTR_USER, 0);
    register_class_attribute(GROUP_MAXPENDING, CMD_TYPE_INT,
                             "Groups Maximum Pending size", 0, EVENT_ATTRIBUTES_CHANGE,
                             0, CONTROL_ATTR_USER, 0);
    register_class_attribute(GROUP_MSG_ACCEPT, CMD_TYPE_STRING,
                             "Group Accept Message", 0, EVENT_ATTRIBUTES_CHANGE,
                             0, CONTROL_ATTR_USER, 0);

}

/**
 * create a new group with the name "name"
 *  
 * @param name - the name for the new group
 * @return the created group object or 0
 * @author Thomas Bopp (astra@upb.de) 
 * @see group_add_user
 */
object execute(mapping vars)
{
    object grp, parentgroup;
    string             name;
    
    name               = vars["name"];
    parentgroup = vars["parentgroup"];
    // check if the parent group can be used

    if ( search(name, ".") >= 0 )
	steam_error("Using '.' in group names is forbidden !");
    
    if ( objectp(parentgroup) ) {
	_SECURITY->check_access(
	    parentgroup, CALLER, SANCTION_INSERT, ROLE_INSERT_ALL ,false);
	name = parentgroup->get_identifier() + "." + name;
    }
    else
	_SECURITY->check_access(
	    this(), CALLER, 
	    SANCTION_WRITE, 
	    ROLE_CREATE_TOP_GROUPS, 
	    false);

    object ogrp = MODULE_GROUPS->lookup(name);
    if ( objectp(ogrp) ) {
	if ( search(sReservedNames, lower_case(name)) >= 0 ) 
	    THROW("The name " + name + " is reserved for system groups.", 
		  E_ACCESS);
	
	if ( !objectp(parentgroup) && sizeof(ogrp->get_groups()) == 0 )
	    THROW("Group with that name ("+name+
		  ") already exists on top level!", E_ACCESS);
	else if ( objectp(parentgroup) && 
		  search(ogrp->get_groups(), parentgroup) >= 0 )
	    THROW("Group with that name ("+name+") already exists in context!",
		  E_ACCESS);
    }

    try_event(EVENT_EXECUTE, CALLER, grp);
    grp = object_create(name, CLASS_NAME_GROUP, 0, 
			vars["attributes"],
			vars["attributesAcquired"], 
			vars["attributesLocked"]); 

    grp->set_group_name(name);
    grp->set_attribute(OBJ_NAME, vars->name);
    grp->lock_attribute(OBJ_NAME);
    grp->set_parent(parentgroup);
    run_event(EVENT_EXECUTE, CALLER, grp);
    
    object workroom, factory;

    factory = _Server->get_factory(CLASS_ROOM);
    
    workroom = factory->execute((["name":vars->name+"'s workarea",]));
    grp->set_attribute(GROUP_WORKROOM, workroom);
    grp->lock_attribute(GROUP_WORKROOM);

    workroom->set_creator(grp->this());
    workroom->sanction_object(grp->this(), SANCTION_ALL);
    workroom->sanction_object_meta(grp->this(), SANCTION_ALL);

    if ( objectp(parentgroup) )
	parentgroup->add_member(grp->this());
    
    if ( mappingp(vars["exits"]) )
	grp->set_attribute(GROUP_EXITS, vars["exits"]);
    else
	grp->set_attribute(GROUP_EXITS, ([ workroom:
					 workroom->get_identifier(), ]));

    return grp->this();
}

object find_parent(object group)
{
  object parent;
  object groups = get_module("groups");

  array parents = group->get_identifier() / ".";
  string path = "";
  foreach ( parents, string pname ) {
    path += pname;
    if ( groups->lookup(path) != group )
      parent = groups->lookup(path);
    path += ".";
  }
  return parent;
}


/**
 * Move a group to a new parent group. Everything is updated accordingly.
 *  
 * @param object group - the group to move
 * @param object new_parent - the new parent group
 * @return true or false
 */
bool move_group(object group, object new_parent)
{
    if ( !objectp(group) )
	steam_error("move_group() needs a group object to move!");
    if ( !objectp(new_parent) )
	steam_error("move_group() needs a target for moving the group!");

    _SECURITY->check_access(group,CALLER,SANCTION_WRITE,ROLE_WRITE_ALL,false);

    string identifier = get_group_name(group);
    foreach(new_parent->get_members(), object grp) {
	if ( objectp(grp) && grp->get_object_class() & CLASS_GROUP )
	    if ( grp != group && get_group_name(grp) == identifier )
		steam_error("Naming conflict for group: already found group "+
			    "same name on target!");
    }
    object parent = group->get_parent();
    object groups = get_module("groups");
    if ( !objectp(parent) ) {
	// try to find some parent anyhow
      parent = find_parent(group);
    }
    if ( objectp(parent) ) {
	werror("- found parent group: " + parent->get_identifier() + "\n");
	// check for permissions required
	parent->remove_member(group);
    }
    new_parent->add_member(group);
    string new_name = new_parent->get_identifier()+"."+get_group_name(group);
    groups->rename_group(group, new_name);
    group->set_group_name(new_name);
    // now we have to rename all subgroups!
    foreach(group->get_sub_groups(), object subgroup) {
      if ( objectp(subgroup) && subgroup->status() > 0 ) {
	move_group(subgroup, group); // this is not actually a move, but should update name
      }
    }
    return true;
}

string get_group_name(object group)
{
  string identifier = group->get_identifier();
  array gn = (identifier / ".");
  if ( sizeof(gn) == 0 )
    return identifier;
  return gn[sizeof(gn)-1];
}

void rename_group(object group, string new_name)
{
    _SECURITY->check_access(group,CALLER,SANCTION_WRITE,ROLE_WRITE_ALL,false);
    object groups = get_module("groups");
    
    object parent = find_parent(group);
    if ( objectp(parent) )
      new_name = parent->get_identifier() + "." + new_name;
    groups->rename_group(group, new_name);
    group->set_group_name(new_name);
    group->unlock_attribute(OBJ_NAME);
    group->set_attribute(OBJ_NAME, new_name);
    group->lock_attribute(OBJ_NAME);
}

string get_identifier() { return "Group.factory"; }
string get_class_name() { return "Group"; }
int get_class_id() { return CLASS_GROUP; }
