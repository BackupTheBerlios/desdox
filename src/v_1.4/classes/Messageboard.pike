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
inherit "/classes/Object";

#include <classes.h>
#include <macros.h>
#include <attributes.h>


object duplicate(void|mapping vars)
{
    object obj = ::duplicate(vars);
    return obj;
}

#define ARCHIVE_THREAD 60*60*24*30 // 30 days

private int ann_thread_time(object annotation) 
{
    int t = annotation->query_attribute(OBJ_CREATION_TIME);
    foreach(annotation->get_annotations(),object ann )
	t = max(t, ann_thread_time(ann));
    return t;
}


bool is_message_board() { return true; }

int get_object_class() { return ::get_object_class() | CLASS_MESSAGEBOARD; }