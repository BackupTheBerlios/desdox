import cert;

#include <macros.h>

static object _fp;
static bool admin_port = 0;
static program handler = ((program)"/net/http.pike");
static object httpPort;

void http_request(object req)
{
    // create request object
    object obj = get_socket_program()(_fp, admin_port);
    master()->register_user(obj);
    obj->http_request(req);
}

program get_socket_program() 
{
    return handler;
}


bool port_required() { return true; }

bool open_port()
{
    int port_nr = get_port();
    _fp = get_module("filepath:tree");
    admin_port = true;
    handler = ((program)"/net/webdav.pike");
    
    mapping certs = read_certificate("config/steam.cer");
    if ( catch(httpPort = Protocols.HTTP.Server.SSLPort(
	http_request, (int)port_nr,
	_Server->query_config("ip"), certs->key, certs->cert)) )
    {
	MESSAGE("Failed to bind HTTPS on port " + port_nr);
	return false;
    }
    
    _Server->set_config("web_port_http", port_nr);
    MESSAGE("Internal HTTPS Server enable on port " + port_nr);
    return true;
}

string get_port_config()
{
  return "https_port";
}

string get_port_name()
{
    return "https";
}
    
int get_port()
{
    return _Server->query_config("https_port");
}

string describe() { return "sTeamHTTPS("+get_port()+")"; }    

bool close_port()
{
    destruct(httpPort);
    destruct(this_object());
}
