/* BUGS/PROBLEMS
 * - PUT method does not return correct response (at least on IE)
 * - IE asks for overwritting existing file even if file is not present
 * - COPY not implemented in existing filesystems yet
 */

inherit "http";

import webdavlib;

#include <macros.h>

#ifdef WEBDAV_DEBUG
#define DAV_WERR(s) werror((s)+"\n")
#else
#define DAV_WERR(s) 
#endif


static object __webdavHandler;

mapping handle_OPTIONS(object obj, mapping variables)
{	
    mapping result = ::handle_OPTIONS(obj, variables);
    result->extra_heads += ([ 
	"MS-Author-Via": "DAV",
	"DAV": "1", ]);
	
    return result;
}


mapping|void handle_MOVE(object obj, mapping variables)
{
    string destination = __request->request_headers->destination;
    string overwrite   = __request->request_headers->overwrite;

    if ( !stringp(overwrite) )
	overwrite = "T";
    __request->misc->overwrite = overwrite;
    __request->misc->destination = resolve_destination(
	destination,  __request->request_headers->host);

    // create copy variables before calling filesystem module
    if ( mappingp(__request->misc->destination) )
	return __request->misc->destination;
    else if ( stringp(__request->misc->destination) )
	__request->misc["new-uri"] = __request->misc->destination;
    DAV_WERR("Handling move:misc=\n"+sprintf("%O\n", misc));
    
    mapping res = ([ ]); // http should know about handle_MOVE handle_http();
    if ( mappingp(res) && res->error == 200 )
	return low_answer(201, "Created");
    return res;
}

mapping|void handle_MKCOL(object obj, mapping variables)
{
    mapping result = ::handle_MKDIR(obj, variables);
    if ( mappingp(result) && (result->error == 200 || !result->error) )
	return low_answer(201, "Created");
    return result;
}

mapping|void handle_COPY(object obj, mapping variables)
{
    string destination = __request->request_headers->destination;
    string overwrite   = __request->request_headers->overwrite;
    string dest_host;

    if ( !stringp(overwrite) )
	overwrite = "T";
    __request->misc->overwrite = overwrite;
    __request->misc->destination = resolve_destination(
	destination, __request->request_headers->host);
    if ( mappingp(__request->misc->destination) )
	return __request->misc->destination;

    mixed result =  ([ ]); // shoulw now how to copy handle_http();
    if ( mappingp(result) && result->error == 200 ) {
	return low_answer(201, "Created");
    }
    return result;
}

mapping|void handle_PROPPATCH(object obj, mapping variables)
{
    return proppatch(__request->not_query, __request->request_headers,
		     __request->body_raw, __webdavHandler);
}

mapping|void handle_PROPFIND(object obj, mapping variables)
{
    return propfind(_fp->object_to_filename(obj), __request->request_headers, 
		    __request->body_raw, __webdavHandler);
}    

static mapping call_command(string cmd, object obj, mapping variables)
{
    mapping result = ([ ]);

    // overwritten - must not forward requests without trailing /

    function call = this_object()["handle_"+cmd];
    if ( functionp(call) ) {
#ifdef DEBUG_MEMORY
        mapping dmap = Debug.memory_usage();
#endif
	result = call(obj, variables);
#ifdef DEBUG_MEMORY
	_Server->debug_out(dmap);
#endif

    }
    else {
	result->error = 501;
	result->data = "Not implemented";
    }
    return result;
}

void create(object fp, bool admin_port)
{
    ::create(fp, admin_port);
    __webdavHandler = WebdavHandler();
    __webdavHandler->get_directory = fp->get_directory;
    __webdavHandler->stat_file = fp->stat_file;
}

void respond(object req, mapping result)
{
    if ( stringp(result->data) )
	result->length = strlen(result->data);
    ::respond(req, result);
}
