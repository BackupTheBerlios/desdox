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
inherit "/classes/Document";

#include <macros.h>
#include <classes.h>
#include <assert.h>
#include <database.h>
#include <exception.h>
#include <attributes.h>
#include <events.h>

private static string  sContentCache = 0;
private static function        fExchange;
private static bool            __blocked;
private static string      sFilePosition;
private static object            oParser;
        static mapping            mLinks;

#define MODE_NORMAL 0
#define MODE_STRING 1

/**
 * Initialize the document and set data storage.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
static void init_document()
{
    mLinks = ([ ]);
    add_data_storage(store_links, restore_links);
}

/**
 * Return the quoted tag.
 *  
 * @param Parser.HTML p - parser context.
 * @param string tag - the tag.
 * @return quoted tag.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static mixed quote(Parser.HTML p, string tag)
{
    return ({ "<!--"+tag+"-->" });
}
/**
 * A scrip tag was found while parsing.
 *  
 * @param Parser.HTML p - the parser context.
 * @return script tag.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static mixed script(Parser.HTML p, string tag)
{
    LOG("Script Tag!!!\n"+tag+"\nEND\n");
    return ({ "<SCRIPT "+tag+"SCRIPT>" });
}

/**
 * Main function for link exchange. Called every time a potential
 * link tag was parsed.
 *  
 * @param Parser.HTML p - the parser context.
 * @param string tag - the tag found.
 * @return tag with exchanged links.
 * @author Thomas Bopp (astra@upb.de) 
 */
static mixed exchange_links(Parser.HTML p, string tag)
{
    array(string)  attr;
    mapping  attributes;
    mapping nattributes;
    string    attribute;
    bool   link = false;
    string        tname;
    int      mode, i, l;

    attributes = ([ ]);

    LOG("TAG:"+tag);

    l = strlen(tag);
    mode = MODE_NORMAL;
    i = 1;
    tname = "";
    int start = 1;
    
    attr = ({ });
    while ( i < l ) {	
	if ( tag[i] == '"' || tag[i] == '\'' ) 
	    mode = (mode+1)%2;
	else if ( (tag[i] == ' ' || tag[i] == '\t' || tag[i]=='\n') && 
		  mode == MODE_NORMAL ) 
	{
	    attr += ({ tag[start..i-1] });
	    start = i+1;
	}
	i++;
    }
    
    if ( tag[l-2] == '/' ) {
	if ( start < l-3 )
	    attr += ({ tag[start..l-3] });
    }
    else if ( start <= l-2 ) {
	attr += ({ tag[start..l-2] });
    }
	
    if ( arrayp(attr) && sizeof(attr) > 0 ) {
	string a, b;
	int       p;
	
	tname = attr[0];
	for ( int i = 1; i < sizeof(attr); i++ ) {
	    if ( (p = search(attr[i], "=")) > 0 ) {
		a = attr[i][..p-1];
		b = attr[i][p+1..];
		if ( strlen(b) > 0 ) {
		    if ( b[0] == '"' || b[0] == '\'' )
		    b = b[1..strlen(b)-2];
		    attributes[a] = b;
		}
	    }
	}
    }
    attr = indices(attributes);
    foreach(attr, attribute) {
	if ( lower_case(attribute) == "src" || lower_case(attribute) == "href" 
	     || lower_case(attribute) == "background" )
	{
	    mixed err = catch {
		attributes[attribute] = fExchange(attributes[attribute]);
	    };
	    link = true;
	}
    }

    
    string result;
    
    
    if ( link ) {
	result = "<"+tname;
	foreach(attr, attribute) {
	    result += " " + attribute + "=\""+attributes[attribute] + "\"";
	}
	if ( search(tag, "/>") > -1 )
	    result += "/>";
	else 
	    result += ">";
    }
    else
	result = tag;

    return ({ result }); // nothing to be done
}

/**
 * Upload is finished and links can be exchanged. Callback function.
 *  
 * @param int id - id for the content.
 * @author Thomas Bopp (astra@upb.de) 
 */
void finish_upload(int id)
{
    mixed err = catch {
	sFilePosition = _FILEPATH->object_to_path(this_object());
	reset_links();
	::save_chunk(sContentCache);
	::save_chunk(0);
	sContentCache = 0;
	__blocked = false;
    };
    if ( err != 0 ) {
	_LOG("Error while uploading:\n"+PRINT_BT(err));
	::save_chunk(0);
    }
}

/**
 * Callback function to save a chunk of data received by the server.
 *  
 * @param string chunk - the received chunk.
 * @author Thomas Bopp (astra@upb.de) 
 */
void save_chunk(string chunk)
{
    string _chunk;


    LOG("save_chunk("+(stringp(chunk) ? "string" : "null")+")");
    if ( objectp(oParser) ) {
	if ( !stringp(chunk) ) {
	    oParser->finish();
	    _chunk = oParser->read();
	    LOG("Result chunk=\n"+_chunk);
	    if ( stringp(_chunk) && strlen(_chunk) > 0 ) {
		::save_chunk(_chunk);
		sContentCache += _chunk;
	    }
	    destruct(oParser);
	    //finish_upload(get_object_id());
	    ::save_chunk(0);
	    return;
	}
	else {
	    oParser->feed(chunk, 1);
	    _chunk = oParser->read();
	}
    }
    else
	_chunk = chunk;
    
    LOG("Result chunk=\n"+_chunk);
    if ( stringp(_chunk) ) {
        ::save_chunk(_chunk);
        sContentCache += _chunk;
    }
    else { 
	::save_chunk(0);
    }
}

/**
 * Function to start an upload. Returns the save_chunk function.
 *  
 * @param int content_size the size of the content.
 * @return upload function.
 * @author Thomas Bopp (astra@upb.de) 
 */
function receive_content(int content_size)
{
    sContentCache = "";
    if ( objectp(oEnvironment) && 
	 oEnvironment->query_attribute(CONT_EXCHANGE_LINKS) == 1 ) 
    {
	sFilePosition = _FILEPATH->object_to_path(this_object());
	oParser = Parser.HTML();
	oParser->_set_tag_callback(exchange_links);
	oParser->add_quote_tag("!--", quote, "--");
	oParser->add_quote_tag("SCRIPT", script, "SCRIPT");
	fExchange = exchange_link;
	reset_links();
    }
    return ::receive_content(content_size);
}

/**
 * Analyse a given path. This function actually looks suspicious (bugs???).
 *  
 * @param string p - the path to analyse
 * @return array of size 2 with - I give up.
 */
array(string) analyse_path(string p)
{
    array(string) tokens = p / "/";
    int sz = sizeof(tokens);
    if ( sz < 2 )
       return ({ p, "" }); 
    else if ( sz == 2 )
       return ({ tokens[0], tokens[1] });
    return ({ tokens[sz-1], tokens[0..sz]*"/" });
}

/**
 * Create a path inside steam which is a sequenz of containers.
 *  
 * @param string p - the path to create.
 * @return the container created last.
 */
static object create_path(string p)
{
   LOG("create_path("+p+")");
   array(string) tokens = p / "/"; 
   object cont = _ROOTROOM;
   object factory = _Server->get_factory(CLASS_CONTAINER);

   for ( int i = 0; i < sizeof(tokens)-1; i++) {
      object obj;
      if ( tokens[i] == "" ) 
	  continue;
      obj = _FILEPATH->resolve_path(cont, tokens[i]);
      if ( !objectp(obj) ) {
          obj = factory->execute((["name":tokens[i],]));
	  obj->move(cont);
      } 
      else LOG("Found path in cont: " + tokens[i]);
      cont = obj;
   }
   LOG("Found:" + cont->get_identifier());
   return cont;
}

/**
 * Exchange a single link. Lookup the path and eventually create an object
 * at the specified point. 
 *  
 * @param string link - the link to exchange.
 * @return exchanged link
 * @author Thomas Bopp (astra@upb.de) 
 */
string exchange_link(string link)
{
    object                     obj;
    string linkstr, position, type;
    int                       i, l;

    LOG("exchange_link("+link+");");
    link = replace(link, "\\", "/");
    if ( search(link, "get.pike") >= 0 || search(link, "navigate.pike") >= 0 )
	return link;
    
    if ( sscanf(link, "%s://%s", type, linkstr) == 2 ) {
	add_extern_link(linkstr, type);
	return link;
    }
	
    if ( sscanf(link, "mailto:%s", linkstr) == 1 )
    {
	add_extern_link(linkstr, "mailto");
	return link;
    }
    
    if ( sscanf(lower_case(link), "javascript:%s", linkstr) == 1 ) {
	//link = linkstr;
	//type = "javascript:";
	return link; // dont touch javascript !
    } 
    else type = "http://";

    if ( sscanf(link, "%s#%s", linkstr, position) == 2 ) {
	link = linkstr;
    }

    if ( link == get_identifier() ) {
	add_local_link(this(), type, position);
	return type + "/scripts/get.pike?object="+get_object_id() + 
	    (stringp(position) ? "#"+position:"");
    }
    string varstr;

    if ( sscanf(link, "%s?%s", linkstr, varstr) == 2 ) {
	link = linkstr;
	varstr = "?" + varstr;
    }
    else
	varstr = "";
    
    if ( link[0] != '/' ) 
	link = sFilePosition + link;
    
    if ( search(link, "../") >= 0 ) {
	array(string) tokens = link / "/";
	LOG("Previous absolute link="+link);
	link = "";
	for ( i = 0; i < sizeof(tokens); i++ ) {
	    if ( i > 0 && tokens[i] == ".." ) {
		// remove this token and the token before
		tokens[i] = "";
		int j;
		j = i-1;
		while ( j >= 0 && tokens[j] == "" )
		    j--;

		tokens[j] = "";
		LOG("Token " + i + " is .. and removing token " + j);
	    }
	}
	link = "/" + tokens[0];
	
	for ( i = 1; i < sizeof(tokens); i++ )
	    if ( link[strlen(link)-1] != '/' )
		link += "/" + tokens[i];
	    else
		link += tokens[i];
	LOG("New absolute link="+link);
    }
	
    mixed err = catch {
	obj = _FILEPATH->path_to_object(link);
    };

    if ( !objectp(obj) ) {
	object     factory;
	string fname, path;

	factory = _Server->get_factory(CLASS_DOCUMENT);
        [ fname, path ] = analyse_path(link);
	object cont = create_path(path);
	obj = factory->execute((["url":fname,]));
	obj->move(cont);
	LOG("Creating new:" + link);
	ASSERTINFO(objectp(obj), "Failed to create object !");
    }

#if 0
    if ( !objectp(obj) )
	return type + "/scripts/get.pike?object=" + link + 
	    (stringp(position) ? "#"+position:"");
	
#endif
    if ( obj->get_object_class() == CLASS_OBJECT )
	return type + link;
    
    add_local_link(obj, type, position);
    return type + _Server->query_config(CFG_WEBSERVER) + ":" +
	_Server->query_config(CFG_WEBPORT_PRESENTATION)+
	"/scripts/get.pike?object=" + obj->get_object_id() + 
	(stringp(position) ? "#"+position:"") + varstr;
}

/**
 * Re-exchange a link again.
 *  
 * @param string link - the link to re-exchange.
 * @return the re-exchanged link.
 * @author Thomas Bopp (astra@upb.de) 
 */
string re_exchange_link(string link)
{
    object                     obj;
    int                         id;
    string                str, jpt;

    LOG("re_exchange_link("+link+")");
    str = jpt = "";
    if ( sscanf(link, "%*sget.pike?object=%d%s", id, str) >= 1 ) {
	obj = find_object(id);
    }
    else
	return link;
    
    LOG("re-exchanging link on object="+id);
    sscanf(str, "#%s", jpt);
    // now find out the matching parts of the path
    int i, sz;
    array(string) ptokens, mytokens;
    string rel = "";

    ptokens = (_FILEPATH->object_to_path(obj)+obj->get_identifier()) / "/";
    mytokens = _FILEPATH->object_to_path(this_object()) / "/";
    sz = MIN(sizeof(ptokens), sizeof(mytokens));
    

    i = 0;
    while ( i < sz && ptokens[i] == mytokens[i] ) i++;
    
    if ( sizeof(mytokens) > i+1 )
	for ( int j = 0; j < (sizeof(mytokens)-i-1); j++ )
	    rel += "../";

    rel = rel + (ptokens[i..]*"/");
    if ( strlen(jpt) > 0  ) 
	rel += "#" + jpt;
    
    return rel;
}

/**
 * this is the content callback function
 * in this case we have to read the whole content at once hmmm
 *  
 * @param int pos - the current position of sending.
 * @return chunk of content.
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static string
send_content_html(int pos)
{
    string result;

    if ( !stringp(sContentCache) )
	return 0; // finished
    
    if ( strlen(sContentCache) < DB_CHUNK_SIZE ) {
	result = copy_value(sContentCache);
	sContentCache = 0;
    }
    else {
	result = sContentCache[..DB_CHUNK_SIZE-1];
	sContentCache = sContentCache[DB_CHUNK_SIZE..];
    }
    return result;
}

/**
 * Get the whole content and for ftp connections re-exchange
 * all the links to retrieve the original content.
 *  
 * @return the content
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string get_content()
{
    object caller = CALLER;
    string content = ::get_content();
    
    if ( functionp(caller->get_client_class) &&
	 caller->get_client_class() == "ftp" ) 
    {
	object parser = Parser.HTML();
	fExchange = re_exchange_link;
	parser->_set_tag_callback(exchange_links);
	parser->feed(content);
	parser->finish();
	return parser->read();
    }
    return content;
}

/**
 * Get the callback function for content.
 *  
 * @param mapping vars - the variables from the web server.
 * @return content function.
 * @author Thomas Bopp (astra@upb.de) 
 */
function get_content_callback(mapping vars)
{
    object caller = CALLER;
    function cb;

    LOG("get_content_callback() by " + caller->get_client_class());
    cb = ::get_content_callback(vars);
    
    if ( functionp(caller->get_client_class) && 
	 caller->get_client_class() != "ftp" )
	return cb;
    
    sContentCache = "";
    string buf;
    int    pos = 0;
    while ( stringp(buf = cb(pos)) ) {
	sContentCache += buf;
	pos += strlen(buf);
    }
    object parser = Parser.HTML();
    fExchange = re_exchange_link;
    parser->_set_tag_callback(exchange_links);
    parser->feed(sContentCache);
    parser->finish();
    sContentCache = parser->read();
    //LOG("Result of parsing: " + sContentCache);    
    return send_content_html;
}

/**
 * Return mapping with save data used by _Database.
 *  
 * @return all the links.
 * @author Thomas Bopp (astra@upb.de) 
 */
mixed
store_links() 
{
    if ( CALLER != _Database ) 
	THROW("Caller is not Database !", E_ACCESS);
    return ([ "Links": mLinks, ]);
}

/**
 * Restore the saved link data. This is called by database and
 * sets the Links mapping again.
 *  
 * @param mixed data - saved data.
 * @author Thomas Bopp (astra@upb.de) 
 */
void restore_links(mixed data)
{
    if (CALLER != _Database ) THROW("Caller is not Database !", E_ACCESS);
    mLinks = data["Links"];
}

/**
 * Add a local link.
 *  
 * @param object o - the object containing a reference to this doc.
 * @param string type - the typ of reference.
 * @string position - where the link points.
 * @author Thomas Bopp (astra@upb.de) 
 */
static void add_local_link(object o, string type, string position)
{
    if ( !mappingp(mLinks[o]) ) 
	mLinks[o] = ([ position: 1 ]);
    else {
	if ( zero_type(mLinks[o][position]) )
	    mLinks[o][position] = 1;
	else
	    mLinks[o][position]++;
    }
    o->add_reference(this());
    require_save();
}


/**
 * Add an extern link to some URL.
 *  
 * @param string url - the url to point to.
 * @param string type - the type of the link.
 * @author Thomas Bopp (astra@upb.de) 
 */
static void add_extern_link(string url, string type)
{
    if ( zero_type(mLinks[url]) )
	mLinks[url] = 1;
    else
	mLinks[url]++;
    require_save();
	
}

/**
 * an object was deleted and so the link to this object is outdated !
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
void removed_link()
{
    object link = CALLER->this();
    object creator = get_creator();
    run_event(EVENT_REF_GONE, link, creator);
}


/**
 * Reset all saved link data.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
static void reset_links()
{
    // first remove all references on other objects
    if ( mappingp(mLinks) ) {
	foreach(indices(mLinks), mixed index) {
	    if ( objectp(index) ) {
		index->remove_reference(this());
	    }
	}
    }
    mLinks = ([ ]);
}

/**
 * Get a copy of the Links mapping.
 *  
 * @return copied link mapping.
 * @author Thomas Bopp (astra@upb.de) 
 */
mapping get_links()
{
    return copy_value(mLinks);
}


/**
 * Get the object class which is CLASS_DOCHTML of course.
 *  
 * @return the object class.
 * @author Thomas Bopp (astra@upb.de) 
 */
int
get_object_class()
{
    return ::get_object_class() | CLASS_DOCHTML;
}

/**
 * Get the size of the content which is the size of the document
 * with exchanged links.
 *  
 * @return the content size.
 * @author Thomas Bopp (astra@upb.de) 
 */
int get_content_size()
{
    return (stringp(sContentCache) ? 
	    strlen(sContentCache) : ::get_content_size());
}
