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
inherit "/kernel/module.pike";

//! This is the tar module. It is able to create a string-archive of
//! all tared files.

#include <macros.h>

#define BLOCKSIZE 512

/**
 * Convert an integer value to oct.
 *  
 * @param int val - the value to convert
 * @param int size - the size of the resulting buffer
 * @return the resulting string buffer
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static string to_oct(int val, int size)
{
    string v = (string) val;
    string oct = "";
    int i;

# define MAX_OCTAL_VAL_WITH_DIGITS(digits) (1 << ((digits) * 3) - 1)
    
    for ( i = 0; i < size; i++ ) oct += " ";
    
    if ( val <= MAX_OCTAL_VAL_WITH_DIGITS(size-1) )
	oct[--i] = '\0';
    
    while ( i >= 0 && val != 0 ) {
	oct[--i] = '0' + (int)(val&7);
	val >>=3;
    }

    while ( i!=0 )
	oct[--i] = '0';
    return oct;
}

static private string header;

/**
 * Copy a source string to the header at position 'pos'.
 *  
 * @param string source - source string to copy.
 * @param int pos - the position to copy it in 'header'.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void buffer_copy(string source, int pos)
{
    for ( int i = 0; i < strlen(source); i++ )
	header[pos+i] = source[i];
}


/**
 * Create a header in the tarfile with name 'fname' and content 'content'.
 *  
 * @param fname - the filename to store.
 * @param content - the content of the file.
 * @return the tar header for the filename.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static string tar_header(string fname, string content)
{
    int  i, l;
    
    fname = replace
	(fname, 
	 ({ "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß", "<", ">", "?", " ", "'" }),
	 ({ "\344", "\366", "\374", "\304", "\326", "\334", "\337", 
		"\74", "\76", "\77", "\40", "\47" }));

    if ( !stringp(content) )
      l = 0;
    else
      l = strlen(content);

    header = "\0" * BLOCKSIZE;

    buffer_copy(fname,  0);
    buffer_copy("0100664",  100);
    buffer_copy("0000767",  108);
    buffer_copy("0000767",  116);
    buffer_copy(to_oct(l, 12),  124);
    buffer_copy(to_oct(time(), 12),  136);
    int chksum = 7*32; // the checksum field is counted as ' '
    buffer_copy("ustar  ",  257);
    buffer_copy("steam",  265);
    buffer_copy("steam",  297);
    buffer_copy(" 0",  155);
    
    for ( i = 0; i < BLOCKSIZE; i++ )
	chksum += header[i];
    
    buffer_copy(to_oct(chksum, 7),  148);
    
    return header;
}

/**
 * Tar the content of the file 'fname'. Tars both header and content.
 *  
 * @param string fname - the filename to tar.
 * @param string content - the content of the file.
 * @return the tared string.
 */
string tar_content(string fname, string content)
{
    string buf;
    if ( !stringp(fname) || fname== "" ) {
	FATAL("Empty file name !");
	return "";
    }
    LOG("tar_content("+fname+", "+strlen(content)+" bytes)\n");
    if ( !stringp(content) || strlen(content) == 0  ) 
	return tar_header(fname, content);

    buf = tar_header(fname, content);
    buf += content;
    int rest = BLOCKSIZE - (strlen(content) % BLOCKSIZE);
    string b = "\0" * rest;
    buf += b;
    return buf;
}

/**
 * Create an end header for the tarfile.
 *  
 * @return the end header.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string end_header()
{
    return "\0" * BLOCKSIZE; 
}

/**
 * Create an empty tarfile header.
 *  
 * @return an empty tarfile header.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see tar_header
 */
string empty_header()
{
    return tar_header("", "");
}

/**
 * Create a tarfile with an array of given steam objects. This
 * tars there identifiers and call the content functions.
 *  
 * @param array(object) arr - array of documents to be tared.
 * @return the tarfile.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string tar_objects(array(object) arr)
{
    string tar = "";
    foreach(arr, object obj) {
	tar += tar_content(obj->get_identifier(), obj->get_content());
    }
    tar += end_header(); // empty header at the end
    return tar;
}

string get_identifier() { return "tar"; }


