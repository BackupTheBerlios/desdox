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
inherit "/classes/Object";

#include <macros.h>
#include <types.h>
#include <classes.h>
#include <attributes.h>

private static object oAnnDocument;

static void init()
{
    ::init();
    add_data_storage(retrieve_ann_data, restore_ann_data);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int
get_object_class() 
{
    return ::get_object_class() | CLASS_ANNOTATION;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping 
query_annotation()
{
    mapping m;

    return query_attribute("annotation");
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
bool
set_annotation(mapping m)
{
    object factory = _Server->get_factory(CLASS_ANNOTATION);
    if ( CALLER != factory )
	THROW("Invalud call to set_annotation()", E_ACCESS);
    
    set_attribute("annotation", m);
    factory = _Server->get_factory(CLASS_DOCUMENT);
    oAnnDocument = factory->execute( ([ "name": m["annName"], ]) );
    oAnnDocument->set_content(m["annData"]);
    require_save();
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
final void
restore_ann_data(mixed data)
{
    if ( CALLER != _Database )
	THROW("Caller is not the Database object !", E_ACCESS );
    oAnnDocument = data["AnnDocument"];
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
final mapping retrieve_ann_data()
{
    if ( CALLER != _Database )
	THROW("Caller is not the Database object !", E_ACCESS );
    return ([ "AnnDocument":oAnnDocument, ]);
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int
get_content_size()
{
    return -1;
}

