inherit "base/ftp";
inherit "coal/login";

#include <classes.h>
#include <attributes.h>
#include <macros.h>

#define DEBUG_FTP

#ifdef DEBUG_FTP
#define FTP_DEBUG(s) werror(s+"\n")
#else
#define FTP_DEBUG(s)
#endif

int received = 0;
int hsent = 0;
mapping options;
int sessions = 0;
int ftp_users = 0;
int requests = 0;
static object _fp; // filpath module


void create(object f)
{
    _fp = get_module("filepath:tree");
    options = ([ 
	"FTPWelcome":"Welcome to sTeam ftp server.\n",
	"passive_port_min": 60000,
	"passive_port_max": 65000,
	]);
    ::create(f, this_object());
}

void log(mixed f, mixed session) 
{
    //werror("LOG:\n"+sprintf("%O\n",f));
}


mixed stat_file(string file, mixed session) 
{
    return _fp->stat_file(file);
}

mixed find_dir_stat(string dir, mixed session) 
{
    return _fp->query_directory(dir);
}

mixed find_dir(string dir, object session) 
{
    return _fp->get_directory(dir);
}

string type_from_filename(string filename)
{
    string ext;
    sscanf(basename(filename), "%*s.%s", ext);
    return get_module("types")->query_mime_type(ext);
}

void done_with_put( array(object) id )
{
  id[0]->close();
  id[1]->done( ([ "error":226, "rettext":"Transfer finished", ]) );
  destruct(id[0]);
}

void got_put_data( array (object) id, string data )
{
  id[0]->write( data );
}

mixed get_file(string fname, mixed session) 
{
    mixed  err;
    object doc;
    object obj = _fp->path_to_object(fname);

    FTP_DEBUG(session->method + " " + fname);
    
    switch ( session->method ) {
    case "GET":
	doc = ((program)"/kernel/DocFile.pike")(obj);
	return ([ "file": doc, "len":obj->get_content_size(), "error":200, ]);
    case "PUT":
        int setuser = 0;
        // passive or active ftp?
        if ( !objectp(this_user()) )
	  setuser = 1;
	if ( setuser )
	  set_this_user(this_object());
	
	object document = _fp->path_to_object(fname);
	if ( !objectp(document) )
	    document = get_factory(CLASS_DOCUMENT)->execute((["url":fname,]));
	doc = ((program)"/kernel/DocFile.pike")(document, "wct");
	werror("Stats="+sprintf("%O\n",doc->stat()));
	session->my_fd->set_id( ({ doc, session->my_fd }) );
	session->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
	if ( setuser )
	  set_this_user(0);
	return ([ "file": doc, "pipe": -1, "error":0,]);
    case "MV":
	doc = _fp->path_to_object(session->misc->move_from);
	string name = basename(fname);
	string dir = dirname(fname);
        object cont = _fp->path_to_object(dir);
	if ( objectp(cont) )
	    doc->move(cont);
	doc->set_attribute(OBJ_NAME, name);	
	return ([ "error": 200, "data": "Ok", ]);
    case "DELETE":
	if ( (obj->get_object_class() & CLASS_USER) || 
	     (obj->get_object_class() & CLASS_GROUP) )
	    return ([ "error":403, "data":"Permission denied." ]);
	
	if ( err = catch(obj->delete()) ) {
	    MESSAGE("ftp error:\n"+err[0] + "\n" + sprintf("%O\n", err[1]));
	    return ([ "error":403, "data":"Permission denied." ]);
	}
	
	return ([ "error":200, "data": fname + " DELETED." ]);
    case "MKDIR":
	string dirn = dirname(fname);
	string cname = basename(fname);
	_fp->make_directory(dirn, cname);
	return ([ "error":200, "data":"Ok.", ]);
    case "QUIT":
	MESSAGE("ftp: quitting...");
    }
}

object authenticate(mixed session) 
{
    object u = get_module("users")->lookup(session->misc->user);
    if ( objectp(u) ) {
	if ( u->check_user_password(session->misc->password) ) {
	    login_user(u);
	    return u;
	}
    }
    return 0;
}

mixed query_option(mixed opt) 
{
    return options[opt];
}    

void ftp_logout()
{
    oUser->disconnect();
    ::ftp_logout();
}

string describe()
{
    return "FTP()";
}


