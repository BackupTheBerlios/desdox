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
inherit "/kernel/orb";

#include <macros.h>
#include <assert.h>
#include <database.h>
#include <classes.h>
#include <access.h>
#include <database.h>
#include <attributes.h>

//#define FILEPATH_DEBUG

#ifdef FILEPATH_DEBUG
#define DEBUG_FILEPATH(s) werror(s+"\n")
#else
#define DEBUG_FILEPATH(s) 
#endif


private static mapping mCache = ([ ]);

//! This module represents an ORB which converts a given pathname to
//! an sTeam object by using the structure of environment/inventory or
//! vice versa.
//!
//! There are several different trees with the 
//! roots "/", "~user" or "/home/user".

/**
 * Initialize the module. This time only the description attributes is set.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void init_module()
{
    set_attribute(OBJ_DESC,"This is the filepath object for simulating "+
	"a filepath in steam. It works by traversing through rooms in rooms/"+
	"containers in containers starting from the Users "+
		  "and Groups workrooms");
}

/**
 * Convert a given path to ~ syntax to retrieve a user or a workarea.
 *  
 * @param string path - the path to convert.
 * @return user or workarea object or 0.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object get_tilde(string path)
{
    string user;
    object  uid;

    DEBUG_FILEPATH("get_tilde("+path+")");
    if ( sscanf(path, "~%ss workroom", user) > 0 ) 
    {
	object workroom;
	
	uid = MODULE_USERS->lookup(user);
	if ( !objectp(uid) ) {
	    uid = MODULE_GROUPS->lookup(user);
	    if ( !objectp(uid) )
		return 0;
	    workroom = uid->query_attribute(GROUP_WORKROOM);
	}
	else {
	    workroom = uid->query_attribute(USER_WORKROOM);
	}
	DEBUG_FILEPATH("Returning workroom="+workroom->get_object_id());
	return workroom;
    }
    else if ( sscanf(path, "~%s", user) > 0 ) 
    {
	// object is the user
	uid = MODULE_USERS->lookup(user);
	if ( !objectp(uid) ) 
	    uid = MODULE_GROUPS->lookup(user);
	return uid;
    }
    return 0;
}

/**
 * get_object_in_cont
 *  
 * @param cont - the container
 * @param obj_name - path to object name (only one token: container or object)
 * @return the appropriate object in the container
 * @author Thomas Bopp 
 * @see 
 */
object
get_object_in_cont(object cont, string obj_name)
{
    array(object) inventory;
    int             i;
    object        obj;

    DEBUG_FILEPATH("get_object_in_cont("+cont->get_identifier()+","+
		   obj_name+")");

    if ( !objectp(cont) )
	return 0;
    if ( strlen(obj_name) > 0 && obj_name[0] == '~' )
	return get_tilde(obj_name);

    return cont->get_object_byname(obj_name);
}

/**
 * Get an array of objects which represent the environment of the environment
 * (and so on) of the given object. 
 *  
 * @param object obj - the object to retrieve the environment hierarchy for.
 * @return array of objects which represent the path to environment = null.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(object) object_to_environment_path(object obj)
{
    array(object) objects = ({ });
    
    object current = obj;
    object env = obj->get_environment();
    while ( objectp(env) ) {
      DEBUG_FILEPATH("object_to_environment_path: " + obj->query_attribute(OBJ_NAME));
	objects = ({ env }) + objects;
	current = env;
	env = current->get_environment();
    }
    // check root object if it is a workroom
    if (  stringp(check_tilde(current)) ) 
	objects = ({ _Server->get_module("home") }) + objects;

    return objects;
}

/**
 * resolves a given path, by starting with container uid and
 * traversing through the tree to find the appropriate object
 *  
 * @param uid - the user logged in (for ~ syntax) or null
 * @param path - path to an object
 * @return the object
 * @author Thomas Bopp 
 * @see object_to_path
 * @see path_to_object
 */
object
resolve_path(object uid, string path)
{
    object  env, user;
    object         ob;
    array(object)   objPath;
    array(int)          inv;
    int         i, sz;
    int       slashes;
    int    start, end;
    int           len;

    DEBUG_FILEPATH("resolve_path("+path+")");

    if ( !objectp(uid) ) {
	env = MODULE_OBJECTS->lookup("rootroom");
	if ( !objectp(env) ) {
	    MESSAGE("Root-Room is null on resolve_path()...");
	    return 0;
	}
    }
    else
	env = uid;

    if ( !stringp(path) || strlen(path) == 0 || path == "/" ) 
	return env;

    /*
     * "/" at beginning of path and "/" at the end
     */
    if ( path[0] != '/' )
	path = "/" + path;

    path = Stdio.append_path(path, "");

    len = strlen(path);
    if ( path[len-1] != '/' ) {
	path += "/";
	len++;
    }

    
    DEBUG_FILEPATH("resolve_path(" + (objectp(uid)?"object":"0") + ", " + path + ")");
    
    if ( env->get_object_class() & CLASS_LINK )
	env = env->get_link_object();
    
    objPath = ({ env });

    /* slashes are counted for relative pathes */
    for ( slashes = 0, i = 0; i < len; i++ )
    {
	if ( path[i] == '/' ) {
	    while ( i < len && path[i] == '/' ) i++;
	    i--;
	    if ( slashes >= sizeof(objPath) )
	    {
		if ( !objectp(env) ) 
		    return 0;

		env = get_object_in_cont(env, path[start+1..i-1]);
		if ( objectp(env) )
		    objPath += ({ env });
	    }
	    start = i;
	    slashes++;
	}
    }

    if ( slashes < 1 || slashes > sizeof(objPath) )
	return 0;

    ob = objPath[slashes-1];
    return ob->this(); // fix home-modul GroupWrapper
}

/**
 * Resolve a path. The ~ syntax will be converted to user/path.
 * additionally the __oid syntax is understood by this function.
 *  
 * @param path - the path to convert to an object
 * @return the resolved object or 0
 * @author Thomas Bopp (astra@upb.de) 
 * @see resolve_path
 */
object path_to_object(string path)
{
    string user, fpath;
    object    obj, uid;
    int            oid;
    object    workroom;

    if ( !stringp(path) || strlen(path) == 0 )
	return 0;

    DEBUG_FILEPATH("path_to_object("+path+")");
    // if we cached the path and the path is ok
    if ( objectp(obj = mCache[path]) ) {
	if ( path == object_to_path(obj)+obj->get_identifier() ) {
	    return obj;
	}
	else {
	    mCache[path] = 0;
	}
    }
    if ( strlen(path) > 0 && path[0] != '/' && !IS_SOCKET(CALLER) ) 
	obj = resolve_path(CALLER->get_environment(), path);
    else
	obj = resolve_path(0, path);
    mCache[path] = obj;
    return obj;
}

/**
 * Check if a given object is a groups workarea or a user workroom 
 * and return the appropriate path.
 *  
 * @param object obj - the object to check.
 * @return tilde path or "" or 0.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string|int check_tilde(object obj)
{
    object creator, workroom;

    if ( obj->get_object_class() & CLASS_ROOM ) {
	if ( obj == _ROOTROOM )
	    return "";
	creator = obj->get_creator();
	if ( creator->get_object_class() & CLASS_USER )
	    workroom = creator->query_attribute(USER_WORKROOM);
	else 
	    workroom = creator->query_attribute(GROUP_WORKROOM);
	
	if ( objectp(workroom) && workroom->this() == obj->this() )
	    return "/home/"+creator->get_identifier();
    } 
    else if ( obj->get_object_class() & CLASS_USER ) {
	return "/~"+obj->get_identifier();
    }
    
    return 0;
}


/**
 * return the path equivalent to an object
 *  
 * @param obj - the object
 * @return converts the object to a path description
 * @author Thomas Bopp 
 * @see path_to_object
 */
string
object_to_path(object obj)
{
    object env, last_env;
    string          path;
    mixed           name;
    string      workroom;
	

    if ( !objectp(obj) )
	return "";
    
    /* traverse through the tree beginning with the object itself
     * and following the environment structure */
    env  = obj->get_environment();
    last_env = env;
    if ( last_env == _ROOTROOM )
	return "/";
    else if ( objectp(env) )
	env = env->get_environment();
    else 
	return 0;

    if ( stringp(workroom=check_tilde(last_env)) ) {
        return workroom + "/";
    }    

    path = "/";

    while ( objectp(env) ) {
	name = last_env->get_identifier();
	
	path = "/" + name + path;
	last_env = env;
	if ( stringp(workroom=check_tilde(env)) ) {
	    return workroom + path;
	}
	env = env->get_environment();
    }
    string tilde = check_tilde(last_env);
    if ( !stringp(tilde) ) {
	if ( last_env == _ROOTROOM )
	    return path;
	return 0;
    }
    return tilde + path;
}

/**
 * Return the whole path, including the filename, for the given object.
 *  
 * @param obj - the object to get the filename
 * @return the filename
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string object_to_filename(object obj)
{
    if ( !objectp(obj) )
	return 0;
    
    if ( obj->this() == _ROOTROOM->this() )
	return "/";

    string workroom;
    if ( stringp(workroom=check_tilde(obj)) )
        return workroom;
    return object_to_path(obj) + obj->get_identifier();
}

/**
 * Get the Container or Room a given url-object is located.
 *  
 * @param string url - the url to find the objects environment.
 * @return the environment.
 * @author Thomas Bopp (astra@upb.de) 
 */
object
path_to_environment(string url)
{
    int i;

    i = strlen(url) - 1;
    while ( i > 0 && url[i] != '/' ) i--;
    if ( i == 0 ) return _ROOTROOM;
    return path_to_object(url[..i]);
}

string get_identifier() { return "filepath:tree"; }

/**
 * Check whether the current user is able to read the given file.
 *  
 * @param string file - the file to check.
 * @return 0 or 1.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int check_access(string file)
{
    object obj;
    obj = path_to_object(file);
    if ( objectp(obj) ) {
	mixed err = catch { 
	    _SECURITY->access_read(obj, this_user());
	};
	if ( arrayp(err) ) return 0;
	DEBUG_FILEPATH("Access ok !");
	return 1;
    }
    return 0;
}


