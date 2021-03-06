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
inherit Stdio.Port;

#include <config.h>
#include <macros.h>

/***
 * Create a new socket when a connection is established on this port.
 *
 */

void setup_port() 
{
    object          tmp, u;

    tmp = ::accept();
    if ( !objectp(tmp) ) {
	werror("Failed to bind socket !\n");
	return;
    }
    master()->register_user((u=new(OBJ_POP3, tmp)));
}

/**
 * Gets the program for the corresponding socket.
 *  
 * @return The socket for this port.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
program get_socket_program()
{
    return (program)OBJ_POP3;
}

/**
 * Setup the port objects port - listen to the configured port.
 *  
 * @return true or false.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool open_port()
{
    int port_nr = _Server->query_config("pop3_port");
    if ( port_nr == 0 ) 
	port_nr = 6668;

    if ( !bind(port_nr, setup_port) ) {
	werror("Failed to bind pop3 port on " + port_nr + " !\n");
	return false;
    }
    LOG("POP3 Port registered on " + port_nr);
    return true;
}

string get_port_config()
{
    return "pop3_port";
}

string get_port_name()
{
    return "pop3";
}

bool close_port()
{
    destruct(this_object());
}

bool port_required() { return false; }
int get_port() { return _Server->query_config("pop3_port"); }
string describe() { return "POP3(#"+get_port()+")"; }    

