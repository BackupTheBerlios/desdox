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
inherit "binary";
inherit "login";

#include <attributes.h>
#include <coal.h>
#include <assert.h>
#include <macros.h>
#include <events.h>
#include <functions.h>
#include <attributes.h>
#include <classes.h>
#include <database.h>
#include <config.h>
#include <client.h>

//#define DEBUG_PROTOCOL

#ifdef DEBUG_PROTOCOL
#define PROTO_LOG(s) werror(s+"\n")
#else
#define PROTO_LOG(s) 
#endif

void send_message(string str);
void close_connection();
void register_send_function(function f, function e);
void set_id(int i);

static mapping        mCommandServer;
static int                 iTransfer;
static int             iTransferSize;
static function              fUpload;
static object         encryptRSA = 0;
static object         decryptRSA = 0;
static string     decryptBuffer = "";


// log
static array   functionCalls;
static int|object      doLog;

/**
 * COAL_event is not used at all since there are usually
 * no events coming from a client.
 *  
 * @param int t_id - the transaction id
 * @param object obj - the context object
 * @param mixed args - parameter array
 * @return ok or failed
 * @author Thomas Bopp 
 */
int
COAL_event(int t_id, object obj, mixed args)
{
    return _COAL_OK;
}

/**
 * COAL_command: Call a function inside steam. The args are
 * an array with one or two parameters. The first on is the function
 * to call and the second one is an array again containing all the
 * parameters to be passed to the function call.
 *  
 * @param int t_id - the transaction id
 * @param object obj - the context object
 * @param mixed args - parameter array
 * @return ok or failed
 * @author Thomas Bopp 
 */
int
COAL_command(int t_id, object obj, mixed args)
{
    int     i, cmd;
    function     f;
    mixed      res;
    array(int)  argtypes;
    
    if ( !objectp(obj) ) return E_NOTEXIST | E_OBJECT;

    if ( sizeof(args) >= 2 )
	[ cmd, args ] = args;
    else {
	PROTO_LOG("1 Arg:"+(arrayp(args) ?"array":"no array"));
	cmd = args[0];
	args = ({ });
    }
    PROTO_LOG("Functioncall of " + cmd + " OBJ="+obj->get_object_id());
    if ( _SECURITY->valid_proxy(obj) )
	obj = obj->get_object();
    f = obj[cmd];

    if ( !functionp(f) )
	THROW("Function: " + cmd + " not found inside ("+obj->get_object_id()+
	      ")", E_FUNCTION|E_NOTEXIST);
    
    if ( !arrayp(args) ) args = ({ args });
    
    int oid, oclass;
    oid = obj->get_object_id();
    oclass = obj->get_object_class();

    string fname = obj->get_identifier();
    float t = gauge {
	res = f(@args);
    };
    PROTO_LOG("Functioncall of " + cmd + " on " + fname+"("+oid+")"+
	" took " + t + " seconds...");
    oUser->command_done(time());
    t = gauge {
	SEND_COAL(t_id, COAL_COMMAND, oid, oclass, res);
    };
    PROTO_LOG("Composing response takes " + t + " seconds...");
    if ( doLog && (intp(doLog) || (objectp(doLog) && doLog == obj)) )
    {
	mapping fcall = ([
			  "function": cmd,
			  "object": obj,
			  "class": oclass,
			  "time": t,
			  "args": args,
			  "result": res, ]);
	functionCalls += ({ fcall });
    }

    return _COAL_OK;
}

/**
 * COAL_query_commands: returns a list of callable commands of the 
 * given object.
 *  
 * @param int t_id - the transaction id
 * @param object obj - the context object
 * @param mixed args - parameter array
 * @return ok or failed
 * @author Thomas Bopp 
 * @see 
 */
int 
COAL_query_commands(int t_id, object obj, mixed args)
{
    mapping cmdMap;

    if ( !objectp(obj) )
	return E_NOTEXIST | E_OBJECT; 
    cmdMap = get_functions(obj);
    
    SEND_COAL(t_id, COAL_QUERY_COMMANDS, obj->get_object_id(),
	      obj->get_object_class(), ({ cmdMap }));
    return _COAL_OK;
}

/**
 * Set the client features of this connection.
 *  
 * @param int t_id - the transaction id
 * @param object obj - the context object
 * @param mixed args - parameter array
 * @return ok or failed.
 * @author Thomas Bopp (astra@upb.de) 
 */
int 
COAL_set_client(int t_id, object obj, mixed args)
{
    if ( sizeof(args) != 1 || !intp(args[0]) )
	return E_FORMAT | E_TYPE;
    iClientFeatures = args[0];
    SEND_COAL(t_id, COAL_SET_CLIENT, 0, 0, ({ }));
    return _COAL_OK;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int COAL_ping(int t_id, object obj, mixed args)
{
    SEND_COAL(t_id, COAL_PONG, 0, 0, ({ }));
    return _COAL_OK;
}

int COAL_pong(int t_id, object obj, mixed args)
{
    // clients are not supposed to send pongs
}

/**
 * Login the server with name and password. Optional the parameters client-name
 * and features can be used to login. If no features and name is given the
 * server will use "steam" and all client features. Otherwise the file client.h
 * describes all possible features. Right now only CLIENT_FEATURES_EVENTS 
 * (enables the socket to get events) and CLIENT_FEATURES_MOVE (moves the
 * user to his workroom when disconnecting and back to the last logout place
 * when connecting). Apart from that the features can be checked at the user
 * object by calling the function get_status(). It will return a bit vector
 * of all set features. This enables clients to check if a user hears a chat
 * for example.
 *
 * @param t_id - id of the transfer
 * @param obj_id - the relevant object
 * @param args - the arguments, { user, password } optional two other 
 *               parameters could be used: { user, password, client-name,
 *               client-features }
 * @return ok or error code
 * @author Thomas Bopp 
 * @see COAL_logout
 * @see database.lookup_user
 */
int 
COAL_login(int t_id, object obj, mixed args)
{
    object            uid;
    string u_name, u_pass;
    object         server;
    int        last_login;
    string         client;

    if ( sizeof(args) < 2 || !stringp(args[0]) || !stringp(args[1]) )
	return E_FORMAT | E_TYPE;
    
    u_name = args[0]; /* first argument is the username */
    u_pass = args[1];
    PROTO_LOG("login("+u_name+")");
    sClientClass = CLIENT_CLASS_STEAM;
    if ( sizeof(args) > 3 ) {
	sClientClass = args[2];
	if ( !intp(args[3]) )
	    THROW("Third argument is not an integer", E_TYPE);
	iClientFeatures = args[3];
    }
    else
	iClientFeatures = CLIENT_STATUS_CONNECTED;

    if ( sizeof(args) == 5 )
      set_id(args[4]);
    
    uid = MODULE_USERS->lookup(u_name);
    
    if ( !objectp(uid) )
	return E_OBJECT | E_NOTEXIST;

    if ( !uid->check_user_password(u_pass) ) 
	return E_ACCESS | E_PASSWORD;
    
    // allready connected to user - relogin
    logout_user();


    last_login = login_user(uid);

    server = master()->get_server();

    PROTO_LOG("Login successfull !");

    send_message( coal_compose(t_id, COAL_LOGIN, uid->get_object_id(),
			       uid->get_object_class(),
			       ({ u_name, server->get_version(), 
				      server->get_last_reboot(),
				      last_login,
				      version(), _Database,
				      MODULE_OBJECTS->lookup("rootroom"),
				      MODULE_GROUPS->lookup("sTeam"),
				      _Server->get_modules(),
				      _Server->get_classes(),
				      _Server->get_configs(),
				      })) );
    return _COAL_OK;
}

/**
 * called when logging out
 *  
 * @param t_id - the current transaction id
 * @param obj - the relevant object (not used in this case)
 * @return ok - works all the time
 * @author Thomas Bopp 
 * @see COAL_login
 */
int
COAL_logout(int t_id, object obj, mixed args)
{
    PROTO_LOG("Logging out...\n");
    close_connection();
    logout_user();
    return _COAL_OK;
}

/**
 * COAL_file_download
 *  
 * @param t_id - the transaction id of the command
 * @param obj - the relevant object
 * @param args - arguments for the download (ignored)
 * @return error code or ok
 * @author Thomas Bopp 
 * @see 
 */
int
COAL_file_download(int t_id, object obj, mixed args)
{
    function send;
    string   type;

    if ( !objectp(obj) )
	return E_NOTEXIST | E_OBJECT;
    else if ( obj->get_content_size() == 0 ) {
      SEND_COAL(t_id, COAL_FILE_UPLOAD, obj->get_object_id(),
		obj->get_object_class(), ({ obj->get_content_size() }));
      return _COAL_OK;
    }
	    
    
    if ( !arrayp(args) )
	args = ({ });

    type = obj->query_attribute(DOC_MIME_TYPE);
    PROTO_LOG("mime:"+type);
    if ( (sizeof(args) != 2 || type == "text/html" || 
	  type == "text/xml" || type=="source/pike") )
    {
        obj = obj->get_object();

	if ( !functionp(obj->get_content_callback) ) {
            object index;
            if ( obj->get_object_class() & CLASS_CONTAINER ) {

                index = obj->get_object_byname("index.html");
                if ( !objectp(index) ) 
		    index = obj->get_object_byname("index.htm");
                if ( !objectp(index) ) 
		    index = obj->get_object_byname("index.xml");
            }
	    if ( !objectp(index) )
	        return E_ERROR;
            obj = index->get_object();
        }
	
	if ( sizeof(args) == 0 )
	    send = obj->get_content_callback( ([ ]) );
	else
	    send = obj->get_content_callback(args[0]);
	
	PROTO_LOG("Now acknowledging download !");
	SEND_COAL(t_id, COAL_FILE_UPLOAD, obj->get_object_id(),
		  obj->get_object_class(), ({ obj->get_content_size() }));
	type = "";

	iTransfer = COAL_TRANSFER_SEND;
	register_send_function(send, download_finished);
	return _COAL_OK;

    }
    SEND_COAL(t_id, COAL_FILE_UPLOAD, obj->get_object_id(),
	      obj->get_object_class(), 
	      ({ obj->get_content_size(), _Server->get_database(),
		     obj->get_content_id() }));
    return _COAL_OK;
}

static void receive_message(string str) { } 

/**
 * download finished will set the mode back to no-transfer
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see COAL_file_download
 */
private void download_finished()
{
    PROTO_LOG("transfer finished...");
    iTransfer = COAL_TRANSFER_NONE;
    receive_message("");
}

/**
 * COAL_file_upload
 *  
 * @param t_id - the transaction id of the command
 * @param obj - the relevant object
 * @param args - arguments for the upload (1 arg, url and size)
 * @return error code or ok
 * @author Thomas Bopp 
 * @see COAL_file_download
 */
int
COAL_file_upload(int t_id, object obj, mixed args)
{
    string        url;
    int          size;
    object   path = 0;

    /* 
     * find the object or create it... 
     */
    if ( !arrayp(args) || 
	 (sizeof(args) != 1 && sizeof(args) != 2 && sizeof(args) != 3) )
    { 
	return E_FORMAT | E_TYPE;
    }
    switch ( sizeof(args) ) {
    case 3:
	[ path, url, size ] = args;
	break;
    case 2:
        [url, size] = args;
	break;
    case 1:
        [ url ] = args;
        size = -1;
    }
    
    if ( objectp(path) ) {
	obj = _FILEPATH->resolve_path(path, url);
    }
    else {
	obj = _FILEPATH->path_to_object(url);
    }
    if ( !objectp(obj) ) {
	object factory, cont;

	factory = _Server->get_factory(CLASS_DOCUMENT);
	cont = _FILEPATH->path_to_environment(url);
	obj = factory->execute((["url":url,]));
	if ( objectp(path) )
	    obj->move(path);
	PROTO_LOG("object created="+master()->stupid_describe(obj,255));
    }
    else 
	PROTO_LOG("found object.="+master()->stupid_describe(obj,255));
    
    if ( !functionp(obj->receive_content) )
	return E_NOTEXIST | E_OBJECT;
    PROTO_LOG("sending ok...");
    SEND_COAL(t_id, COAL_FILE_DOWNLOAD, 0, 0, ({ obj }));
    iTransfer = COAL_TRANSFER_RCV;
    iTransferSize = size;
    fUpload = obj->receive_content(size);
    obj->set_attribute(DOC_LAST_ACCESSED, time());
    obj->set_attribute(DOC_LAST_MODIFIED, time());
    return _COAL_OK;
}

/**
 * COAL_upload_start - start an upload and
 * call upload_package subsequently.
 *  
 * @param t_id - the transaction id of the command
 * @param obj - the relevant object
 * @param args - arguments for the upload (1 arg, url and size)
 * @return error code or ok
 * @author Thomas Bopp 
 * @see COAL_file_download
 */
int
COAL_upload_start(int t_id, object obj, mixed args)
{
    string|object url;
    int          size;
    /* find the object or create it... */
    
    if ( !arrayp(args) || sizeof(args) != 1 ) 
	return E_FORMAT | E_TYPE;
    size    = 0;
    [ url ] = args;
    
    if ( objectp(url) ) 
	obj = url;
    else
	obj = _FILEPATH->path_to_object(url);

    if ( !objectp(obj) ) {
	object factory, cont;

	factory = _Server->get_factory(CLASS_DOCUMENT);
	if ( !objectp(factory) ) LOG("Unable to find document factory !\n");
	cont = _FILEPATH->path_to_environment(url);
	obj = factory->execute((["url":url,]));
	PROTO_LOG("object created="+master()->stupid_describe(obj,255));
    }
    else 
	PROTO_LOG("found object.="+master()->stupid_describe(obj,255));
    
    if ( !functionp(obj->receive_content) )
	return E_NOTEXIST | E_OBJECT;
    SEND_COAL(t_id, COAL_FILE_DOWNLOAD, 0, 0, ({ obj }) );
    iTransfer = 0; 
    // only set upload function, but dont set transfer mode,
    // this means the protocoll is not blocking anymore !
    fUpload = obj->receive_content(size);
    PROTO_LOG("fUpload="+(functionp(fUpload) ? "function":"void"));
    obj->set_attribute(DOC_LAST_ACCESSED, time());
    obj->set_attribute(DOC_LAST_MODIFIED, time());
    return _COAL_OK;
}

/**
 * Upload a package to steam. Before this command can be used
 * there has to be a call to upload start before to define
 * a callback function receiving the data.
 *  
 * @param t_id - the transaction id of the command.
 * @param obj - the relevant object.
 * @param args - arguments for the query containing the content.
 * @return ok or failed.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int COAL_upload_package(int t_id, object obj, mixed args)
{
    if ( !functionp(fUpload) ) 
	THROW("No upload function - start upload with COAL_UPLOAD_START !",
	      E_ERROR);
    PROTO_LOG("uploading...");
    if ( sizeof(args) != 1 )
	return E_FORMAT | E_TYPE;
    PROTO_LOG("upload_package()");
    if ( !stringp(args[0]) || args[0] == 0 ) {
	fUpload(0);
	fUpload = 0;
	MESSAGE("Finished upload !\n");
        // at this point send back that we are finished, so client can logout
	SEND_COAL(t_id, COAL_UPLOAD_FINISHED, 0, 0, ({ obj })); 
	return _COAL_OK;
    }
    PROTO_LOG("Received package: " + strlen(args[0]));
    fUpload(args[0]);
    return _COAL_OK;
}


/**
 * get the inherit structure and function list of the server
 *  
 * @param t_id - the transaction id of the command
 * @param obj - the relevant object
 * @param args - arguments for the query (ignored)
 * @return error code or ok
 */
int
COAL_query_programs(int t_id, object obj, mixed args)
{
    array(program) programs;
    mapping               m;

    if ( !objectp(obj) )
	return E_NOTEXIST|E_OBJECT;

    m = ([ ]);
    programs = master()->get_programs();
    foreach(programs, program prg) {
	m[prg] = ({ get_local_functions(prg), Program.inherit_list(prg) });
    }
    
    SEND_COAL(t_id, COAL_QUERY_PROGRAMS, obj->get_object_id(),
	      obj->get_object_class(), ({ m }));
}

int COAL_log(int t_id, object obj, mixed args)
{
    if ( sizeof(args) != 1 )
	return E_FORMAT | E_TYPE;

    doLog = args[0];
    functionCalls = ({ });
    SEND_COAL(t_id, COAL_LOG, 0, 0, ({  }));
}

int COAL_retr_log(int t_id, object obj, mixed args)
{
    SEND_COAL(t_id, COAL_RETR_LOG, obj->get_object_id(),
	      obj->get_object_class(), ({ functionCalls }));
}

array get_function_calls()
{
    return functionCalls; 
}


/**
 * Initialize the protocoll.
 */
void
init_protocoll()
{
    mCommandServer = ([
	COAL_EVENT:   COAL_event,
	COAL_COMMAND: COAL_command,
	COAL_QUERY_COMMANDS: COAL_query_commands,
	COAL_LOGIN: COAL_login,
	COAL_LOGOUT: COAL_logout,
	COAL_FILE_UPLOAD: COAL_file_upload,
	COAL_FILE_DOWNLOAD: COAL_file_download,
	COAL_QUERY_PROGRAMS: COAL_query_programs,
	COAL_SET_CLIENT: COAL_set_client,
	COAL_UPLOAD_PACKAGE: COAL_upload_package,
	COAL_UPLOAD_START: COAL_upload_start,
	COAL_PING: COAL_ping,
	COAL_PONG: COAL_pong,
	COAL_LOG: COAL_log,
	COAL_RETR_LOG: COAL_retr_log,
	]);
}


/**
 * notify the client about an event in the user object
 *  
 * @param event - the current event
 * @param args - list of parameters for the event
 * @author Thomas Bopp (astra@upb.de) 
 * @see base.events.add_event
 */
nomask void
notify(int event, mixed ... args)
{
    object target;

    if ( !is_user_object(CALLER) )
	return;
    target = args[0];
    SEND_COAL(time(), COAL_EVENT, target->get_object_id(),
	      target->get_object_class(),
	      ({ event, args[1..] }));
}

/**
 * send a message to the client - this function can only be called
 * by the connected user-object
 *  
 * @param tid - transaction id
 * @param cmd - the command
 * @param obj - the relevant object
 * @param args - the arguments for the command
 * @author Thomas Bopp (astra@upb.de) 
 * @see coal_compose
 */
nomask void
send_client_message(int tid, int cmd, object obj, mixed ... args)
{
    if ( !is_user_object(CALLER) )
	return;
    if ( tid == USE_LAST_TID )
	tid = iLastTID;
    SEND_COAL(tid, cmd, obj->get_object_id(), obj->get_object_class(), args);
}

/**
 * Compose a coal command by passing a number of parameters.
 *  
 * @param int t_id - the transaction id
 * @param int cmd - the coal command to call
 * @param int o_id - the object id of the context object
 * @param int class_id - the class of the context object
 * @param mixed args - the parameters
 * @return composed string
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string coal_compose(int t_id, int cmd, int o_id, int class_id, mixed args)
{
    string res = ::coal_compose(t_id, cmd, o_id, class_id, args);
    if ( objectp(encryptRSA) ) {
	LOG("Encryption block_size="+CRYPT_WSIZE);
	LOG("Uncrypted package to send:\n"+res);
	int l = strlen(res);
	int i = 0;
	string nmsg = "";
	while ( i < l ) {
	    if ( i + CRYPT_WSIZE > l )
		nmsg += encryptRSA->encrypt(res[i..]);
	    else
		nmsg += encryptRSA->encrypt(res[i..i+CRYPT_WSIZE-1]);
	    i+=CRYPT_WSIZE;
	}
	res = nmsg;
    }
    return res;
}
