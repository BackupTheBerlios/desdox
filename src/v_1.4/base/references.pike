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

#include <macros.h>
#include <exception.h>

static mapping mReferences;

static void   require_save();
object                this();
int       get_object_class();
object     get_environment();
string      get_identifier();

/**
 * Initialize the reference storage.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void init_references()
{
    mReferences = ([ ]);
}


/**
 * Add a reference to this object. The reference functionality is
 * maintained by the server itself and shouldnt be called by other code.
 *  
 * @param object ref - the reference.
 * @author Thomas Bopp (astra@upb.de) 
 * @see remove_reference
 */
void add_reference(object ref)
{
    if ( CALLER->get_object_id() != ref->get_object_id() )
	THROW("Adding reference by non-referencing object !", E_ACCESS);
    mReferences[ref] = 1;
    require_save();
}

/**
 * Remove a reference from this object. The function is for internal use.
 * The references are maintained by the server itself.
 *  
 * @param object ref - a reference to remove.
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_reference
 */
void remove_reference(object ref)
{
    if ( CALLER->get_object_id() != ref->get_object_id() )
	THROW("Adding reference by non-referencing object !", E_ACCESS);
    m_delete(mReferences, ref);
    require_save();
}

/**
 * Get the mapping of references. The mapping is in the form
 * ([ ref:1 ]) - a mapping is used for faster lookup.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see add_reference
 */
mapping get_references()
{
    return copy_value(mReferences);
}


/**
 * Store the references in the database. Database calls this function.
 *  
 * @return refereces.
 * @author Thomas Bopp (astra@upb.de) 
 * @see restore_references
 */
mixed
store_references() 
{
    if (CALLER != _Database ) THROW("Caller is not Database !", E_ACCESS);
    return ([ "References": mReferences, ]);
}

/**
 * The object is loaded and its references restored by the database.
 *  
 * @param mixed data - the reference data.
 * @author Thomas Bopp (astra@upb.de) 
 * @see store_references
 */
void restore_references(mixed data)
{
    if (CALLER != _Database ) THROW("Caller is not Database !", E_ACCESS);
    mReferences = data["References"];
}
