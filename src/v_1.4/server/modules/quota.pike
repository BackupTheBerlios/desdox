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
inherit "/kernel/secure_n_n";

#include <macros.h>
#include <attributes.h>
#include <exception.h>
#include <types.h>
#include <classes.h>
#include <events.h>
#include <database.h>

//! This is the quota module. It gives a quote for each group and
//! a user's quota is the sum of all groups quotas.
//! The module also keeps track of all objects and their creators
//! in the database. For this it uses events for uploading
//! and deleting objects.

static mapping mGroupQuotas;

#define QUOTA_NO_QUOTA         -1
#define QUOTA_STEAM_QUOTA 5000000

void init_module()
{
#if 0
    add_global_event(EVENT_UPLOAD, upload_document, PHASE_BLOCK);
    add_global_event(EVENT_UPLOAD, upload_document_done, PHASE_NOTIFY);
    add_global_event(EVENT_DELETE, delete_document, PHASE_NOTIFY);
    mGroupQuotas = ([ 
	_STEAMUSER: QUOTA_STEAM_QUOTA,
	_ADMIN: QUOTA_NO_QUOTA, ]);
    add_data_storage(retrieve_quota_data, restore_quota_data);
#endif
}

mapping retrieve_quota_data()
{
    if ( CALLER != _Database )
	THROW("Invalid call to retrieve_quota_data().", E_ACCESS);
    
    return ([
	"GroupQuota": mGroupQuotas, 
	]);
}

void restore_quota_data(mapping data)
{
    if ( CALLER != _Database )
	THROW("Invalud call to restore_quota_data().", E_ACCESS);

    mGroupQuotas = data["GroupQuota"];
    array groups = MODULE_GROUPS->get_groups();
    foreach(groups, object group)
	if ( zero_type(mGroupQuotas[group]) )
	    mGroupQuotas[group] = 0;
}

int get_user_quota(object user)
{
    array(object) groups = user->get_groups();
    int maxquota = 0;
    foreach ( groups, object grp) {
	int quota = get_quota(grp);
	if ( quota == QUOTA_NO_QUOTA )
	    return QUOTA_NO_QUOTA;
	maxquota += quota;
    }
    return maxquota;
}

int get_user_quota_used(object user)
{
    mixed user_quota = lookup("quota_used_"+user->get_object_id());
    if ( arrayp(user_quota) && sizeof(user_quota) > 0 )
	return user_quota[0];
    return 0;
}

void delete_document(object obj, object caller)
{
    array modifier = get_key(obj);
    if ( arrayp(modifier) && sizeof(modifier) > 0 )
    {
	mixed quota_obj = lookup(obj->get_object_id());
	if ( arrayp(quota_obj) && sizeof(quota_obj) > 0 )
	    quota_obj = quota_obj[0];
	else
	    quota_obj = 0;
	object last_modify = find_object(modifier[0]);
	int m_quota = get_user_quota_used(last_modify);
	delete("quota_used_"+last_modify->get_object_id());
	set_value( ({ "quota_used_" + last_modify->get_object_id() }),
		   m_quota - quota_obj);
    }
}

void upload_document(object obj, object caller)
{
    if ( !objectp(this_user()) )
	return;
    int quota = get_user_quota(this_user());
    int used_quota = get_user_quota_used(this_user());
    if ( quota != QUOTA_NO_QUOTA && used_quota > quota )
	THROW("Cannot upload - quota is used up !", E_QUOTA);
    
    LOG("Uploading document ="+obj->get_identifier()+"\n");
}

void upload_document_done(object obj, object user)
{
    if ( !(obj->get_object_class() & CLASS_DOCUMENT) )
	return;
    mixed quota_obj = lookup(obj->get_object_id());
    if ( arrayp(quota_obj) && sizeof(quota_obj) > 0 )
	quota_obj = quota_obj[0];
    else
	quota_obj = 0;
    
    LOG("Uploading document size="+obj->get_content_size() + ", "+
	" quota_obj="+quota_obj+"\n");
    array modifier = get_key(obj);
    if ( arrayp(modifier) && sizeof(modifier) > 0 )
    {
	if ( modifier[0] != user->get_object_id() ) {
	    object last_modify = find_object(modifier[0]);
	    int m_quota = get_user_quota_used(last_modify);
	    delete("quota_used_"+last_modify->get_object_id());
	    set_value( ({ "quota_used_" + last_modify->get_object_id() }),
		       m_quota - quota_obj);
	}
    }
    set_value( ({ user->get_object_id() }) , obj);
    set_value( ({ obj->get_object_id() }), obj->get_content_size());
    int quota_used = get_user_quota_used(this_user());
    werror("User is:" + user->get_identifier()+"\n");
    
    delete("quota_used_"+user->get_object_id());
    set_value( ({ "quota_used_"+user->get_object_id() }), quota_used + 
	       obj->get_content_size() - 
	       quota_obj);
}

void set_quota(object group, int quota)
{
    if ( !(group->get_object_class() & CLASS_GROUP) )
	THROW("Can only set quota to groups !", E_ERROR);
    
    try_event(EVENT_CHANGE_QUOTA, group, quota);
    mGroupQuotas[group] = quota;
    require_save();
    run_event(EVENT_CHANGE_QUOTA, group, quota);
}

int get_quota(object group)
{
    if ( !mappingp(mGroupQuotas) )
        return -1;
    return copy_value(mGroupQuotas[group]);
}

mapping get_groups_quota()
{
    return copy_value(mGroupQuotas);
}


array(object) get_documents(object user)
{
    array(object) owned = lookup(this_user()->get_object_id());
    return owned;
}

string show_quota(object user)
{
    string xml = "";
    int used   = get_user_quota_used(user);
    int quota  = get_user_quota(user);
    xml += "<used>"+ used + "</used>";
    xml += "<max>"+ quota + "</max>";
    xml += "<available>"+(quota-used)+"</available>\n";
    return xml;
}


function find_function(string f) { LOG("find_function("+f+")"); return 0; }
string get_identifier() { return "quota"; }
string get_table_name() { return "quota"; }
