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
/*
 * COAL - HyperMUD Protocoll implementation file 
 */
inherit "coal/protocoll";

#include <coal.h>
#include <macros.h>
#include <assert.h>
#include <attributes.h>

#ifdef COAL_DEBUG
#define CDEBUG(s) werror(s+"\n")
#else
#define CDEBUG(s)
#endif

static mixed          mReceiveData;
static string          sLastPacket;
static array(string)      saErrors;
static int           iLastResponse;

/**
 * Create the socket and initialize the variables.
 *  
 * @author Thomas Bopp (astra@upb.de)
 */
void create()
{
    mCommandServer = ([ ]);
    sLastPacket    = "";
    iTransfer      = COAL_TRANSFER_NONE;
    iLastResponse  = time();

    saErrors = ({ 
	"Object was not found",
	"COAL: wrong syntax",
	"COAL: wrong filetype specified",
	"Security: Access violation",
	"Target was not found",
	"Error loading object",
	"Wrong Password",
	"account has expired",
        "Protocol error",
	"Command not understood",
	"Execution error (internal server error)",
	"User is unknown",
	"Wrong number of arguments to function",
	"Argument type does not match",
	"Exception",
    });
    init_protocoll();
}

/**
 * Called when the socket disconnects and also calls disconnect
 * function of the user object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
disconnect()
{
    object obj;
    
    CDEBUG("Transfer finished...\n");
    iTransfer = 0;
    if ( functionp(fUpload) ) {
	fUpload(0);
	fUpload = 0;
    }
    if ( objectp(oUser) )
	oUser->disconnect();
}


/**
 * Receive a message on the socket.
 *  
 * @param string str - the string received on the socket.
 * @author Thomas Bopp
 */
static void
receive_message(string str)
{
    string                         arguments;
    int                t_id, obj_id, command;
    function                            func;
    mixed                             result;
    array(mixed)                        args;
    array(mixed)                        cmds;
    object                               obj;
    int                            cid, n, i;

    iLastResponse = time();

    str = sLastPacket + str;
    sLastPacket = "";

    if ( iTransfer == COAL_TRANSFER_SEND ) {
	sLastPacket = str;
	return;
    }
    else if ( iTransfer == COAL_TRANSFER_RCV ) {
        i = strlen(str);            
        if ( i > iTransferSize ) {
            sLastPacket = copy_value(str[iTransferSize..]);
            str = str[..iTransferSize-1];
        } 
        fUpload(str);
        if ( iTransferSize != -1 ) {
             iTransferSize -= strlen(str);
             if ( iTransferSize <= 0 ) {
                 fUpload(0);
		 fUpload = 0;
                 str = sLastPacket;
		 iTransfer = COAL_TRANSFER_NONE;
	     }
        }
        if ( iTransfer == COAL_TRANSFER_RCV )
	    return;
    }
    
    
    cmds = receive_binary(str);
 
    while ( arrayp(cmds) ) {
	command  = cmds[HL_CMD][COALLINE_COMMAND] & COMMAND_RAW;
	obj_id   = cmds[HL_CMD][COALLINE_OBJECT];
	args     = cmds[HL_ARGS];
	str      = cmds[HL_REST];
	t_id     = cmds[HL_CMD][COALLINE_TID];
	obj      = (obj_id == 0 ? _Server : find_object(obj_id) );
	func     = mCommandServer[command];
	cid = (objectp(obj) ? obj->get_object_class() : 0);

	CDEBUG("RCVD: " + command + ","+obj_id+","+t_id+")");
	if ( functionp(func) )
	{
	    string btrace = "";
	    mixed message = catch {
		result = func(t_id, obj, args);
	    };
	    if ( message != 0 ) {
		iTransfer = 0; // set back transfer mode !
		FATAL("Caught Throw !\n");
		FATAL(message[0]);
		FATAL(master()->describe_backtrace(message[1]));
		btrace = master()->describe_backtrace(message[1]);
	    }
	    if ( arrayp(message) ) {
		if ( sizeof(message) == 3 ) {
		    SEND_ERROR(message[2], message[0], t_id, obj_id, cid,
			       command, args, btrace);
                }
		else {
		    SEND_ERROR(E_ERROR, message[0],  
			       t_id, obj_id, cid, command, args, btrace);
		}
	    }
	    else if ( objectp(message) ) {
		SEND_ERROR(E_ERROR, message[0],  
			   t_id, obj_id, cid, command, args, btrace);
	    }

	    if ( result != 0 ) {
		SEND_ERROR(result, "Exception",t_id,obj_id,cid, 
			   command, args, 0);
	    }
	}
	else 
	    SEND_ERROR(E_FUNCTION|E_NOTEXIST, "Command does not exist !", 
		       t_id, obj_id, cid,command, args, 0);
	
	cmds = receive_binary(str);
    }
    sLastPacket += str;	
}

void hangup()
{
    SEND_COAL(0, COAL_LOGOUT, 0, 0, ({ }));
    close_connection();
}

static void close_connection()
{
  logout_user();
}

string get_socket_name() { return "coal"; }
int get_last_response() { return iLastResponse; }
