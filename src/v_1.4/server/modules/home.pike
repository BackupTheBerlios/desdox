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
inherit "/kernel/module";

#include <macros.h>
#include <classes.h>
#include <database.h>
#include <exception.h>
#include <attributes.h>

//! The home module must be located in the root-room and resolves
//! any user or group name parsed and gets the appropriate workarea
//! for it. Queried users/groups can be seen in this modules inventory
//! afterwards. This way emacs and other tools may be able to resolve
//! path, even though actually no object is really places in this container.

class GroupWrapper {
    object grp, home;
    void create(object g, object h) { 
	if ( !IS_PROXY(g) ) 
	    THROW("GroupWrapper: Group is no proxy !", E_ERROR);
	if ( !IS_PROXY(h) ) 
	    THROW("GroupWrapper: Home is no proxy !", E_ERROR);
	if ( !objectp(h) )
	    h = OBJ("/home/steam");
	grp = g; home = h; 
    }
    string get_identifier() { return grp->get_identifier(); }
    int get_object_class() { return CLASS_ROOM|CLASS_CONTAINER; }
    object this() { return this_object(); }
    int status() { return 1; }
    final mixed `->(string func) 
    {
	if ( func == "get_identifier" )
	    return get_identifier;
	else if ( func == "create" )
	    return create;
	else if ( func == "status" )
	    return status;
	else if ( func == "get_object_class" )
	    return get_object_class;
	return home->get_object()[func];
    }
};


static mapping directoryCache = ([ ]);

string get_identifier() { return "home"; }
int get_object_class()  
{ 
    return ::get_object_class() | CLASS_CONTAINER | CLASS_ROOM;
}


bool insert_obj(object obj) 
{ 
    return true; //THROW("No Insert in home !", E_ACCESS); 
}

bool remove_obj(object obj) 
{ 
    return true; // THROW("No Remove in home !", E_ACCESS); 
}

array(object) get_inventory() 
{ 
    array(object) groups = this_user()->get_groups();
    foreach(groups, object grp) {
	if ( !directoryCache[grp->get_identifier()] )
	    directoryCache[grp->get_identifier()] = 
		GroupWrapper(grp, grp->query_attribute(GROUP_WORKROOM));
    }
    return values(directoryCache); 
}
array(object) get_inventory_by_class(int cl) 
{
    if ( cl & _STEAMUSER->get_object_class() )
	return values(directoryCache);
    return ({ });
}

/*
 * Get the object by its name. This function is overloaded to allow
 * the /home syntax to all directories, without having the workrooms
 * environments point there. This means the Container is actually empty,
 * but you can do cd /home/user and get somewhere.
 *  
 * @param string obj_name - the object to resolve
 * @return the object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object get_object_byname(string obj_name)
{
    object obj, res;

    LOG("Getting "+ obj_name);
    if ( objectp(directoryCache[obj_name]) )
	return directoryCache[obj_name];
    
    obj = MODULE_GROUPS->lookup(obj_name);
    if ( objectp(obj) ) {
	LOG("Found group - returning workroom !");
	res = obj->query_attribute(GROUP_WORKROOM);
    }
    else {
	obj = MODULE_USERS->lookup(obj_name);
	if ( objectp(obj) ) {
	    res = obj->query_attribute(USER_WORKROOM);
	}
    }
    if ( objectp(res) )
	directoryCache[obj_name] = GroupWrapper(obj, res);

    return directoryCache[obj_name];
}

/**
 * Called after the object is loaded. Move the object to the workroom !
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void load_module()
{ 
    if ( objectp(_ROOTROOM) && oEnvironment != _ROOTROOM ) {
	set_attribute(OBJ_NAME, "home");
	move(_ROOTROOM); 
    }
}

/**
 * Get the content size of this object which does not make really
 * sense for containers.
 *  
 * @return the content size: -2 as the container can be seen as an inventory
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see stat
 */
int get_content_size()
{
    return -2;
}

/**
 * This function returns the stat() of this object. This has the 
 * same format as statting a file.
 *  
 * @return status array as in file_stat()
 * @author Thomas Bopp (astra@upb.de) 
 * @see get_content_size
 */
array(int) stat()
{
    int creator_id = objectp(get_creator())?get_creator()->get_object_id():0;
    

    return ({ 16877, get_content_size(), time(), time(), time(),
		  creator_id, creator_id, "httpd/unix-directory" });
}
