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
inherit "/factories/DocumentFactory";

#include <macros.h>
#include <classes.h>
#include <events.h>
#include <exception.h>
#include <database.h>
#include <attributes.h>

private static object mExternLookup;

void init()
{
    ::init();
    mExternLookup = _Server->get_module("extern_documents");
}

object execute(mapping vars)
{
    object obj;
    if ( !stringp(vars["url"]) )
	THROW("No url given!", E_ERROR);
    
    int l = strlen(vars["url"]);
    if ( l >= 2 && vars["url"][l-1] == '/' )
	vars["url"] = vars["url"][..l-2];
    
    if ( !stringp(vars->name) || strlen(vars->name) == 0 )
      vars->name = vars->url;

    try_event(EVENT_EXECUTE, CALLER, obj);
    obj = ::object_create(
	vars["name"], CLASS_NAME_DOCEXTERN, 0, vars["attributes"],
	vars["attributesAcquired"], vars["attributesLocked"]);
    obj->set_attribute(DOC_EXTERN_URL, vars["url"]);
    obj->lock_attribute(DOC_EXTERN_URL);
    
    run_event(EVENT_EXECUTE, CALLER, obj);
    return obj->this();
}

object
get_document(string url)
{
    int l = strlen(url);
    if ( l >= 2 && url[l-1] == '/' )
	url = url[..l-2];
    return mExternLookup->lookup(url);
}

string get_identifier() { return "DocExtern.factory"; }
string get_class_name() { return "DocExtern"; }
int get_class_id() { return CLASS_DOCEXTERN; }



