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
inherit "coal/login";

#include <macros.h>
#include <database.h>
#include <classes.h>
#include <attributes.h>
#include <access.h>
#include <roles.h>
#include <config.h>
#include <client.h>

import httplib;

#define DEBUG_HTTP 1

#ifdef DEBUG_HTTP
#define HTTP_DEBUG(s, args...) werror( s+"\n", args)
#else
#define HTTP_DEBUG(s)
#endif

object                    _fp;
static object      __notfound;
static int         __finished;
static bool      __admin_port;
static object       __request; // the saved request object

static int           __toread; // how many bytes to go to read body
static string          __body; // the request body
static object        __upload;
static object         __tasks;

constant automatic_tasks = ({ "create_group_exit", "remove_group_exit" });

void create(object fp, bool admin_port)
{
    _fp = fp;
    __finished = 0;
    __admin_port = admin_port;
    __tasks = _Server->get_module("tasks");
}

/**
 * authenticate with server. Normal http authentication
 *  
 * @param string basic - the auth in base64 encoding
 * @return nothing, will log in, or might throw an error
 */
void authenticate(string basic)
{
    string auth, user, pass;
    object userobj;
    
    if ( stringp(basic) ) {
       
	if ( sscanf(basic, "Basic %s", auth) == 0 )
	    sscanf(basic, "basic %s", auth);
	
	auth = MIME.decode_base64(auth);
	sscanf(auth, "%s:%s", user, pass);
	userobj = MODULE_USERS->lookup(user);
    }
    if ( objectp(userobj) ) {
	if ( userobj->check_user_password(pass) )
	    login_user(userobj);
	else
	    steam_error("Authentication failed.\n");
    }
    else if ( !__admin_port )
	login_user(_GUEST);
    else
	steam_error("Authentication failed - login required.\n");
}

/**
 * This thread is used for downloading stuff.
 *  
 * @param object req - the request object.
 * @param function dataf - the function to call to read data
 */
static void download_thread(object req, function dataf)
{
    string str;
    while ( stringp(str=dataf()) ) {
	int sz = strlen(str);
	int written = 0;
	while ( written < sz ) {
	    written += req->my_fd->write(str[written..]);
	}
    }
}


/**
 * Handle the GET method of the HTTP protocol
 *  
 * @param object obj - the object to get
 * @param mapping vars - the variable mapping
 * @return result mapping with data, type, length
 */
mapping handle_GET(object obj, mapping vars)
{
    mapping result = ([ ]);
    mapping  extra = ([ ]); // extra headers
    object    _obj =   obj; // if some script is used to display another object
    int           modified;

    get_module("log")->add_request();

    // the variable object is default for all requests send to sTeam
    // whenever some script is executed, object defines the sTeam object
    // actually requested.
    if ( !objectp(obj) ) 
	return response_notfound(__request->not_query, vars);
    if ( vars->object ) 
	_obj = find_object((int)vars->object);
    if ( !objectp(_obj) ) 
	return response_notfound(vars->object, vars);

    // handle if-modified-since header as defined in HTTP/1.1 RFC
    // instead of any script called the actually referred object (vars->object)
    // is used here for DOC_LAST_MODIFIED
    string mod_since = vars->__internal->request_headers["if-modified-since"];
    modified = _obj->query_attribute(DOC_LAST_MODIFIED);
    if ( _obj->get_object_class() & CLASS_DOCUMENT && 
	 !is_modified(mod_since, modified, _obj->get_content_size()) )
    {
	HTTP_DEBUG("Not modified.");
	return ([ "error":304, "data":"not modified", ]);
    }
    

    // the type variable is crucial for steam, since
    // it defines how the object is displayed.
    // the content type is the default and also
    // means objects are downloaded instead of displayed by show_object()
    if ( !stringp(vars->type) || vars->type == "" ) {
	if ( obj->get_object_class() & CLASS_MESSAGEBOARD )
	    vars->type = "annotations";
	else
	    vars->type = "content";
    }

    if ( obj->get_object_class() & CLASS_SCRIPT ) 
    {
	result = handle_POST(obj, vars);
    }
    else if ( obj->get_object_class() & CLASS_DOCXML ) {
	string xml = obj->get_content();
	object xsl = obj->get_stylesheet();
	if ( objectp(xsl) && !stringp(vars->source) ) {
	    result->data = run_xml(xml, xsl, vars);
	    result->type = "text/"+xsl->get_method();
	}
	else {
	    result->data = xml;
	    result->type = "text/xml";
	}
    }
    else if ( vars->type == "content" &&
	      obj->get_object_class() & CLASS_DOCUMENT ) 
    {
	object xsl = obj->query_attribute("xsl:public");
	if ( objectp(xsl) && obj->query_attribute("xsl:use_public") ) 
	{
	    // if xsl:document is set for any document then
	    // instead of downloading the document, do an
	    // xml transformation.
	    // the xml code is generated depending on the stylesheet
	    // This is actually show_object() functionality, but
	    // with type content set.
	    result->data = run_xml(obj, xsl, vars);
	    if ( stringp(vars->source) )
		result->type = "text/xml";
	    else
		result->type = "text/"+xsl->get_method();
	}
	else {
	    // download documents, but only if type is set to content
	    // because we might want to look at the objects annotations
	    object doc = 
		((program)"/kernel/DocFile.pike")(obj, "r", vars, "http");
	    result->file = doc;
	    result->type = obj->query_attribute(DOC_MIME_TYPE);
	    modified = doc->stat()->mtime;
	    result->modified = modified;
	    get_module("log")->add_download(obj->get_content_size());
	}
    }
    else {
	vars->object = (string)obj->get_object_id();   
	mixed res = show_object(obj, vars);
	if ( mappingp(res) )
	    return res;
	
	result->data  = res;
	result->length = strlen(result->data);
	result->type = "text/html";
    }
    if ( stringp(result->type) ) {
	if( search(result->type, "image") >= 0 ||
	    search(result->type, "css") >= 0 ||
	    search(result->type, "javascript") >= 0 )
	    extra->Expires = http_date(60*60*24*365+time());
    }

    if ( !mappingp(result->extra_heads) )
	result->extra_heads = extra;
    else
	result->extra_heads |= extra;
    return result;
}

/**
 * handle the http POST method. Also it might be required to
 * read additional data from the fd.
 *  
 * @param object obj - script to post data to
 * @param mapping m - variables
 * @return result mapping
 */
mapping handle_POST(object obj, mapping m)
{
    mapping result = ([ ]);
    //HTTP_DEBUG("POST(%O)", m);
    // need to read the request yourself...
    if ( !objectp(obj) )
	return response_notfound(__request->not_query, m);

    get_module("log")->add_request();

    mixed res = obj->execute(m);
    if ( intp(res) ) {
	if ( res == -1 ) {
	    result->error = 401;
	    result->extra_heads = 
		([ "WWW-Authenticate": "basic realm=\"steam\"", ]);
	    return result;
	}
    }
    else if ( arrayp(res) ) {
	if ( sizeof(res) == 2 )
	    [ result->data, result->type ] = res;
	else
	    [ result->data, result->type, result->modified ] = res;
    }
    else {
	result->data = res;
	result->type = "text/html";
    }
    return result;
}

mapping handle_OPTIONS(object obj, mapping vars)
{
    string allow = "";
    mapping result = low_answer(200, "OK");
    
    
    foreach ( indices(this_object()), string ind) {
	string cmd_name;
	if ( sscanf(ind, "handle_%s", cmd_name) > 0 )
	    allow += cmd_name + ", ";
    }

    result->extra_heads = ([
	"Allow": allow, 
	]);
    return result;
}

mapping handle_PUT(object obj, mapping vars)
{
    if ( !objectp(obj) ) {
	string fname = __request->not_query;
	obj = get_factory(CLASS_DOCUMENT)->execute( ([ "url":fname, ]) );
    }
    // create Stdio.File wrapper class for a steam object
    __upload = ((program)"/kernel/DocFile")(obj, "wct");
    __toread = (int)__request->request_headers["content-length"];
    if ( strlen(__request->body_raw) > 0 ) {
	__toread -= strlen(__request->body_raw);
	__upload->write(__request->body_raw);
    }
    if ( __toread > 0 )
	__request->my_fd->set_nonblocking(read_put_data,0,finish_put);
    else {
	__upload->close();
	return low_answer(201, "created");
    }
    return 0;
}

static void read_put_data(mixed id, string data)
{
    __upload->write(data);
    __toread -= strlen(data);
    __request->my_fd->write("HTTP/1.1 100 Continue\r\n\r\n");
    if ( __toread <= 0 )
	finish_put(0);
}

static void finish_put(mixed id)
{
    __upload->close();
    __upload = 0;
    __finished = 1;
    __request->response_and_finish( low_answer(201, "created") );
}


mapping handle_MKDIR(object obj, mapping vars)
{
    string fname = __request->not_query;
    obj = _fp->make_directory(dirname(fname), basename(fname));
    if ( objectp(obj) )
	return low_answer(201, "Created.");
    return low_answer(403, "forbidden");
}

mapping handle_DELETE(object obj, mapping vars)
{
    if ( !objectp(obj) )
	return response_notfound(__request->not_query, vars);

    if ( catch(obj->delete()) )
	return low_answer(403, "forbidden");
    return low_answer(200, "Ok");
}


mapping handle_HEAD(object obj, mapping vars)
{
    if ( !objectp(obj) )
	return response_notfound(__request->not_query, vars);

    mapping result = low_answer(200, "Ok");
    result->type = obj->query_attribute(DOC_MIME_TYPE);
    result->modified = obj->query_attribute(DOC_LAST_MODIFIED);
    result->len = obj->get_content_size();
    return result;
}



/**
 * Read the body for a request. Usually the body is ignored, but
 * POST with multipart form data need the body for the request.
 *  
 * @param object req - the request object
 * @param int len - the length of the body (as set in request headers)
 * @return the parsed form data (variables set in a mapping) or 0
 */
mapping read_body(object req, int len)
{
    if ( len == 0 )
	return ([ ]);

    HTTP_DEBUG("trying to read length of body = %O", len);
    len -= strlen(req->body_raw);
    
    if ( req->request_type == "PUT" )
	return ([ ]);

    __toread = len;
    __body = "";
    if ( len > 0 ) 
	return 0;
    __body = req->body_raw;

    string content_type = req->request_headers["content-type"];

    if ( strlen(__body) == 0 || !stringp(content_type) )
	return ([ ]);
    if ( search(content_type, "multipart/form-data") >= 0 )
	return parse_multipart_form_data(req, __body);
    else if ( search(content_type, "xml") >= 0 )
	return ([ "__body": __body, ]);
    else
	return ([ ]);
}

/**
 * Read the body of a http request - if the POST sends
 * multipart/formdata, then the request is not read by 
 * Protocols.HTTP.Server.
 *  
 * @param mixed id - id object
 * @param string data - the body data
 */
void read_body_data(mixed id, string data)
{
    if ( stringp(data) ) {
	__body += data;
	__toread -= strlen(data);
	if ( __toread <= 0 ) {
	    __request->body_raw += __body;
	    __request->variables|=parse_multipart_form_data(
		__request,__request->body_raw);
	    __body = "";
	    http_request(__request);
	}
	else {
	    __request->my_fd->write("HTTP/1.1 100 Continue\r\n\r\n");
	}
    }
}

/**
 * Call a command in the server. Return the result of the call or
 * if no function was found 501.
 *  
 * @param string cmd - the request_type to call
 * @param object obj - the object
 * @param mapping variables - the variables
 * @return result mapping
 */
static mapping call_command(string cmd, object obj, mapping variables)
{
    mapping result = ([ ]);

    // redirect a request on a container or a room that does not
    // include the trailing /
    if ( objectp(obj) && obj->get_object_class() & CLASS_CONTAINER && 
	 __request->not_query[-1] != '/' )
    {
	// any container access without the trailing /
	result->data = redirect(
	    replace_uml(__request->not_query)+"/"+
	    (strlen(__request->query) > 0 ? "?"+ __request->query : ""),0);
	result->type = "text/html";
	return result;
    }
    werror("call_command("+cmd+")\n");
    function call = this_object()["handle_"+cmd];
    if ( functionp(call) ) {
	werror("Calling function....\n");
	result = call(obj, variables);
    }
    else {
	result->error = 501;
	result->data = "Not implemented";
    }
    return result;
}

/**
 * Handle a http request within steam.
 *  
 * @param object req - the request object
 */
mapping run_request(object req)
{
    mapping result = ([ ]);
    mixed              err;

    if ( catch(	authenticate(req->request_headers->authorization) ) )
    {
	result->extra_heads = 
	    ([ "WWW-Authenticate": "basic realm=\"steam\"", ]);
	result->error=401;
	return result;
    }


    //  find the requested object
    req->not_query = rewrite_url(req->not_query, req->request_headers);
    req->not_query = url_to_string(req->not_query);
    object obj = _fp->path_to_object(req->not_query);

    // make variable mapping compatible with old format used by caudium
    mapping m = req->variables;
    m->__internal = ([ "request_headers": req->request_headers, 
		     "client": ({ "Mozilla", }), ]);
    
    err = catch ( result = call_command(req->request_type, obj, m) );

    if ( err ) 
    {
      if ( arrayp(err) && sizeof(err) == 3 && (err[2] & E_ACCESS) ) {
	result = response_noaccess(obj, m);
      }
      else {
	// fixme! list backtraces appropriately
	result = response_error(obj, m, err);
      }
      MESSAGE(sprintf("error:\n%O\n%O\n", err[0], err[1]));
    }

    return result;
}

string rewrite_url(string url, mapping headers)
{
    if ( !stringp(headers->host) )
	return url;
    mapping virtual_hosts = _ADMIN->query_attribute("virtual_hosts");
    // virtual_hosts mapping is in the form
    // http://steam.uni-paderborn.de : /steam
    if ( mappingp(virtual_hosts) ) {
	foreach(indices(virtual_hosts), string host) 
	    if ( search(headers->host, host) >= 0 )
		return virtual_hosts[host] + "/" + url;
    }
    return url;
}




/**
 * A http request is incoming. Convert the req (Request) object
 * into a mapping.
 *  
 * @param object req - the incoming request.
 */
void http_request(object req)
{
    mapping result;
    int        len;

    __request = req;

    HTTP_DEBUG("HTTP: %O",req);


    // read body always...., if body is too large abort.
    len = (int)req->request_headers["content-length"];
#if 0
    if ( len > HTTP_MAX_BODY && req->request_type == "POST" ) {
	req->my_fd->set_blocking();
	HTTP_DEBUG("Body too large...");
	result = response_too_large_file(req);
	HTTP_DEBUG("Returning:%O", result));
	req->response_and_finish( result );    
	return;
    }
#endif
    mapping body_variables = read_body(req, len);
    
    // sometimes not the full body is read
    if ( !mappingp(body_variables) ) {
	// in this case we need to read the body
	req->my_fd->set_nonblocking(read_body_data,0,0);
	return;
    }
    req->my_fd->set_blocking();

    set_this_user(this_object());
	

    mixed err = catch {
	req->variables |= body_variables;
	result = run_request(req);
    };

    if ( err != 0 ) {
	MESSAGE(sprintf("Internal Server error.\n%O\n%O\n",err[0],err[1]));
	result = ([ "error":500, "data": "internal server error",
		  "type": "text/html", ]);
	if ( !objectp(get_module("package:web") ) && 
	     !objectp(OBJ("/stylesheets")) ) 
	{
	    result->data = "<html><body><h2>Welcome to sTeam</h2><br/>"+
		"Congratulations, you successfully installed a sTeam server!"+
		"<br/>To be able to get anything working on this "+
		"Web Port, <br/>you need to install the web Package.";
	}
    }
    set_this_user(0);

    // if zero is returned, then the http request object is 
    // still working on the request
    if ( mappingp(result) ) {
	// run rxml parsing/replacing when file extension is xhtm
	// ! fixme !! how to get the tags mapping ??
	if ( result->mimetype == "text/xhtml" )
	    result->data = rxml(result->data, req->variables, ([ ]) );

	respond( req, result );
	__finished = 1;
    }
}

/**
 * Get the appropriate stylesheet for a user to display obj.
 *  
 * @param object user - the active user
 * @param object obj - the object to show
 * @param mapping vars - variables.
 * @return the appropriate stylesheet to be used.
 */
object get_xsl_stylesheet(object user, object obj, mapping vars)
{
    mapping xslMap = obj->query_attribute("xsl:"+vars->type);
    object xsl;
    
    // for the presentation port the public stylesheets are used.
    if ( !__admin_port ) {
	xsl = obj->query_attribute("xsl:public");
	if ( !objectp(xsl) )
	    xsl = OBJ("/stylesheets/public.xsl");
	return xsl;
    }

    if ( !mappingp(xslMap) ) 
	xslMap = ([ ]);
    object aGroup = user->get_active_group();
    if ( stringp(vars["style"]) )
	xsl = _FILEPATH->path_to_object(vars["style"]);
    
    // select the apropriate stylesheet depending on the group
    if ( !objectp(xsl) ) {
	if ( objectp(xslMap[aGroup]) )
	    xsl = xslMap[aGroup];
	else {
	    object grp;

	    array(object) groups = user->get_groups();
	    for ( int i = 0; i < sizeof(groups); i++ )
		groups += groups[i]->get_groups();
	    
	    foreach( groups, grp ) {
		if ( objectp(xslMap[grp]) )
		    xsl = xslMap[grp];
	    }
	}
    }

    if ( !objectp(xsl) ) {
	if ( vars->type == "PDA:content" )
	    vars->type = "zaurus";
	xsl = _FILEPATH->path_to_object("/stylesheets/"+vars->type+".xsl");
    }
    return xsl;
}

/**
 * handle the tasks. Call the task module and try to run a task
 * if any none-automatic task is in the queue then display
 * a html page.
 *  
 * @param object user - the user to handle tasks for
 * @param mapping vars - the variables mapping
 * @return string|int result, 0 means no tasks
 */
string|int run_tasks(object user, mapping vars, mapping client_map)
{
    mixed tasks = __tasks->get_tasks(user);
    string                            html;
    int                           todo = 0;

    if ( arrayp(tasks) && sizeof(tasks) > 0 ) {
	if ( !stringp(vars["type"]) )
	    vars["type"] = "content";
	if ( !stringp(vars->object) )
	    vars->object = (string)user->query_attribute(USER_WORKROOM)->
		get_object_id();
	html = "<form action='/scripts/browser.pike'>"+
	    "<input type='hidden' name='_action' value='tasks'/>"+
	    "<input type='hidden' name='object' value='"+vars["object"]+"'/>"+
	    "<input type='hidden' name='id' value='"+vars["object"]+"'/>"+
	    "<input type='hidden' name='type' value='"+vars["type"]+"'/>"+
	    "<input type='hidden' name='room' value='"+vars["room"]+"'/>"+
	    "<input type='hidden' name='mode' value='"+vars["mode"]+"'/>"+
	    "<h3>Tasks:</h3><br/><br/>";
	
	foreach(tasks, object t) {
	    if ( search(automatic_tasks, t->func) == -1  ) {
		html += "<input type='checkbox' name='tasks' value='"+
		    t->tid+"' checked='true'/><SPAN CLASS='text0sc'> "+
		    t->descriptions[client_map["language"]] + 
		    "</SPAN><br/>\n";
		todo++;
	    }
	    else if ( t->obj == __tasks || t->obj == 
		      _FILEPATH->path_to_object("/scripts/browser.pike") ) 
	    {
		__tasks->run_task(t->tid); // risky ?
	    }
	}
	__tasks->tasks_done(user);
	html += "<br/><br/><input type='submit' value='ok'/></form>";
	if ( todo > 0 )
	    return html;
    }
    return 0;
}
    

/**
 * Show an object by doing the 'normal' xsl transformation with 
 * stylesheets. Note that the behaviour of this function depends
 * of the type of port used. There is the admin port and the presentation
 * port.
 *  
 * @param object obj - the object to display
 * @param mapping vars - variables mapping
 * @return string|mapping result of transformation
 */
string|int|mapping show_object(object obj, mapping vars)
{
    string html, xml;
    mixed        err;

    object user = this_user();

    if ( obj == _ROOTROOM && !_ADMIN->is_member(user) )
	return redirect("/home/"+user->get_user_name()+"/", 0);
    
    _SECURITY->check_access(obj, user, SANCTION_READ,ROLE_READ_ALL, false);

    mapping client_map = get_client_map(vars);
    if ( user != _GUEST ) {
      if ( !stringp(user->query_attribute(USER_LANGUAGE)) )
	user->set_attribute(USER_LANGUAGE, client_map->language);
    }

    string lang = client_map->language;
    // the standard presentation port shouild behave like a normal webserver
    // so, if present, index files are used instead of the container.
    if ( !__admin_port && obj->get_object_class() & CLASS_CONTAINER )
    {
      if ( obj->query_attribute("cont_type") == "multi_language" ) {
	    mapping index = obj->query_attribute("language_index");
	    if ( mappingp(index) ) {
	      object indexfile = obj->get_object_byname(index[lang]);
	      if ( !objectp(indexfile) )
		indexfile = obj->get_object_byname(index->default);
	      if ( objectp(indexfile) ) {
		// indexfile need to be in the container
		if ( indexfile->get_environment() == obj )
		  return handle_GET(indexfile, vars);    
	      }
	    }
	}
	object indexfile = obj->get_object_byname("index.html");
	if ( objectp(indexfile) )
	  return handle_GET(indexfile, vars);
    }
    
    if ( obj->get_object_class() & CLASS_ROOM ) {
	// check for move clients !
	if ( !(user->get_status() & CLIENT_FEATURES_MOVE) ) 
	    user->move(obj);
	else
	    user->add_trail(obj, 20);
	// possible move other users to their home area
	get_module("collect_users")->check_users_cleanup(obj->get_users());
    }

    if ( __admin_port ) {
	mixed result = run_tasks(user, vars, client_map);
	if ( stringp(result) )
	    return result_page(result, "no");
    }

    
    // PDA detection - use different stylesheet (xsl:PDA:content, etc)
    if ( client_map["xres"] == "240" ) 
	vars->type = "PDA:" + vars->type;

    vars |= client_map;

    object xsl = get_xsl_stylesheet(user, obj, vars);
    html = run_xml(obj, xsl, vars);
    
#if 0
    if ( !equal(xsl->get_tags(), ([ ])) )
	html = rxml(html, vars, xsl->get_tags());
#endif

    if ( vars->source == "true" )
	return ([ 
	    "data"   : html, 
	    "length" : strlen(html), 
	    "type"   : "text/xml", ]);
    
    return html;
}


mapping response_noaccess(object obj, mapping vars)
{
    mapping result;
    object noaccess = OBJ("/documents/access.xml");
    result = handle_GET(noaccess, vars);

    // on the admin port users are already logged in - so just show no access
    result->error = (__admin_port ? 200 : 
		     ( _Server->query_config("secure_credentials") ? 
		       200 : 401 ) );
    result->extra_heads = 
	([ "WWW-Authenticate": "basic realm=\"steam\"", ]);

    result->data = replace(result->data, ({ "{FILE}", "{USER}" }), 
			   ({ obj->get_identifier(), 
				  this_user()->get_identifier() }));
    return result;
}

mapping response_too_large_file(object req)
{
    string html = error_page(
	"The amount of form/document data you are trying to "+
	"submit is<br/>too large. Use the FTP Protocol to upload files "+
	"larger than 20 MB.");
    return ([ "data": html, "type":"text/html", "error":413, ]);
}

mapping response_notfound(string|int f, mapping vars)
{
    string html = "";
    object xsl, cont;

    HTTP_DEBUG("The object %O was not found on server.", f);

    if ( zero_type(f) )
	f = __request->not_query;
    
    xsl = OBJ("/stylesheets/notfound.xsl");

    if ( stringp(f) ) {
	string path = f;
	array tokens = path / "/";

	
	for ( int i = sizeof(tokens)-1; i >= 1; i-- )
	{
	    path = tokens[..i]*"/";
	    cont = _fp->path_to_object(path);
	    if ( objectp(cont) ) {
		catch(xsl = cont->query_attribute("xsl:notfound"));
	        if ( !objectp(xsl) )
		    xsl = OBJ("/stylesheets/notfound.xsl");
		break;
	    }
	}
    }
    else {
	f = "Object(#"+f+")";
    }
    if ( !objectp(cont) )
	cont = _ROOTROOM;

    string xml =  
	"<?xml version='1.0' encoding='iso-8859-1'?>\n"+
	"<error><actions/>"+
	"<message><![CDATA[The Document '"+f+"' was not found on the "+
	"Server.]]></message>\n"+
	"<orb>"+_fp->get_identifier()+"</orb>\n"+
	"<url>"+f+"</url>\n"+
	"<user>"+this_user()->get_identifier()+"</user>\n"+
	"<container>"+get_module("Converter:XML")->show(cont)+
	get_module("Converter:XML")->get_basic_access(cont)+
	"</container>\n"+
	"</error>";

    html = run_xml(xml, xsl, vars);
    html += "\n<!--"+xml+"-->\n";
    mapping result = ([
	"error":404,
	"data":html,
	"type":"text/html",
	]);
    return result;
}

mapping response_error(object obj, mapping vars, mixed err)
{
    string errStr = "<b>"+err[0]+"</b>";
    string xml, html;
   
    HTTP_DEBUG("err=%O\n", err);
    errStr += backtrace_html(err[1]);

    object xsl = OBJ("/stylesheets/errors.xsl");
    xml =  
	"<?xml version='1.0' encoding='iso-8859-1'?>\n"+
	"<error><actions/><message><![CDATA["+
	"<h2>Internal Server Error</h2><br/><br/>"+
	uml_to_html(err[0])+"<br/><br/>"+errStr+"]]></message></error>";
    html = run_xml(xml, xsl, vars);
    return ([ "data": html, "type": "text/html", "error": 500, ]);
}

static void respond(object req, mapping result)
{
    req->response_and_finish(result);
}



int is_closed() { return __finished; }
int get_client_features() { return 0; }
string get_client_class() { return "http"; }
string get_identifier() { return "http"; }
string describe() { return "HTTP-Request()"; }
object get_object() { return this_object(); }
object this() { return this_object(); }
