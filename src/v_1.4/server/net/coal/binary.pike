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
#include <coal.h>
#include <macros.h>
#include <assert.h>

static string     wstr;
static int    iLastTID;

static object find_obj(int id)
{
    return find_object(id);
}

/**
 * convert an array to binary string
 *  
 * @param arr - the array to send
 * @return the binary representation of the array
 * @author Thomas Bopp (astra@upb.de) 
 * @see send_binary
 */
string send_array(array(mixed) arr)
{
    int  i, sz;
    string str;
    
    sz = sizeof(arr);
    str = "   ";
    str[0] = CMD_TYPE_ARRAY;
    str[1] = (sz & (255<<8)) >> 8;
    str[2] = (sz & 255);    

    for ( i = 0; i < sz; i++ )
	str += send_binary(arr[i]);
    return str;
}

/**
 * convert a mapping to a binary string
 *  
 * @param map - the mapping to send
 * @return the binary representation of the mapping
 * @author Thomas Bopp (astra@upb.de) 
 * @see send_binary
 */
string send_mapping(mapping map)
{
    int  i, sz;
    string str;
    array(mixed) ind;
    
    ind = indices(map);
    sz  = sizeof(ind);
    str = "   ";
    str[0] = CMD_TYPE_MAPPING;
    str[1] = (sz & (255<<8)) >> 8;
    str[2] = (sz & 255);    

    for ( i = 0; i < sz; i++ ) {
	str += send_binary(ind[i]);
	str += send_binary(map[ind[i]]);
    }
    return str;
}

/**
 * convert a variable to a binary string
 *  
 * @param arg - the variable to convert
 * @return the binary representation of the variable
 * @author Thomas Bopp (astra@upb.de) 
 * @see receive_binary
 */
string 
send_binary(mixed arg)
{
    int      i;
    int    len;
    object obj;
    string str;

    if ( zero_type(arg) )
	arg = 0; //send zero

    if ( floatp(arg) ) {
	string floatstr;

	str = "     ";
	floatstr = sprintf("%F", arg);
	str[0] = CMD_TYPE_FLOAT;
	str[1] = floatstr[0];
	str[2] = floatstr[1];
	str[3] = floatstr[2];
	str[4] = floatstr[3];
    }
    else if ( intp(arg) ) {
	str = "     ";
	str[0] = CMD_TYPE_INT;
	if ( arg < 0 ) {
	    arg = -arg;
            arg = (arg ^ 0x7fffffff) + 1; // 32 bit
	    str[1] = ((arg & ( 0xff000000)) >> 24);
	    str[1] |= (0x80);
	}
	else {
	    str[1] = ((arg & ( 0xff000000)) >> 24);
	}
	str[2] = (arg & ( 255 << 16)) >> 16;
	str[3] = (arg & ( 255 << 8)) >> 8;
	str[4] = (arg & ( 255 ));
    }
    else if ( functionp(arg) ) {
	str = "     ";
	string fname;
	object o = function_object(arg);
	if ( !objectp(o) || !functionp(o->get_object_id) )
	    fname = "(function)";
	else
	    fname = "("+function_name(arg) + "():" + o->get_object_id() + ")";

	len = strlen(fname);
	str[0] = CMD_TYPE_FUNCTION;
	str[1] = (len & ( 255 << 24)) >> 24;
	str[2] = (len & ( 255 << 16)) >> 16;
	str[3] = (len & ( 255 << 8)) >> 8;
	str[4] = (len & 255);

	str += fname;
    }
    else if ( programp(arg) ) {
	string prg = master()->describe_program(arg);

	str = "     ";
	len = strlen(prg);
	str[0] = CMD_TYPE_PROGRAM;
	str[1] = (len & 0xff000000) >> 24;
	str[2] = (len & 0x0000ff00) >> 16;
	str[3] = (len & 0x00ff0000) >> 8;
	str[4] = (len & 0x000000ff);
	str += prg;
	
    }
    else if ( stringp(arg) ) {
	str = "     ";
	len = strlen(arg);
	str[0] = CMD_TYPE_STRING;
	str[1] = (len & 0xff000000) >> 24;
	str[2] = (len & 0x00ff0000) >> 16;
	str[3] = (len & 0x0000ff00) >> 8;
	str[4] = (len & 0x000000ff);
	str += arg;
    }
    else if ( objectp(arg) ) {
	int id;
	str = "         ";
	str[0] = CMD_TYPE_OBJECT;
	if ( !functionp(arg->get_object_id) )
	    id = 0;
	else
	    id = arg->get_object_id();
	str[1] = (id & ( 255 << 24)) >> 24;
	str[2] = (id & ( 255 << 16)) >> 16;
	str[3] = (id & ( 255 << 8))  >>  8;
	str[4] = (id & ( 255 ));
	if ( !functionp(arg->get_object_class) )
	    arg = 0;
	else
	    arg = arg->get_object_class();
	str[5] = (arg & ( 255 << 24)) >> 24;
	str[6] = (arg & ( 255 << 16)) >> 16;
	str[7] = (arg & ( 255 << 8))  >>  8;
	str[8] = (arg & ( 255 ));
    }
    else if ( arrayp(arg) )
	return send_array(arg);
    else if ( mappingp(arg) )
	return send_mapping(arg);
    else
	error("Failed to serialize - unknown type of arg="+sprintf("%O",arg));
    return str;
}

/**
 * a mapping was found at offset position pos
 *  
 * @param pos - the position where the mapping starts in the received string
 * @return the mapping and the end position of the mapping data
 * @author Thomas Bopp (astra@upb.de) 
 * @see receive_args
 */
array(int|mapping)
receive_mapping(int pos)
{
    mapping   map;
    int    i, len;
    array(mixed)    arr;
    mixed     val;
    mixed  ind, v;

    map = ([ ]);
    len = (wstr[pos] << 8) + wstr[pos+1];
    pos += 2;

    for ( i = 0; i < len; i++ )
    {
	val = receive_args(pos);
	pos = val[1];
	ind = val[0];
	val = receive_args(pos);
	pos = val[1];
	v   = val[0];
	map[ind] = v;
    }
    return ({ map, pos });
}

/**
 * an array was found in the received string
 *  
 * @param pos - the startposition of the array data
 * @return the array and the end position
 * @author Thomas Bopp (astra@upb.de) 
 * @see receive_args
 */
array(mixed)
receive_array(int pos)
{
    int    i, len;
    array(mixed)    arr;
    mixed     val;
    
    len = (wstr[pos] << 8) + wstr[pos+1];
    pos += 2;
    arr = allocate(len);
    for ( i = 0; i < len; i++ )
    {
	val = receive_args(pos);
	pos = val[1];
	arr[i] = val[0];
    }
    return ({ arr, pos });
}


/**
 * receive a variable at position i, the type is not yet known
 *  
 * @param i - the position where the variable starts, 
 *            including type information
 * @return the variable and end position in the binary string
 * @author Thomas Bopp (astra@upb.de) 
 * @see send_binary
 */
mixed
receive_args(int i)
{
    int    type, tmp;
    object       obj;
    int          len;
    mixed        res;

    type = wstr[i];
    switch(type) { 
    case CMD_TYPE_INT:
	res = (int)((wstr[i+1]<<24) + (wstr[i+2] << 16) + 
			(wstr[i+3] << 8) + wstr[i+4]);
	if ( res > 0 && res & (1<<31) ) {
	    // conversion from 32 to 64 bit if negative
	    res = (res ^ (0xffffffff)) + 1;
	    res *= -1; // negative
	}
	return ({ res, i+5 });
    case CMD_TYPE_FLOAT:
	string floatstr;
	floatstr = "    ";
	floatstr[0] = wstr[i+1];
	floatstr[1] = wstr[i+2];
	floatstr[2] = wstr[i+3];
	floatstr[3] = wstr[i+4];
	sscanf(floatstr, "%4F", res);
	return ({ res, i+5 });
    case CMD_TYPE_OBJECT:
	tmp = (int)((wstr[i+1]<<24) + (wstr[i+2] << 16) + 
		    (wstr[i+3] << 8) + wstr[i+4]);
	obj = find_obj(tmp);
	return ({ obj, i+9 });
    case CMD_TYPE_PROGRAM:
    case CMD_TYPE_STRING:
    case CMD_TYPE_FUNCTION:
	len = (int)((wstr[i+1]<<24)+(wstr[i+2]<<16) +
		    (wstr[i+3] << 8) + wstr[i+4]);
	return ({ wstr[i+5..i+len-1+5], i+len+5 });
    case CMD_TYPE_ARRAY:
	return receive_array(i+1);
    case CMD_TYPE_MAPPING:
	return receive_mapping(i+1);
    }
    error("coal::Unknown type "+ type);
}

/**
 * converts a coal command to a binary string
 *  
 * @param t_id - the transaction id
 * @param cmd - the command
 * @param o_id - the relevant object id
 * @param args - the additional args to convert
 * @return the binary string representation
 * @author Thomas Bopp (astra@upb.de) 
 * @see send_binary
 */
string
coal_compose(int t_id, int cmd, int o_id, int class_id, mixed args)
{
    string scmd;

    scmd = "                  ";
    scmd[0] = COMMAND_BEGIN_MASK; /* command begin flag */

    scmd[5] = (t_id & (255 << 24)) >> 24;
    scmd[6] = (t_id & (255 << 16)) >> 16;
    scmd[7] = (t_id & (255 <<  8)) >> 8;
    scmd[8] = t_id & 255;

    scmd[9] = cmd%256;

    scmd[10]  = (o_id & (255 << 24)) >> 24;
    scmd[11]  = (o_id & (255 << 16)) >> 16;
    scmd[12] = (o_id & (255 <<  8)) >>  8;
    scmd[13] = o_id & 255;
    scmd[14] = (class_id & (255 << 24)) >> 24;
    scmd[15] = (class_id & (255 << 16)) >> 16;
    scmd[16] = (class_id & (255 <<  8)) >>  8;
    scmd[17] = class_id & 255;

    scmd += send_binary(args);
    int slen = strlen(scmd);
    scmd[1] = (slen & 0xff000000) >> 24;
    scmd[2] = (slen & 0x00ff0000) >> 16;
    scmd[3] = (slen & 0x0000ff00) >> 8;
    scmd[4] = (slen & 0x000000ff);

    return scmd;
}


/**
 * receive_binary
 *  
 * @param str - what is received
 * @return array containing { tid, cmd, obj_id }, args, unparsed rest 
 * @author Thomas Bopp 
 * @see send_binary
 */
static mixed
receive_binary(string str)
{
    int cmd, t_id, len, i, slen, id, n;
    mixed                         args;

    if ( !stringp(str) )
	return -1; 
    slen = strlen(str);
    if ( slen == 0 )
	return -1;
    for ( n = 0; n < slen-10; n++ )
	if ( str[n] == COMMAND_BEGIN_MASK )
	    break;
    if ( n >= slen-18 ) 
	return -1;

    len    = (int)((str[n+1]<<24) + (str[n+2]<<16) + (str[n+3]<<8) +str[n+4]);
    if ( len+n > slen || len < 12 ) // need whole string in buffer
	return 0;

    t_id   = (int)((str[n+5] << 24) + (str[n+6]<<16) + 
		   (str[n+7]<<8) + str[n+8]);
    cmd    = (int)str[n+9];
    id     = (int)((str[n+10] << 24) + (str[n+11]<<16) + 
		   (str[n+12]<<8) + str[n+13]);
    
    /* class id of object is ignored at this point... */
    iLastTID = t_id;

    wstr = str;
    args = receive_args(n+18);

    args = args[0];
    wstr = "";
    return ({ ({ t_id, cmd, id }), args, str[n+len..] });
}






