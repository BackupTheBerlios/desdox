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
inherit "/kernel/secure_n_n";

#include <macros.h>
#include <attributes.h>
#include <exception.h>
#include <types.h>
#include <classes.h>
#include <events.h>

//! This module stores keywords inside the database to allow the
//! search of objects by keywords. Thus the module maps keyword:object
//! in a database table. The function search_objects() searches
//! a given keyword inside the table.

/**
 * Initialize the module.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void init_module()
{
    set_attribute(OBJ_DESC,"This module handles the keywords for each object");
}

/**
 * Called on installation of module, registers the keywords attribute
 * of all classes to this module, to store the values in an indexed
 * database table for fast lookup.
 *  
 * @param  none
 * @return nothing
 * @author Ludger Merkens (balduin@upb.de)
 * @see    set_attribute
 * @see    query_attribute
 */
void install_module()
{
    LOG("install_module() inside keyword_index.pike !");
    object factory = _Server->get_factory(CLASS_OBJECT);
    array reg = factory->describe_attribute(OBJ_KEYWORDS);
    factory->register_attribute(OBJ_KEYWORDS, CMD_TYPE_ARRAY,"keywords", 
				0, EVENT_ATTRIBUTES_CHANGE, this(),
				CONTROL_ATTR_USER, ({}));
}

/**
 * This function associates the CALLER with the keywords set within the
 * database, search ability is improved by creating an reverse index.
 *  
 * @param   key - checked for OBJ_KEYWORDS
 * @param   mixed - the list of keywords to store for the caller
 * @return  (true|false) 
 * @author Ludger Merkens (balduin@upb.de)
 * @see     query_attribute
 * @see     /kernel/secure_mapping.register
 */
mixed set_attribute(string|int key, mixed val)
{
    array(string)      keywords;
    object obj = CALLER->this();
    mixed values, valold;
    string v;

    LOG_DB("Keywords "+master()->detailed_describe(val)+
        " for Object #"+obj->get_object_id());
    
    if ( key == OBJ_KEYWORDS ) {
        if (!arrayp(val))
            val = ({val});
	return register(val, obj);
    }
    else {
	return ::set_attribute(key, val);
    }
}
    
/**
 * This function retreives the keywords stored in the database for CALLER
 *  
 * @param    key - checked for OBJ_KEYWORDS
 * @return   keywords from the database
 * @author   Ludger Merkens (balduin@upb.de) 
 * @see      set_attribute
 * @see      /kernel/secure_mapping.lookup
 */
mixed query_attribute(string|int key)
{
    mixed res;
    
    if ( key == OBJ_KEYWORDS ) {
	object obj = CALLER->this();
	res = ::get_key(obj);
	return res;
    }
    return ::query_attribute(key);
}

/**
 * executes a query in the database according to a search term
 * 25.09.2001 replace * probably meant as wild card, with % 
 *            to regard SQL Syntax
 * @param  string - search-term
 * @return a list of objects
 * @author Ludger Merkens 
 */
array(object) search_objects(string searchterm)
{
    //    LOG("keyword_index.pike search for "+searchterm);
    searchterm = replace(searchterm, "*", "%");
    mixed result = lookup(searchterm);
    if ( objectp(result) )
	return ({ result });
    else if ( !arrayp(result) )
	return ({ });
    return result;
}

/**
 * Get the identifier of this module. 
 *
 * @return  "index:keywords"
 * @author Ludger Merkens 
 */
string get_identifier() { return "index:keywords"; }
string get_table_name() { return "keyword_index"; }
