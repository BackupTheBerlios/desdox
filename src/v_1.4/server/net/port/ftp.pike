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
 * Setup a new connection with a socket.
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
    werror("Registering new user on ftp port...\n");
    master()->register_user((u=new(OBJ_FTP, tmp)));
}

/**
 * Gets the program for the corresponding socket.
 *  
 * @return The socket for this port.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
program get_socket_program()
{
    return (program)OBJ_FTP;
}

/**
 * Called to open the port and binds the configured coal port.
 *  
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool open_port()
{
    int port_nr = get_port();
    if ( !bind(port_nr, setup_port) ) {
	werror("Failed to open secure coal socket !\n");
	return false;
    }
    _Server->set_config("web_port_ftp", port_nr);
    MESSAGE("FTP port opened on port " + port_nr);
    return true;
}

bool close_port()
{
    
}

string get_port_config()
{
    return "ftp_port";
}

string get_port_name()
{
    return "ftp";
}

bool port_required() { return false; }
int get_port() { return _Server->query_config("ftp_port"); }
string describe() { return "FTP(#"+get_port()+")"; }    
