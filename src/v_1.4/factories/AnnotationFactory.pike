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

static void 
create_object()
{
    ::create_object();
    register_class_attribute("annotation", CMD_TYPE_MAPPING, "annotation data",
			     EVENT_ATTRIBUTES_QUERY, EVENT_ATTRIBUTES_CHANGE,0,
			     CONTROL_ATTR_SERVER, ([ ]) );
}

/**
 * Create a new annotation to some external URL.
 *  
 * @param mapping vars - vars mapping with name and url.
 * @return newly created annotation.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
object execute(mapping vars)
{
    object        obj, link, fac;

    fac = _Server->get_factory(CLASS_DOCEXTERN);
    obj = fac->get_document(vars["url"]);
    if ( !objectp(obj) ) {
	obj = _FILEPATH->path_to_object(vars["url"]);
    }

    try_event(EVENT_EXECUTE, CALLER, obj, link);

    if ( !objectp(obj) )
	THROW("Unable to find annotated site !", E_ERROR);

    link = ::object_create(
	vars["name"], CLASS_NAME_ANNOTATION, 0, vars["attributes"]);
    obj->set_annotation(vars["annData"]);
    obj->add_annotation(link);

    run_event(EVENT_EXECUTE, CALLER, obj, link);
    return link->this();
}


string get_identifier() { return "Annotation.factory"; }
string get_class_name() { return "Annotation"; }
int get_class_id() { return CLASS_ANNOTATION; }

