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


bool port_required() { return false; }

bool open_port()
{
    int port_nr = get_port();
    _fp = get_module("filepath:url");
    if ( catch(httpPort = Protocols.HTTP.Server.Port(
	http_request, (int)port_nr)) )
      if ( catch(httpPort = Protocols.HTTP.Server.Port(
          http_request, (int)port_nr, _Server->query_config("ip"))) )
            return false;
    MESSAGE("Internal HTTP Server enable on port " + port_nr);
    _Server->set_config("web_port", port_nr);
    return true;
}


bool close_port()
{
    destruct(httpPort);
    destruct(this_object());
}

string get_port_config()
{
    return "http_port";
}

string get_port_name()
{
    return "http";
}

int get_port()
{
    return _Server->query_config("http_port");
}

string describe() { return "sTeamHTTP("+get_port()+")"; }    
