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
#include <database.h>
#include <assert.h>
#include <events.h>
#include <attributes.h>
#include <types.h>
#include <access.h>

static int iActivation = 0;

/**
 * Initialize the factory with its default attributes.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void init_factory()
{
    ::init_factory();
    init_class_attribute(USER_ADRESS, CMD_TYPE_STRING, "user adress",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_USER, "");
    init_class_attribute(USER_MODE,  CMD_TYPE_INT, "user mode", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_CLIENT, 0);
    init_class_attribute(USER_UMASK,  CMD_TYPE_MAPPING, "user umask", 
			 EVENT_ATTRIBUTES_QUERY, EVENT_ATTRIBUTES_CHANGE,0,
			 CONTROL_ATTR_USER, ([ ]));
    init_class_attribute(USER_MODE_MSG, CMD_TYPE_STRING, 
			 "user mode message", 0, 
			 EVENT_ATTRIBUTES_CHANGE, 0,CONTROL_ATTR_USER,"");
    init_class_attribute(USER_EMAIL, CMD_TYPE_STRING, "email", 
			 0, EVENT_ATTRIBUTES_CHANGE,0,
			 CONTROL_ATTR_USER, "");
    init_class_attribute(USER_FULLNAME, CMD_TYPE_STRING, "user fullname",0,
			 EVENT_ATTRIBUTES_CHANGE, 0,CONTROL_ATTR_USER, "");
    init_class_attribute(USER_WORKROOM, CMD_TYPE_OBJECT, "workroom", 0, 
			 EVENT_ATTRIBUTES_CHANGE, 0,CONTROL_ATTR_USER, 0);
    init_class_attribute(USER_LOGOUT_PLACE, CMD_TYPE_OBJECT, "logout-env",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_USER, 0);
    init_class_attribute(USER_LAST_LOGIN, CMD_TYPE_TIME, "last-login", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, 0);
    init_class_attribute(USER_BOOKMARKROOM, CMD_TYPE_OBJECT, "bookmark room",0,
			 EVENT_ATTRIBUTES_CHANGE, 0,CONTROL_ATTR_USER, 0);
    init_class_attribute(USER_FORWARD_MSG, CMD_TYPE_INT, "forward message", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_USER, 1);
    init_class_attribute(USER_FAVOURITES, CMD_TYPE_ARRAY, "favourites list", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_USER, ({ }) );

    init_class_attribute(USER_CALENDAR, CMD_TYPE_OBJECT, "calendar", 0,
                         EVENT_ATTRIBUTES_CHANGE, 0, CONTROL_ATTR_USER,0);
}

/**
 * Create a new user object with the following vars:
 * name     - the users name (nickname is possible too).
 * email    - the users email adress.
 * pw       - the users initial password.
 * fullname - the full name of the user.
 * firstname - the last name of the user.
 *  
 * @param mapping vars - variables for execution.
 * @return the objectp of the new user if successfully, or 0 (no access or user
 *         exists)
 * @author Thomas Bopp (astra@upb.de) 
 */
object execute(mapping vars)
{
    int       i;
    object  obj;

    try_event(EVENT_EXECUTE, CALLER, obj);

    string name;
    
    if ( stringp(vars["nickname"]) )
	name = lower_case(vars["nickname"]);
    else
	name = vars["name"];
    
 /* 
    string tempS;
    tempS = lower_case(vars["fullname"]);
    name = tempS[0..0]; // create username from 1st char of name and first 6 chars of surname 
    tempS = lower_case(vars["surname"]);
    name = name + temps[0..5];
 */  
    if ( search(name, " ") >= 0 )
	steam_error("Whitespaces in Usernames are not allowed");
    
    string pw = vars["pw"];
    string email = vars["email"];

    obj = MODULE_USERS->lookup(name);
    if ( objectp(obj) ) {
	SECURITY_LOG("user_create(): User does already exist.");
	return null;
    }
    obj = MODULE_GROUPS->lookup(name);
    if ( objectp(obj) ) {
	SECURITY_LOG("user_create(): Group with this name already exist.");
	return null;
    }
    obj = object_create(name, CLASS_NAME_USER, 0, vars["attributes"],
	    	vars["attributesAcquired"], vars["attributesLocked"]); 
    obj->lock_attribute(OBJ_NAME);
    if ( !objectp(obj) ) {
	SECURITY_LOG("Creation of user " + name + " failed...");
	return null; // creation failed...
    }

    obj->set_user_password(pw);
    obj->set_user_name(name);
    obj->set_attribute(USER_EMAIL, email);
    obj->set_attribute(USER_FULLNAME, vars["fullname"]);
    obj->set_attribute(USER_FIRSTNAME, vars["firstname"]);
    obj->set_creator(_ROOT);
    obj->set_acquire(0);

    if ( stringp(vars["description"]) )
	obj->set_attribute(OBJ_DESC, vars["description"]);
    if ( stringp(vars["contact"]) )
	obj->set_attribute(USER_ADRESS, vars["contact"]);
    
    object workroom, factory, calendar;

    factory = _Server->get_factory(CLASS_ROOM);
    
    workroom = factory->execute((["name":name+"'s workarea",]));
    obj->move(workroom);
    obj->set_attribute(USER_WORKROOM, workroom);
    obj->lock_attribute(USER_WORKROOM);
    workroom->set_attribute(OBJ_DESC, name+"s workroom.");
    workroom->set_creator(obj->this());
    workroom->sanction_object(obj->this(), SANCTION_ALL);
    workroom->sanction_object_meta(obj->this(), SANCTION_ALL);

    object bookmarkroom = factory->execute((["name":name+"'s bookmarks",]));
    obj->set_attribute(USER_BOOKMARKROOM, bookmarkroom);
    obj->lock_attribute(USER_BOOKMARKROOM);
    bookmarkroom->set_creator(obj->this());
    bookmarkroom->sanction_object(obj->this(), SANCTION_ALL);
    bookmarkroom->sanction_object_meta(obj->this(), SANCTION_ALL);

    factory = _Server->get_factory(CLASS_TRASHBIN);
    object trashbin = factory->execute((["name":"trashbin", ]));
    trashbin->set_attribute(OBJ_DESC, "Trashbin");
    trashbin->move(workroom->this());
    trashbin->set_creator(obj->this());
    trashbin->sanction_object(obj->this(), SANCTION_ALL);
    trashbin->sanction_object_meta(obj->this(), SANCTION_ALL);
    trashbin->sanction_object(_STEAMUSER, SANCTION_INSERT);
    trashbin->set_acquire(0); 
    
    obj->set_attribute(USER_TRASHBIN, trashbin);

    // Von uns Essenern eingefuegt: Anfang
    calendar = _Server->get_factory(CLASS_CALENDAR)->execute((["name":name+"'s calendar"]) );
    obj->set_attribute(USER_CALENDAR, calendar);
//  obj->lock_attribute(USER_CALENDAR);

    calendar->set_creator(obj->this());
//    calendar->sanction_object(obj->this(), SANCTION_ALL);
//    calendar->sanction_object_meta(obj->this(), SANCTION_ALL);

    // Von uns Essenern eingefuegt Ende

    // steam users can annotate and read the users attributes.
    obj->sanction_object(_STEAMUSER, SANCTION_READ|SANCTION_ANNOTATE);
   
    ASSERTINFO(_STEAMUSER->add_member(obj->this()), 
	       "Failed to add user to sTeam Users !");
    array(object) inv = workroom->get_inventory_by_class(CLASS_EXIT);
    if ( sizeof(inv) == 0 ) {
	factory = _Server->get_factory(CLASS_EXIT);
	object swa = _STEAMUSER->query_attribute(GROUP_WORKROOM);
	object exit = factory->execute( 
	    ([ "name":swa->get_identifier(), "exit_to": swa, ]));
	exit->set_creator(obj->this());
	exit->move(workroom);
    }
	
    run_event(EVENT_EXECUTE, CALLER, obj);
   
       // now remove all guest privileges on this object
    if ( objectp(_GUEST) ) {
	obj->sanction_object(_GUEST, 0);
	workroom->sanction_object(_GUEST, 0);
    }
    iActivation = time() + random(100000);
    obj->set_activation(iActivation);
    return obj->this();
}

/**
 * Queries and resets the activation code for an user. Thus
 * it is required, that the creating object immidiately calls
 * this function and sends the activation code to the user.
 *  
 * @return activation code for the last created user
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_activation()
{
    int res = iActivation;
    iActivation = 0;
    return res;
}

string get_identifier() { return "User.factory"; }
string get_class_name() { return "User"; }
int get_class_id() { return CLASS_USER; }
