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
#include <database.h>
#include <attributes.h>
#include <classes.h>
#include <exception.h>

#define NNTP_DEBUG

#ifdef NNTP_DEBUG
#define NNTP_LOG(s) werror(s +"\n");
#else
#define NNTP_LOG(s)
#endif

#define HEADER_SEP "\r\n"
#define HEADER_SEP_RCV  "\r\n\r\n"

//! This is a wrapper class for use with nttp. It encapsulates sTeam
//! message boards (objects with annotations in general) and supports
//! nntp functionality for them.

static array(Group) aGroups;
static string       sServer;

class Group {
    object            oSteamObj;
    string             name = 0;
    int            iStart, iEnd;
    mapping mReferences = ([ ]);
    mapping mArticles   = ([ ]);
    

    string get_name() { 
	if ( name != 0 )
	    return name;
	if ( !objectp(oSteamObj) )
	    return "";

	if ( !objectp(_FILEPATH) )
	    return "steam." + oSteamObj->get_identifier(); 
	string path = _FILEPATH->object_to_filename(oSteamObj);
	array tokens = path / "/";
	if ( sizeof(tokens) < 3 ) 
	    name = replace(path,"/",".");
	else
	    name = (tokens[2..]*".");
	name = replace(name, ({ " ", "\t" }), ({ "_", "_" }));
	return name;
    }
    int get_last_message() {
	array articles = get_articles();
	return iEnd;
    }
    int get_first_message() {
	return iStart;
    }
    int get_num_messages() {
	array articles = get_articles();
	return sizeof(articles());
    }
    bool read_access(object user) {
	mixed err = catch {
	    _SECURITY->access_read(oSteamObj, user);
	};
	return err == 0;
    }
    bool write_access(object user) {
	mixed err = catch {
	    _SECURITY->access_write(oSteamObj, user);
	};
	return err == 0;
    }
    bool newer_than(int date, int t) {
	return true;
    }
    void add_article(object article, string ref) {
	object refobj;
	if ( !stringp(ref) ) 
	    refobj = oSteamObj;
	else {
	    int iRef;
	    sscanf(ref, "<%d@%*s>", iRef);
	    refobj = find_object(iRef);
	}
	refobj->add_annotation(article);
	article->set_acquire(refobj);
    }
    bool can_post() {
	mixed err = catch {
	    _SECURITY->access_annotate(oSteamObj, this_user(), 0);
	};
	if ( err != 0 )
	    return false;
	
	return true;
    }

    static void get_sub_articles(object article) {
	array(object) subarticles = article->get_annotations_for();
	foreach( subarticles, object sub) {
	    mReferences[sub] = article;
	    mArticles[sub]   = iEnd++;
	    get_sub_articles(sub);
	}
	
    }
    // Fixme: should only fetch articles from time to time
    array(object) get_articles() {
	iStart = 1;
	iEnd   = 1;
	
	array(object) articles = oSteamObj->get_annotations_for();
	NNTP_LOG("get_articles() == \n"+sprintf("%O", articles)+
	    "\n for "+oSteamObj->get_identifier());
	foreach ( articles, object article ) {
	    mArticles[article] = iEnd++;
	    get_sub_articles(article);
	}
	return indices(mArticles);
    }
    object get_article(int id) {
	foreach(indices(mArticles), object article)
	    if ( mArticles[article] == id )
		return article;
	return 0;
		
    }
    object get_article_num(object article) {
	return mArticles[article];
    }

    string get_time(int t) {
	string tf = ctime(t);
	sscanf(tf, "%s\n", tf);
	return tf;
    }
    string id(int|object article) {
	if ( objectp(article) ) 
	    return "<"+article->get_object_id()+"@"+sServer+">";
	return "<"+article+"@"+sServer+">";
    }
    string header(object article) {
	object creator = article->get_creator();
	string name = creator->query_attribute(USER_EMAIL);
	if ( !stringp(name) ) 
	    name = creator->get_identifier();
	else
	    name = creator->query_attribute(USER_FULLNAME) + " <"+name+">";

	string res = mArticles[article] + "\t"+
	    article->query_attribute(OBJ_NAME)+"\t"+
	    name+"\t"+
	    get_time(article->query_attribute(OBJ_CREATION_TIME))+"\t"+
	    id(article)+"\t"+
	    (objectp(mReferences[article]) ? get_references(article)+"\t":"")+
	    article->get_content_size()+"\t"+
	    sizeof((article->get_content()/"\n"))+"\t"+
	    "Xref: "+sServer+" " + get_name()+ ":"+mArticles[article];
	NNTP_LOG("Header:\n"+res);
	return res;
    }
    string get_references(object article) {
	if ( !objectp(mReferences[article]) )
	    return "";
	string ref = get_references(mReferences[article]);
	if ( strlen(ref) > 0 ) ref += " ";
	ref += "<"+mReferences[article]->get_object_id()+"@"+sServer+">";
	return ref;
    }

    string get_header(object article) {
	if ( !objectp(article) ) 
	    return 0;

	string header = _Server->get_module("message")->header(article);
	header += "Path: not-for-mail"+HEADER_SEP+
	    "User-Agent: sTeam Forum"+HEADER_SEP+
	    "Newsgroups: " + get_name()+HEADER_SEP+
	    "Xref: "+sServer+" "+get_name()+":"+mArticles[article]+HEADER_SEP+
	    (objectp(mReferences[article]) ? 
	     "References:" + get_references(article) + HEADER_SEP : "");
	return header;
    }
    string get_body(object article) {
	return article->get_content();
    }
    object get_next_article(object article) {
	array articles = get_articles();
	int i = search(articles, article);
	if ( sizeof(articles) > i )
	    return articles[i+1];
	return 0;
    }
    static void create(object o, string|void grp_name) {
	oSteamObj = o;
	if ( stringp(grp_name) )
	    name = grp_name;
    }
    int get_object_id() { 
	return (objectp(oSteamObj) ? 
		oSteamObj->get_object_id() :
		0); 
    }
    object this() { return oSteamObj; }
    object get_object() { return oSteamObj->get_object(); }
    string get_identifier() { return "nntp:mailbox"; }
}

/**
 * Callback to initialize the module.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void init_module()
{
    object objects = _Server->get_module("objects");
    if ( objectp(objects) ) 
	aGroups = ({ Group(objects->lookup("bugs")), 
			 Group(objects->lookup("ideas")) });
    else
	aGroups = ({ });
    sServer = _Server->query_config("server") + "." + 
	_Server->query_config("domain");
    set_attribute(OBJ_DESC, "This module functions as a nntp server.");
    add_data_storage(retrieve_groups, restore_groups);
}

/**
 * Restore function to restore group data of NNTP.
 *  
 * @param mapping data - the saved data mapping.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void restore_groups(mapping data)
{
    if ( CALLER != _Database )
	THROW("Invalud call to restore_groups() !", E_ACCESS);
    array groups = data["groups"];
    aGroups = ({ });
    foreach(groups, object g) {
	if ( objectp(g) )
	    aGroups += ({ Group(g) });
    }
}

/**
 * Retrieve the group data.
 *  
 * @return Mapping of group data to be saved.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see restore_groups
 */
final mapping retrieve_groups()
{
    if ( CALLER != _Database )
	THROW("Invalid call to retrieve_groups()", E_ACCESS);
    array groups= ({ });
    foreach(aGroups, object g) 
	groups += ({ g->oSteamObj });

    return ([ "groups": groups, ]);
}

/**
 * Register a new group.
 *  
 * @param object grp - the new group to register.
 * @param string|void name - optional name for the group.
 * @return newly created Group class for the given group.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object register_group(object grp, string|void name)
{
    if ( !_Server->is_a_factory(CALLER) )
	return 0;
    object group = Group(grp, name);
    aGroups += ({ group });
    require_save();
    return group;
}

/**
 * List the registered groups.
 *  
 * @return array of registered Groups.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array(Group) list_groups() 
{
    return aGroups;
}

/**
 * Get a certain group identified by 'id'.
 *  
 * @param string id - the id of the group to get.
 * @return the Group or 0.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
Group get_group(string id) 
{
    NNTP_LOG("get_group("+id+")");
    foreach(aGroups, object grp) {
	if ( grp->get_name() == id )
	    return grp;
    }
    return 0;
}

/**
 * Get a mapping of article headers for an article with 'content'.
 *  
 * @param string content - the content of the NNTP article.
 * @return mapping of headers.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mapping article_header(string content)
{
    string      header;
    mapping header_map;

    // dont know whats this ????!!!!
    int i = search(content, HEADER_SEP_RCV+HEADER_SEP_RCV);
    header = content[..i-1];
    array(string) settings = header / (HEADER_SEP_RCV);
    header_map = ([ ]);
    foreach(settings, string setting ) {
	string key, val;
	sscanf(setting, "%s: %s", key, val);
	header_map[lower_case(key)] = val;
    }
    NNTP_LOG("Header-Map="+sprintf("%O",header_map));
    return header_map;
}

/**
 * Find all group in a string 'id' separated by ','. This subsequently calls
 * get_group for each group found in 'id'.
 *  
 * @param string id - groups id string.
 * @return array(object) of found groups.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_group
 */
array(object) find_groups(string id)
{
    array(string) grps = id / ",";
    array(object) groups = ({ });
    if ( !arrayp(grps) )
	grps = ({ id });

    NNTP_LOG("find_groups("+id+")");
    
    foreach(grps, string grp) {
	groups += ({ get_group(grp) });
    }
    return groups;
}

/**
 * Get the body text of an article which means the
 * separator is found and the rest of the articles content returned.
 *  
 * @param string content - the content of the article.
 * @return the body.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see article_header
 */
string get_body(string content)
{
    int i = search(content, HEADER_SEP_RCV+HEADER_SEP_RCV);
    string body = content[i+2..];
    return body;
}

/**
 * Post an article with content. This will parse the header information
 * and create an appropriate object inside sTeam.
 *  
 * @param string content - the posted article.
 * @return -1 no posting allowed, 0 posting failed, 1 success
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int post_article(string content) 
{
    LOG("New article :\n"+content);
    mapping header = article_header(content);
    object factory = _Server->get_factory(CLASS_DOCUMENT);
    object group;

    bool post = false;
    array(object) groups = find_groups(header["newsgroups"]);
    foreach ( groups, group ) {
	LOG("Checking group: " + group->get_name() + " for posting...");
	if ( group->can_post() ) {
	    LOG("Posting allowed...");
	    post = true;
	}
    }
    if ( post == false )
	return -1;



    string mimetype = header["content-type"];
    if ( !stringp(mimetype) ) 
	mimetype = "text/html";
    
    sscanf(mimetype, "%s;%*s", mimetype);
    object article = factory->execute( ([ "name": header["subject"],
					"mimetype": mimetype, ]));
    article->set_content(get_body(content));
    mixed err = catch {
	foreach(groups, group) {
	    LOG("Adding annotation on group...\n");
	    groups->add_article(article->this(), header["references"]);
	}
    };
    if ( err != 0 ) {
	if ( arrayp(err) && sizeof(err) == 3 && err[2] == E_ACCESS )
	    return -1;
	else
	    throw(err);
	return 0;
    }
    return 1;
}


string get_identifier() { return "nntp"; }

