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
#include <attributes.h>
#include <events.h>
#include <classes.h>
#include <database.h>
#include <exception.h>
#include <types.h>

//! This is the icon module. It keeps track of all classes and maps
//! an icon document for each class. If no individual icon is set in
//! an object the OBJ_ICON attribute is acquired from this object and
//! so the default icon is retrieved. Obviously this enables the admin
//! to replace the default system icons at this place.
//!
//! @note
//! Whats missing here is an interface to set the icons
//! which is really not an issue of this module, but an appropriate
//! script should do the work and call the functions here.

static mapping mIcons = ([ ]);

void install_module()
{
    object factory = _Server->get_factory(CLASS_OBJECT);
    factory->register_attribute(OBJ_ICON, CMD_TYPE_OBJECT,"icon", 
				0, EVENT_ATTRIBUTES_CHANGE, this(),
				CONTROL_ATTR_USER, 0);
}

void init_icons()
{
    mixed err = catch {
    mIcons = ([
	CLASS_TRASHBIN:
	    _FILEPATH->path_to_object("/images/doctypes/trashbin.gif"),
	    CLASS_FACTORY:
	    _FILEPATH->path_to_object("/images/doctypes/type_factory.gif"),
	CLASS_ROOM:
	    _FILEPATH->path_to_object("/images/doctypes/type_area.gif"),

	CLASS_ROOM|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_gate.gif"),
	CLASS_EXIT:
	    _FILEPATH->path_to_object("/images/doctypes/type_gate.gif"),
	CLASS_EXIT|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_gate.gif"),
	CLASS_USER:
	    _FILEPATH->path_to_object("/images/user_unknown.jpg"),
	CLASS_GROUP:
	    _FILEPATH->path_to_object("/images/group.gif"),
	CLASS_CONTAINER:
	    _FILEPATH->path_to_object("/images/doctypes/type_folder.gif"),
	CLASS_CONTAINER|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_folder_lnk.gif"),
	CLASS_DOCUMENT:
	    _FILEPATH->path_to_object("/images/doctypes/type_generic.gif"),
	CLASS_DOCUMENT|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_generic_lnk.gif"),
	CLASS_DOCHTML:
	    _FILEPATH->path_to_object("/images/doctypes/type_html.gif"),
	CLASS_DOCHTML|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_html_lnk.gif"),
	CLASS_DOCWIKI:
	    _FILEPATH->path_to_object("/images/doctypes/type_wiki.gif"),
	CLASS_DOCWIKI|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_wiki_lnk.gif"),
	CLASS_IMAGE:
	    _FILEPATH->path_to_object("/images/doctypes/type_img.gif"),
	CLASS_IMAGE|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_img_lnk.gif"),
	CLASS_DOCEXTERN:
	    _FILEPATH->path_to_object("/images/doctypes/type_references.gif"),
	CLASS_DOCEXTERN|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_references_lnk.gif"),
	CLASS_SCRIPT:
	    _FILEPATH->path_to_object("/images/doctypes/type_pike.gif"),
	CLASS_SCRIPT|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_pike_lnk.gif"),
	CLASS_DOCLPC:
	    _FILEPATH->path_to_object("/images/doctypes/type_pike.gif"),
	CLASS_DOCLPC|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_pike_lnk.gif"),
	CLASS_OBJECT:
	    _FILEPATH->path_to_object("/images/doctypes/type_object.gif"),
	CLASS_OBJECT|CLASS_LINK:
	    _FILEPATH->path_to_object("/images/doctypes/type_object_lnk.gif"),
	CLASS_MESSAGEBOARD: 
	    _FILEPATH->path_to_object("/images/doctypes/type_messages.gif"),

	CLASS_MESSAGEBOARD|CLASS_LINK: 
	    _FILEPATH->path_to_object("/images/doctypes/type_messages_lnk.gif"),
	CLASS_GHOST:
	    _FILEPATH->path_to_object("/images/doctypes/type_ghost.jpg"),
	    "video/*":
	    _FILEPATH->path_to_object("/images/doctypes/type_movie.gif"),
	    "audio/*":
	    _FILEPATH->path_to_object("/images/doctypes/type_audio.gif"),
	"application/pdf":
	    _FILEPATH->path_to_object("/images/doctypes/type_pdf.gif"),
	    
	]);
    };
    if ( err != 0 ) {
	LOG("While installing Icons-module: One or more images not found !");
	LOG(sprintf("%s\n%O", err[0], err[1]));
    }
    require_save();
}

void init_module()
{
    
    if ( !objectp(_ROOTROOM) ) 
	return; // first start of server
    
    if ( _FILEPATH->get_object_in_cont(_ROOTROOM, "images") == 0 ) 
        return;
    

    add_data_storage(store_icons, restore_icons);
     
    set_attribute(OBJ_DESC, "This is the icons module. Here each class "+
		  "is associated an appropriate icon.");

    LOG("Initializing icons ...");
    init_icons();
}

mixed set_attribute(string|int key, mixed val)
{
    if ( key == OBJ_ICON )
	return 0;
    return ::set_attribute(key, val);
}

mixed query_attribute(string|int key)
{
    if ( key == OBJ_ICON ) {
	int type = CALLER->get_object_class();
	return get_icon(type, CALLER->query_attribute(DOC_MIME_TYPE));
    }
    return ::query_attribute(key);
}

/**
 * Get an icon for a specific object class or mime-type.
 *  
 * @param int type - the object class
 * @param string|void mtype - the mime-type
 * @return an icon document.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object get_icon(int type, string|void mtype)
{
    if ( stringp(mtype) )
    {
	if ( objectp(mIcons[mtype]) )
	    return mIcons[mtype];
	
	// global type registration 
	string glob, loc;
	sscanf(mtype,"%s/%s", glob, loc);
	if ( mIcons[glob+"/*"] )
	    return mIcons[glob+"/*"];
    }

    int rtype = type;
    if ( type & CLASS_LINK ) {
	object caller = CALLER;
	type = caller->get_link_object()->get_object_class();
    }



    int t = 0;
	
    for ( int i = 31; i >= 0; i-- ) {
	if ( (type & (1<<i)) && objectp(mIcons[(1<<i)]) ) {
	    t = 1 << i;
	    break;
	}
    }
    if ( t != 0 ) {
	if ( rtype & CLASS_LINK )
	    return mIcons[t|CLASS_LINK];
	else
	    return mIcons[t];
    }
    return 0;
}

void set_icon(int|string type, object icon)
{
    _SECURITY->access_write(this(), CALLER);
    mIcons[type] = icon;
    require_save();
}

mapping get_icons()
{
    return copy_value(mIcons);
}

/**
 * Restore callback function called by _Database to restore data.
 *  
 * @param mixed data - the data to restore.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void restore_icons(mixed data)
{
    if (CALLER != _Database )
	THROW("Caller is not Database !", E_ACCESS);
    mIcons = data["icons"];
}

/**
 * Function to save data called by the _Database.
 *  
 * @return Mapping of icon save data.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mixed store_icons()
{
    if (CALLER != _Database )
	THROW("Caller is not Database !", E_ACCESS);
    return ([ "icons": mIcons, ]);
}

string get_identifier() { return "icons"; }


