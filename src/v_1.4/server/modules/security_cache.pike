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
inherit "/kernel/secure_mapping";

#include <macros.h>
#include <exception.h>
#include <database.h>
#include <access.h>

//! This module caches security checks in a mapping or the database.
//! Instead of traversing the whole group structure it directly
//! answers questions like is user A allowed to read document B,
//! and document B wont have user A explicitely in its ACL.

mapping mCache =([ ]);
int hits=0, total = 0;

string get_index(object obj, object user)
{
    return obj->get_object_id() + ":" + user->get_object_id(); 
}

static mixed get_value(string|int key)
{
    mixed erg;
    total++;
    if (erg = mCache[key])
    {
        hits++;
        return erg;
    }
    erg = ::get_value(key);
    mCache[key] = erg;
    return erg;
}

static mixed set_value(string|int key, mixed value)
{
    mCache[key] = value;
    ::set_value(key, value);
}

void add_permission(object obj, object user, int value)
{
    int       perm, o_idx;
    string            idx;

    if ( !objectp(obj) ) return;

    if ( user == _ROOT && value > ( 1<< SANCTION_SHIFT_DENY) )
	THROW("Odd status of permissions - setting denied permissions for Root-user !", E_ERROR);
    
    if ( CALLER->this() != _SECURITY->this() )
	THROW("No permission to use security cache !", E_ACCESS);

    // add all dependend objects into the databasese
    object|function acquire = obj->get_acquire();
    if ( functionp(acquire) ) acquire = acquire();
    
    if ( objectp(acquire ) ) {
	o_idx = acquire->get_object_id();
	mixed val = get_value(o_idx);
	if ( !arrayp(val) ) 
	    val = ({ });
	if ( search(val, obj) == -1 )
	    set_value(o_idx, val + ({ obj }) );
    }
    
    idx = get_index(obj, user);
    perm = get_value(idx);
    set_value(idx, perm | value);
}

void remove_permission(object obj)
{
    //if ( CALLER->this() != _SECURITY->this() )
    //THROW("No permission to use security cache !", E_ACCESS);
    if ( !objectp(obj) ) return;
 
    array to_del = report_delete(obj->get_object_id()+":%");
    mixed elem;
    foreach(to_del, elem)
        m_delete(mCache, elem);
    
    array depends;
    depends = get_value(obj->get_object_id());
    if ( arrayp(depends) ) 
	foreach(depends, object dep)
	    remove_permission(dep);

    int id;
    delete(id =obj->get_object_id());
    m_delete(mCache, id);
}

void remove_permission_user(object user)
{
    //if ( CALLER->this() != _SECURITY->this() )
    //THROW("No permission to use security cache !", E_ACCESS);
    array to_del = report_delete("%:"+user->get_object_id());
    mixed elem;
    foreach(to_del, elem)
        m_delete(mCache, elem);
}

int get_permission(object obj, object user)
{
    if ( !objectp(obj) || !objectp(user) ) return 0;

    return get_value(get_index(obj, user));
}

string get_identifier() { return "Security:cache"; }
string get_table_name() { return "security_cache"; }
