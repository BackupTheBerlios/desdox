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
inherit "/classes/Object" :  __object;
inherit "/base/content"   : __content;

#include <attributes.h>
#include <classes.h>
#include <macros.h>
#include <events.h>
#include <types.h>
#include <config.h>
#include <database.h>

static mapping       mReferences;

static void init_document() { }

/**
 * Init callback function.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final static void
init()
{
    __object::init();
    __content::init_content();
    init_document();
}

/**
 * Called after the document was loaded by database.
 *  
 */
static void load_document()
{
}

/**
 * Called after the document was loaded by database.
 *
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void load_object()
{
    load_document();
}

/**
 * Duplicate the Document and its content.
 *  
 * @return the duplicate of this document.
 */
object duplicate()
{
    // DocumentFactory deals with content_obj variable
    return ::duplicate( ([ "content_obj": this_object() ]) );
}

/**
 * Destructor function of this object removes all references
 * and deletes the content.
 *  
 */
static void 
delete_object()
{
    if ( mappingp(mReferences) ) {
	foreach(indices(mReferences), object o) {
	    if ( !objectp(o) ) continue;
	    
	    o->removed_link();
	}
    }
    ::delete_content();
    ::delete_object();
}

/**
 * Adding data storage is redirected to objects functionality.
 *  
 * @param function a - store function
 * @param function b - restore function
 * @return whether adding was successfull.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static bool
add_data_storage(function a, function b)
{
    return __object::add_data_storage(a,b);
}

/**
 * Get the content size of this document.
 *  
 * @return the content size in bytes.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_content_size()
{
    return __content::get_content_size();
}

/**
 * Returns the id of the content inside the Database.
 *  
 * @return the content-id inside database
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_content_id()
{
    object obj = CALLER;
    int             res;

    try_event(EVENT_DOWNLOAD, obj);    
    
    res = __content::get_content_id();
    run_event(EVENT_DOWNLOAD, obj);
    return res;
}

/**
 * Callback function when a download has finished.
 *  
 */
static void download_finished()
{
    run_event(EVENT_DOWNLOAD_FINISHED, CALLER);
}

/**
 * give status of Document similar to file->stat()
 *
 * @param  none
 * @return ({ \o700, size, atime, mtime, ctime, uid, 0 })
 * @see    file_stat
 * @author Ludger Merkens 
 */
array(int) stat()
{
    int creator_id = get_creator() ? get_creator()->get_object_id() : -1;
    
    return ({
	33279,  // -rwx------
	    get_content_size(),
	    do_query_attribute(OBJ_CREATION_TIME),
	    do_query_attribute(DOC_LAST_MODIFIED),
	    do_query_attribute(DOC_LAST_ACCESSED),
	    creator_id,
	    creator_id,
	    query_attribute(DOC_MIME_TYPE), // aditional, should not be a prob?
	    });
}

int get_object_class() { return ::get_object_class() | CLASS_DOCUMENT; }
final bool is_document() { return true; }

/**
 * content function used for download, this function really resides in
 * base/content and this overridden function just runs the appropriate event
 *  
 * @return the function for downloading (when socket has free space)
 * @author Thomas Bopp (astra@upb.de) 
 * @see receive_content
 */
function get_content_callback(mapping vars)
{
    object obj = CALLER;

    if ( functionp(obj->get_user_object) && objectp(obj->get_user_object()) )
	obj = obj->get_user_object();

    try_event(EVENT_DOWNLOAD, obj);

#if 1
    do_set_attribute(DOC_LAST_ACCESSED, time());
    require_save();
#endif
    run_event(EVENT_DOWNLOAD, obj);

    return __content::get_content_callback(vars);
}

/**
 * Get the content of this document as a string.
 *  
 * @param int|void len - optional parameter length of content to return.
 * @return the content or the first len bytes of it.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_content_callback
 */
string get_content(int|void len)
{
    string      content;
    object obj = CALLER;

    try_event(EVENT_DOWNLOAD, obj);
    content = ::get_content(len);

    do_set_attribute(DOC_LAST_ACCESSED, time());
    require_save();

    run_event(EVENT_DOWNLOAD, obj);
    return content;
}

/**
 * Callback function called when upload is finished.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void content_finished()
{
    __content::content_finished();
    run_event(EVENT_UPLOAD, this_user());
}

/**
 * content function used for upload, this function really resides in
 * base/content and this overridden function just runs the appropriate event
 *  
 * @return the function for uploading (called each time a chunk is received)
 * @author Thomas Bopp (astra@upb.de) 
 * @see get_content_callback
 */
function receive_content(int content_size)
{
    object obj = CALLER;
    if ( (obj->get_object_class() & CLASS_USER) && 
	 (functionp(obj->get_user_object) ) &&
	 objectp(obj->get_user_object()) )
	obj = obj->get_user_object();
    
    try_event(EVENT_UPLOAD, obj, content_size);
    set_attribute(DOC_LAST_MODIFIED, time());
    set_attribute(DOC_USER_MODIFIED, this_user());
    return __content::receive_content(content_size);
}

string describe()
{
    return get_identifier()+"(#"+get_object_id()+","+
	master()->describe_program(object_program(this_object()))+","+
	get_object_class()+","+do_query_attribute(DOC_MIME_TYPE)+")";
}




