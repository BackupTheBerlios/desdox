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

//! This class keep XSL Stylesheets and is able to do XSLT with libxslt

inherit "/base/xml_parser";
inherit "/base/xml_data";
inherit "/classes/Document";

#include <macros.h>
#include <database.h>
#include <attributes.h>
#include <config.h>
#include <classes.h>
#include <events.h>
#include <exception.h>

//#define DOCXSL_DEBUG

#ifdef DOCXSL_DEBUG
#define DEBUG_DOCXSL(s) werror(s+"\n")
#else
#define DEBUG_DOCXSL
#endif

static object              XML;
static mapping    mXML = ([ ]);
static mapping mDepend = ([ ]);

static object xsl_english, xsl_german; // english and german stylesheets
static mapping mStylesheets = ([ ]);  // all stylesheet objects
static mapping mEnglish, mGerman;     // english and german tags
static object oDescriptionXML;
static mapping usedTags;              // special rxml tags used

/**
 * Initialize the document
 *  
 */
static void init_document()
{
    XML =  _Server->get_module("Converter:XML");
    usedTags = ([ ]);
}

/**
 * load the document - initialize the xslt.Stylesheet() object.
 * This is called when the XSL stylesheet is loaded.
 *  
 */
static void load_document()
{
    XML =  _Server->get_module("Converter:XML");
    load_xml_structure();
}

/**
 * Get a mapping of all tags.
 *  
 * @return tag-name: tag-handler mapping
 */
mapping get_tags() 
{
    return usedTags;
}


/**
 * Add a dependant stylesheet and notify it when the content
 * of this stylesheet changed.
 *  
 * @param object o - the dependant stylesheet
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void add_depend(object o)
{
    mDepend[o] = 1;
}

/**
 * callback function to find a stylesheet.
 *  
 * @param string uri - the uri to locate the stylesheet
 * @return the stylesheet content or zero.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static string|int
find_stylesheet(string uri, string language)
{
    object  obj;
    object cont;
    int       i;
    
    LOG("find_stylesheet("+uri+","+language+")");
    uri = uri[1..];
    if ( uri[0] == '/' ) {
	obj = _FILEPATH->path_to_object(uri);
	if ( objectp(obj) ) {
	    obj->add_depend(this());
	    string contstr = obj->get_content(language);
	    return contstr;
	}
	FATAL("Failed to find Stylesheet: "+ uri +" !");
	return 0;
    }
    
    cont = _ROOTROOM;
    while ( (i=search(uri, "../")) == 0 && objectp(cont) ) {
	cont = cont->get_environment();
	uri = uri[3..];
    }
    LOG("Looking up in " + _FILEPATH->object_to_filename(cont));
    obj = _FILEPATH->resolve_path(cont, uri);

    if ( objectp(obj) ) {
	obj->add_depend(this());
        return obj->get_content(language);
    }
    return 0;
}

static int match_stylesheet(string uri)
{
    if ( search(uri, "steam:") == 0 )
	return 1;
    return 0;
}

static object open_stylesheet(string uri)
{
    sscanf(uri, "steam:/%s", uri);
    object obj = _FILEPATH->path_to_object(uri);
    
    if ( !objectp(obj) ) {
	FATAL("Stylesheet " + uri + " not found !");
	return 0;
    }
    DEBUG_DOCXSL("open_stylesheet("+uri+") - " + (objectp(obj)?"success":"failed"));
    obj->add_depend(this());
    return obj;
}

static string|int
read_stylesheet(object obj, string language, int position)
{
    if ( objectp(obj) ) {
	DEBUG_DOCXSL("read_stylesheet(language="+language+")");
	string contstr = obj->get_content(language);
	DEBUG_DOCXSL("length="+strlen(contstr) + " of " + obj->get_object_id());
	return contstr;
    }
    DEBUG_DOCXSL("No stylesheet given for reading...");
    return 0;
}

static void
close_stylesheet(object obj)
{
}

static void clean_xsls()
{
    if ( objectp(xsl_english) ) 
	destruct(xsl_english);
    if ( objectp(xsl_german) )
	destruct(xsl_german);
    xsl_english=0;
    xsl_german=0;
   foreach( indices(mDepend), object o ) {
	if ( objectp(o) )
	    o->inc_stylesheet_changed();
    }
}

void inc_stylesheet_changed()
{
    DEBUG_DOCXSL("Reloading XSL Stylesheet: "+get_identifier());
    clean_xsls();
}


/**
 * Unserialize a myobject tag from the xml description file.
 *  
 * @param string data - myobject data.
 * @return the corresponding object
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static object unserialize_myobject(string data)
{
    int id = (int) data;
    if ( id != 0 ) {
	return (object)find_object(id);
    }
    string prefix, val;
    if ( sscanf(data, "%s:%s", prefix, val) == 2 ) {
      switch ( prefix ) {
      case "group":
	return MODULE_GROUPS->lookup(val);
      case "orb":
	return _FILEPATH->path_to_object(val);
      case "url":
	return get_module("filepath:url")->path_to_object(val);
      }
    }
    
    switch(data) {
	case "THIS":
	    return XML->THIS;
	    break;
        case "ENV":
	    return XML->THIS->ENV;
	case "CONV":
	    return XML;
	    break;
	case "THIS_USER":
	    return XML->THIS_USER;
	    break;
	case "SERVER":
	    return _Server;
	    break;
	case "LAST":
	    return XML->LAST;
	    break;
	case "ACTIVE":
	    return XML->ACTIVE;
	    break;
	case "ENTRY":
	    return XML->ENTRY;
	    break;
	case "XSL":
	    return XML->XSL;
	    break;
        case "STEAM":
	    return MODULE_GROUPS->lookup("sTeam");
	    break;
        case "local":
	    return this_object();
	    break;
        case "master": 
	    return master();
	    break;
	case "server":
	    return _Server;
	    break;
        case "ADMIN":
	    return MODULE_GROUPS->lookup("admin");
	    break;
        default:
	    return _Server->get_module(data);
	    break;
    }
    return 0;
}

mapping get_default_map(string data)
{
    switch (data) {
    case "objects":
	return XML->objXML;
	break;
    case "exits":
	return XML->exitXML;
	break;
    case "links":
	return XML->linkXML;
	break;
    case "users":
	return XML->userXML;
	break;
    case "usersInv":
      	return XML->userInvXML;
	break;
    case "container":
	return XML->containerXML;
	break;
    }
    return 0;
}

mixed unserialize_var(mixed name, mixed defval)
{
    return XML->get_var(name, defval);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mixed unserialize(NodeXML n) 
{
    function func;
    if ( n->name == "myobject" || n->name == "o" ) {
	return unserialize_myobject(n->data);
    }
    else if ( n->name == "var" ) {
      object datanode = n->get_node("def");
      if ( sizeof(datanode->sibling) ) {
	werror("datanode with sibling found:" +
	       datanode->sibling[0]->data+"\n");
	return unserialize_var(
	    n->get_node("name")->data, 
	    unserialize(datanode->sibling[0]));
      }
      else
	return unserialize_var(
	    n->get_node("name")->data, 
	    n->get_node("def")->data);
    }
    else if ( n->name == "object" ) {
      object node = n->get_node("path");
      if ( objectp(node) ) {
	if ( node->name="group" )
	  return MODULE_GROUPS->lookup(node->data);
	else if ( node->name = "path" )
	  return get_module("filepath:tree")->path_to_object(node->data);
      }
    }
    else if ( n->name == "maps" ) {
	mapping res = ([ ]);
	foreach(n->sibling, NodeXML sibling) {
	  mapping m = get_default_map(sibling->data);
	  res |= m;
	}
	return res;
    }
    else if ( n->name == "function" ) {
	NodeXML obj = n->get_node("object");
	NodeXML f   = n->get_node("name");
	NodeXML id  = n->get_node("id");
	switch ( obj->data ) {
	case "local":
	    func = (function)this_object()[f->data];
	    break;
	case "master": 
	    object m = master();
	    func = [function](m[f->data]);
	    break;
	case "server":
	    func = [function](_Server[f->data]);
	    break;
	default:
	    object o;
	    o = _Server->get_module(obj->data);
	    if ( !objectp(o) )
		return 0;
	    mixed err = catch {
	        func = o->find_function(f->data);
	    };
	    if ( err != 0 ) {
		LOG("Failed to deserialize function: " + f->data + 
		    " inside " + master()->describe_object(o) + "\n"+
		    err[0] + "\n" + sprintf("%O", err[1]));
		return 0;
	    }
	    break;
	}
	if ( !functionp(func) )
	    LOG("unserialize_function: no functionp :"+
		sprintf("%O\n",func));
	return func;
    }
    return ::unserialize(n);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
string compose_scalar(mixed val)
{
    if ( objectp(val) ) {
	if ( val == XML->THIS )
	    return "<myobject>THIS</myobject>";
	else if ( val == XML->CONV )
	    return "<myobject>CONV</myobject>";
	else if ( XML->THIS_USER == val )
	    return "<myobject>THIS_USER</myobject>";
	else if ( _Server == val )
	    return "<myobject>SERVER</myobject>";
	else if ( XML->LAST == val )
	    return "<myobject>LAST</myobject>";
	else if ( XML->ACTIVE == val )
	    return "<myobject>ACTIVE</myobject>";
	else if ( XML->ENTRY == val )
	    return "<myobject>ENTRY</myobject>";
	else if ( XML->XSL == val )
	    return "<myobject>XSL</myobject>";
    }
    return ::compose_scalar(val);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mixed compose(mixed m)
{
    if ( functionp(m) ) {
	object o = function_object(m);
	if ( !objectp(o) ) {
	    LOG("function without object:" + function_name(m));
	    return "";
	}
	if ( o == this_object()) 
	    return "<function><object>local</object><name>"+function_name(m)+
		"</name></function>";
	else if ( o == master()  )
	    return "<function><object>master</object>"+
		"<name>"+function_name(m) + "</name></function>";
	else if ( o == _Server )
	    return "<function><object>server</object>"+
		"<name>"+function_name(m) + "</name></function>";
	else 
	    return "<function><id>"+o->get_object_id()+
		"</id><object>"+o->get_identifier()+"</object>"+
		"<name>"+function_name(m) + "</name></function>";
    }
    return ::compose(m);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void load_xml_structure()
{
   if ( objectp(oEnvironment) ) {
	object xml = oEnvironment->get_object_byname(get_identifier()+".xml");
	if ( !objectp(xml) && CALLER == this_object() ) {
	    // load anything
	    xml = OBJ("/stylesheets/public.xsl.xml");
	}
	if ( objectp(xml) ) {
	    usedTags = ([ ]);

	    NodeXML n = parse_data(xml->get_content());
	    mixed err = catch {
		if ( !objectp(n) )
		    throw( ({ "Root node '<structure>' not found in "+
				  "XML description file !", backtrace() }) );
		if ( n->name == "structure" ) {
		    mXML = xmlTags(n);
		}
		else
		   mXML = xmlMap(n);
	    };
	    if ( err != 0 ) {
		FATAL("Error while generating xml map ["
		      +xml->get_identifier()+"]:\n"+err[0]+
		      sprintf("%O",err[1]));
		if ( CALLER != this_object() )
		    throw(err);
	    }
	    else {
		clean_xsls();
	    }
	}
	else {
	    if ( CALLER != this_object() ) {
		THROW("No description file ("+get_identifier()
		      +".xml) found for Stylesheet !", E_ERROR);
	    }
	}
	
    }
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping get_xml_structure()
{
    return copy_value(mXML);
}



/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
function|mapping xmlTagShowFunc(NodeXML n)
{
    NodeXML f = n->get_node("f");
    if ( !objectp(f) ) {
	NodeXML m = n->get_node("map");
	if ( !objectp(m) )
	    m = n->get_node("structure");
	if ( !objectp(m) )
	    return 0;
	mapping res = ([ ]);
	res += xmlTags(m);
	if ( m->attributes->name )
	    res["name"] = m->attributes->name;
	
	foreach(m->sibling, object tag) {
	    if ( tag->name == "tag" ) {
		res[tag->attributes->name] += xmlTag(tag);
	    }
	    else if ( tag->name == "def" ) {
		res += get_default_map(tag->data);
	    }
	}
	return res;
    }
    function func;
    object    obj;

    NodeXML na = f->get_node("n");
    NodeXML o  = f->get_node("o");
    if ( !objectp(n) )
	THROW("Function tag (f) has no sub tag 'n' !", E_ERROR);

    if ( !objectp(o) )
	obj = XML;
    else {
	obj = unserialize_myobject(o->data);
    }

    
    mixed err = catch {
	func = [function]obj->find_function(na->data);
    };
    if ( err != 0 ) {
	LOG("Failed to deserialize function: " + na->data + 
	    " inside " + master()->describe_object(obj) + "\n"+
	    err[0] + "\n" + sprintf("%O", err[1]));
	return 0;
    }
    return func;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
array xmlTagCallFunc(NodeXML n)
{
    array res, params;

    NodeXML f = n->get_node("n");
    NodeXML o = n->get_node("o");
    NodeXML p = n->get_node("p");
    
    object obj;
    
    if ( !objectp(f) ) 
	THROW("No Node n (function-name) found at function tag", E_ERROR);

    if ( !objectp(o) )
	obj = XML->THIS;
    else 
	obj = unserialize_myobject(o->data);
    if ( objectp(p) ) {
	if ( stringp(p->data) && strlen(p->data) > 0 )
	    steam_error("Found data in param tag - all params need to be "+
			"in type tags like <int>42</int>.\n");
	params = xmlArray(p);
    }
    if ( !arrayp(params) )
	params = ({ });
    
    res = ({ obj, f->data, params, 0 });
    return res;
}

array xmlTag(NodeXML n) 
{
    array res;
    res = xmlTagCallFunc(n->get_node("call/f"));
    res[3] = xmlTagShowFunc(n->get_node("show"));
    return res;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping xmlTags(NodeXML n) 
{
    mapping res = ([ ]);
    foreach(n->sibling, object node) {
	if ( node->name == "class" ) {
	    int t;
	    if ( sscanf(node->attributes->type, "%d", t) != 1 ) {
		object f = _Server->get_factory(node->attributes->type);
		if ( objectp(f) )
		    t = f->get_class_id();
	    }
	    res[t] = ([ ]);
	    foreach(node->get_nodes("tag"), object tag) {
		res[t][tag->attributes->name] = xmlTag(tag);
	    }
	}
	else if ( node->name == "language" ) {
	    res[node->attributes->name] = ([ ]);
	    foreach(node->get_nodes("term"), object term) {
		res[node->attributes->name]["{"+term->attributes->name+"}"]=
		    term->data;
	    }
	}
	else if ( node->name == "tags" ) {
	    foreach(node->get_nodes("tag"), object tag) {
		usedTags[tag->attributes->name] = find_object(tag->get_data());
	    }
	}
    }
    if ( n->attributes->name )
	res["name"] = n->attributes->name;

    return res;
}

void set_xml_structure(mapping x)
{
    mXML = copy_value(x);
}

string serialize_xml()
{
    object factory = _Server->get_factory(CLASS_DOCUMENT);

    object o;
    o = oEnvironment->get_object_byname(get_identifier()+"xml");
    if ( !objectp(o) )
	o = factory->execute((["name":get_identifier()+".xml",]));
    string xml = compose(mXML);
    o->set_content(xml);
    o->move(oEnvironment);
    return xml;
}

static void 
content_finished()
{
    // successfull upload...
    ::content_finished();
    clean_xsls();



}

string get_content(void|string language)
{
    if ( stringp(language) ) {
	string str = ::get_content();
	if ( mappingp(mXML[language]) ) {
	    str = replace(str, indices(mXML[language]),values(mXML[language]));
	}
	return str;
    }
    else 
	return ::get_content();
}

/**
 * Get the xslt.Stylesheet() object.
 *  
 * @return the stylesheet.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object get_stylesheet(string|void language)
{
    mixed err;

    if ( !objectp(xsl_english) ) {
	xsl_english = xslt.Stylesheet();
	xsl_german  = xslt.Stylesheet();

	// now I got some (the real one, but it needs internationalization)
	err = catch {
	    string xsl_code = get_content("english");
	    xsl_english->set_include_callbacks(match_stylesheet,
					       open_stylesheet,
					       read_stylesheet,
					       close_stylesheet);
	
	    xsl_english->set_language("english");
	    xsl_english->set_content(xsl_code);
	    mStylesheets["english"] = xsl_english;
	};
	if ( err != 0 ) {
	    destruct(xsl_english);
	    xsl_english = 0;
	    destruct(xsl_german);
	    xsl_german = 0;
	    throw(err);
	}
	 
	err = catch {
	    string ger_xsl_code = get_content("german");
	    xsl_german->set_include_callbacks(match_stylesheet,
					      open_stylesheet,
					      read_stylesheet,
					      close_stylesheet);
	    xsl_german->set_language("german");
	    xsl_german->set_content(ger_xsl_code);
	    mStylesheets["german"] = xsl_german;
	};
	if ( err != 0 ) {
	    destruct(xsl_english);
	    xsl_english = 0;
	    destruct(xsl_german);
	    xsl_german = 0;
	    throw(err);
	}
    }

    LOG("Getting stylesheet " + get_identifier() + ",language="+language);
    if ( !stringp(language) )
	language = "english";

    if ( objectp(mStylesheets[language]) ) {
	return mStylesheets[language];
    }
    return xsl_english;
}

string get_method()
{
    object xsl = get_stylesheet();
    if ( objectp(xsl) )
	return xsl->get_method();
    return "plain";
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
array(string) get_styles() 
{ 
    return ({ "content", "attributes", "access", "annotations" });
}

int get_object_class() { return ::get_object_class() | CLASS_DOCXSL; }

