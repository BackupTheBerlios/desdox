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
inherit "/classes/Document";

#include <exception.h>
#include <macros.h>
#include <classes.h>
#include <attributes.h>
#include <types.h>

static mapping mp3Data = ([ "sampling":44100, "bitrate":128000, ]);



mapping get_mp3()
{
    if ( !mappingp(mp3Data) ) {
	object mp3 = MP3.File(get_content(8192));
	mp3Data = mp3->get_frame();
	m_delete(mp3Data, "data");
	return mp3->get_frame();
    }
    return copy_value(mp3Data);
}

int get_bitrate()
{
    if ( !mappingp(mp3Data) )
	get_mp3();
    return mp3Data->bitrate/1000;
}

int get_frequency()
{
    if ( !mappingp(mp3Data) )
	get_mp3();
    return mp3Data->sampling;
}

class MyBuffer {
    inherit Stdio.File;
    
    int       fPos;
    string content;

    void create(string buf) {
	content = buf;
	fPos = 0;
    }

    mapping stat() {
	mapping stats = ([ "size":strlen(content), ]);
	return stats;
    }
    
    int seek(int pos) {
	fPos = pos;
	return pos;
    }
    void set_limit(int x) { }
    
    string read(int bytes) {
	string str = content[fPos..fPos+bytes];
	fPos += bytes;
	return str;
    }
}

mapping get_id3()
{
    MyBuffer buf = MyBuffer(get_content());
    object tag = ID3.Tag(buf);
    mapping id3 = tag->friendly_values() + ([ "version": tag->version, ]);
    return id3;
}

int get_object_class() { return ::get_object_class() | CLASS_MP3; }
