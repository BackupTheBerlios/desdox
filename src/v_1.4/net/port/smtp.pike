/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 * Copyright (C) 2002-2003  Christian Schmidt
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


void setup_port()
{
    object tmp,u;

    tmp = ::accept();
    if ( !objectp(tmp) )
    {
        werror("Failed to bind socket !\n");
        return;
    }
    master()->register_user((u=new(OBJ_SMTP, tmp)));
}

program get_socket_program()
{
    return (program)OBJ_SMTP;
}

bool port_required() { return false; }
int get_port() { return _Server->query_config("smtp_port"); }
string describe() { return "SMTP(#"+get_port()+")"; }    

bool open_port()
{
    int port_nr = (int)_Server->query_config("smtp_port");
    string hostname = _Server->query_config("smtp_host");
    if ( !stringp(hostname) )
	hostname = "localhost";
    
    if ( port_nr == 0 )
    {
        MESSAGE("Port for incoming SMTP not defined - service is NOT started");
        return false;
    }

    if ( !bind(port_nr, setup_port) )
    {
        werror("Failed to bind smtp port on %s:%d!\n", hostname, port_nr);
        return false;
    }
    MESSAGE(sprintf("SMTP Port registered on %s:%d", hostname, port_nr));
    return true;
}

string get_port_config()
{
    return "smtp_port";
}

string get_port_name()
{
    return "smtp";
}
