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
#include <exception.h>
#include <classes.h>
#include <types.h>

static object oLinkObject;

static void
init()
{
    ::init();
    add_data_storage(retrieve_link_data, restore_link_data);
}

/**
 * Create a duplicate of this link object which means create
 * another link pointing to the same object than this.
 *  
 * @return the duplicated object.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object duplicate()
{
    object dup_obj = ::duplicate();
    dup_obj->set_link_object(oLinkObject);
    return dup_obj;
}

static void 
create_object() 
{
    oLinkObject   = 0;
}



/**
 * Set the link object which is the object this link refers to.
 *  
 * @param obj - the link
 * @author Thomas Bopp 
 * @see query_link_object
 */
final void
set_link_object(object obj)
{
    if ( objectp(oLinkObject) || !objectp(obj) )	
	return; // only set link once !
    /* the object links to another one now */
    oLinkObject = obj;
    oLinkObject->add_reference(this());
    require_save();
}

/**
 * Get the object this link points to.
 *  
 * @return the object linked to this
 * @author Thomas Bopp 
 * @see set_link_object
 */
final object
get_link_object()
{
    return oLinkObject;
}

/**
 * Retrieve the to be saved data of this Link.
 *  
 * @return mapping of link data.
 * @author Thomas Bopp (astra@upb.de) 
 */
final mapping
retrieve_link_data()
{
    if ( CALLER != _Database )
	THROW("Caller is not database !", E_ACCESS);
    return ([ "LinkObject": oLinkObject ]);
}

/**
 * Restore the saved link data. Called by database to load the link.
 *  
 * @param mixed data - the data to be restored.
 * @author Thomas Bopp (astra@upb.de) 
 */
final void
restore_link_data(mixed data)
{
    if ( CALLER != _Database )
	THROW("Caller is not database !", E_ACCESS);
    if ( arrayp(data) )
	oLinkObject = data[0];
    else
	oLinkObject = data["LinkObject"];
}


/**
 * Get the action to take for this link. Usually follow for exits
 * or get if the link points to a document.
 *  
 * @return the link action string description.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string get_link_action() 
{
    if ( !objectp(oLinkObject) )
	return "none";
    else if ( oLinkObject->get_object_class() & 
      (CLASS_CONTAINER|CLASS_ROOM|CLASS_EXIT|CLASS_MESSAGEBOARD|CLASS_DOCEXTERN) )
	return "follow";
    else
	return "get";
}


/**
 * Get the content size of the object linked to.
 *  
 * @return the content size of the linked object.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_content_size()
{
    if ( objectp(oLinkObject) ) {
	if ( !(oLinkObject->get_object_class() & CLASS_LINK) )
	    return oLinkObject->get_content_size();
    }
    return ::get_content_size();
}

int get_object_class() { return CLASS_LINK | ::get_object_class(); }
