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
#include <classes.h>
#include <attributes.h>

int get_object_class() 
{ 
    return CLASS_DRAWING | ::get_object_class();
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
object duplicate()
{
    object factory = _Server->get_factory(get_object_class());
    object dup_obj = factory->execute( ([ 
	"name": query_attribute(OBJ_NAME),
	"attributes":query_attributes(),
	"type": query_attribute(DRAWING_TYPE),
	]));
    
    return dup_obj;
}
