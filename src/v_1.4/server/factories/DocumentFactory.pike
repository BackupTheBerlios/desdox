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
#include <attributes.h>
#include <database.h>
#include <events.h>
#include <types.h>
#include <classes.h>

/**
 * Initialization callback for the factory.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void init_factory()
{
    ::init_factory();
    init_class_attribute(DOC_LAST_MODIFIED, CMD_TYPE_TIME, 
			 "last modified", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, 0);
    init_class_attribute(DOC_USER_MODIFIED, CMD_TYPE_OBJECT,
			 "last modified by user",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, 0);
    init_class_attribute(DOC_LAST_ACCESSED, CMD_TYPE_TIME, 
			 "last accessed", 
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, 0);
    init_class_attribute(DOC_MIME_TYPE, CMD_TYPE_STRING, 
			 "for example text/html",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, "text/html");
    init_class_attribute(DOC_TYPE, CMD_TYPE_STRING, 
			 "the document type/extension",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER,"");
    init_class_attribute(DOC_TIMES_READ, CMD_TYPE_INT, "how often read",
			 0, EVENT_ATTRIBUTES_CHANGE, 0,
			 CONTROL_ATTR_SERVER, 0);
}

    
/**
 * Create a new instance of a document. The vars mapping should contain
 * the following entries:
 * url - the filename     or
 * name - the filename
 * mimetype - the mime type (optional)
 * externURL - content should be downloaded from the given URL.
 *  
 * @param mapping vars - some variables for the document creation.
 * @return the newly created document.
 * @author Thomas Bopp (astra@upb.de) 
 */
object execute(mapping vars)
{
    string ext, name, doc_class, fname, mimetype;
    array(string)                         tokens;
    int                                       sz;
    object                             cont, obj;
    string                                folder;

    string url = vars["url"];
    if ( !stringp(url) ) {
	url = vars["name"];
	fname = url;
	folder = "";
    }
    else {
	fname  = basename(url);
	folder = dirname(url);
	if ( strlen(folder) > 0 ) {
	    cont = get_module("filepath:tree")->path_to_object(folder);
	    if ( !objectp(cont) )
		steam_error("The Container " + folder + " was not found!");
	}
	
    }

    try_event(EVENT_EXECUTE, CALLER, url);


    SECURITY_LOG("Creating new document: " + url + ", fname:"+fname+
		 ",folder:"+folder);


    if ( !stringp(vars["mimetype"]) || vars["mimetype"] == "auto-detect" ||
	 search(vars["mimetype"], "/") == -1 ) 
    {
	tokens = fname / ".";
	if ( sizeof(tokens) >= 2 ) {
	    ext = tokens[-1]; // last token ?
	    ext = lower_case(ext);
	}
	else {
	    ext = "";
	}
	mimetype = _TYPES->query_mime_type(ext);
	doc_class = _TYPES->query_document_class(ext);
    }
    else {
	mimetype = vars["mimetype"];
	ext = "";
	doc_class = _TYPES->query_document_class_mime(vars->mimetype);
    }
    
    SECURITY_LOG("creating " + doc_class);
    if ( objectp(vars["move"]) ) {
	obj = object_create(fname, doc_class, vars["move"],vars["attributes"]);
    }
    else if ( objectp(cont) )
    {
	// Object is created somewhere
	SECURITY_LOG("Creating new object in "+ folder);
	obj = object_create(fname, doc_class, cont,
			    vars["attributes"],
			    vars["attributesAcquired"], 
			    vars["attributesLocked"]);
    }
    else {
	SECURITY_LOG("Creating new object in void");
	obj = object_create(
	    fname, doc_class, 0, vars["attributes"],
	    vars["attributesAcquired"], vars["attributesLocked"]);
    }
    if ( objectp(obj) ) {
	obj->set_attribute(DOC_TYPE, ext);
	obj->set_attribute(DOC_MIME_TYPE, mimetype);
    }
    if ( objectp(vars["acquire"]) )
	obj->set_acquire(vars["acquire"]);
    
    if ( objectp(vars["content_obj"]) )
	obj->set_content(vars["content_obj"]->get_content());

    if ( stringp(vars["externURL"]) )
	thread_create(download_url, obj, vars["externURL"]);

    run_event(EVENT_EXECUTE, CALLER, url);
    return obj->this();
}

/**
 * Download content from an extern URL.
 *  
 * @param object doc - the document
 * @param string url - the URL to download from.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void download_url(object doc, string url)
{
    mapping m;
    LOG("getting content !");
    Protocols.HTTP.Query q = Protocols.HTTP.get_url(
	url);
    if ( objectp(q) )
	m = q->cast("mapping");
    doc->set_content(m["data"]);
}

string get_identifier() { return "Document.factory"; }
string get_class_name() { return "Document"; }
int get_class_id() { return CLASS_DOCUMENT; }


mixed test()
{
    object doc = execute( ([ "name" : "test it.jpg", ]) );
    if ( !(doc->get_object_class() & CLASS_IMAGE) )
	steam_error(".jpg file does not create Image class!");
    if ( search(doc->query_attribute(DOC_MIME_TYPE), "image/") != 0 )
	steam_error("Image mimetype not set in .jpg document.");
    doc->delete();
    doc = execute ( ([ "name": "test.html", "mimetype":"text/html", ]) );
    if ( !(doc->get_object_class() & CLASS_DOCHTML) )
	steam_error("text/html mimetype does not produce DocHTML class.");
    if ( doc->query_attribute(DOC_MIME_TYPE) != "text/html" )
	steam_error("Got other mimetype than defined.");

    doc = execute ( ([ "name": "test.test.html", ]) );
    if ( !(doc->get_object_class() & CLASS_DOCHTML) )
	steam_error(".html ending does not produce DocHTML class.");
    if ( doc->query_attribute(DOC_MIME_TYPE) != "text/html" )
	steam_error("Got other mimetype than exptected.");
    if ( !catch( execute( ([ "url": "time/money" ]) ) ) )
	steam_error("URL with folder submitted does not throw !");
    doc = execute ( ([ "name": "time/money", ]) );
    return doc;
}


