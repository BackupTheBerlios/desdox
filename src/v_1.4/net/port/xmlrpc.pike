/* Copyright (C) 2000, 2001  Thomas Bopp, Thorsten Hampel, Ludger Merkens
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
inherit Stdio.Port;

#include <config.h>
#include <macros.h>

/***
 *
 *
 * @return 
 * @author Thomas Bopp 
 * @see 
 */

void setup_port() 
{
    object          tmp, u;

    tmp = ::accept();
    if ( !objectp(tmp) ) {
	werror("Failed to bind socket !\n");
	return;
    }
    master()->register_user((u=new(OBJ_XMLRPC, tmp)));
}

/**
 * Gets the program for the corresponding socket.
 *  
 * @return The socket for this port.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
program get_socket_program()
{
    return (program)OBJ_XMLRPC;
}

bool port_required() { return false; }
int get_port() { return _Server->query_config("xmlrpc_port"); }
string describe() { return "XMLRPC(#"+get_port()+")"; }

bool open_port()
{
    int port_nr = _Server->query_config("xmlrpc_port");
    if (  port_nr == 0 )
	port_nr = 2004; //23; must be root ?!

    if ( !bind(port_nr, setup_port) ) {
	werror("Failed to open xmlrpc socket !\n");
	return false;
    }
    MESSAGE("XMLRPC port opened on port "+ port_nr);
    return true;
}

string get_port_config()
{
    return "xmlrpc_port";
}

string get_port_name()
{
    return "xmlrpc";
}
