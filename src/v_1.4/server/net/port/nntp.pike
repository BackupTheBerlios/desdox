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
 * Called when a new connection is established and assigns
 * a socket object to that connection.
 *
 * @author Thomas Bopp 
 */

void setup_port() 
{
    object          tmp, u;

    tmp = ::accept();
    if ( !objectp(tmp) ) {
	werror("Failed to bind socket !\n");
	return;
    }
    master()->register_user((u=new(OBJ_NNTP, tmp)));
}

/**
 * Gets the program for the corresponding socket.
 *  
 * @return The socket for this port.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
program get_socket_program()
{
    return (program)OBJ_NNTP;
}

/**
 * Open the port on the configured value (nntp_port).
 *  
 * @return true or false.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool open_port()
{
    int port_nr = _Server->query_config("nntp_port");
    if ( port_nr == 0 ) 
	port_nr = 6669;

    if ( !bind(port_nr, setup_port) ) {
	werror("Failed to bind nntp port on " + port_nr+" !\n");
	return false;
    }
    LOG("NNTP Port registered on " + port_nr);
    return true;
}

string get_port_config()
{
    return "nntp_port";
}

string get_port_name()
{
    return "nntp";
}

bool port_required() { return false; }
int get_port() { return _Server->query_config("nntp_port"); }
string describe() { return "NNTP(#"+get_port()+")"; }    
