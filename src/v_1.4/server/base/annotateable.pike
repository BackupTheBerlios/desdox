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
#include <classes.h>
#include <access.h>
#include <database.h>
#include <roles.h>
#include <attributes.h>

static array(object) aoAnnotations; // list of annotations
static object           oAnnotates; // refering to ...

string        get_identifier();
object                  this();
static void     require_save();

/**
 * Initialization of annotations on this object.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see add_annotation
 * @see remove_annotation
 */
static void init_annotations()
{
    aoAnnotations = ({ });
    oAnnotates = 0;
}

/**
 * Add an annotation to this object. Any object can be an annotations, but
 * usually a document should be used here.
 *  
 * @param object ann - the documentation
 * @return if adding was successfull or not.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see remove_annotation
 */
static bool add_annotation(object ann)
{
    if ( !IS_PROXY(ann) )
	THROW("Fatal error: annotation is not a proxy !", E_ERROR);
    LOG("Adding annotation: " + ann->get_object_id() + " on "+
	get_identifier());
    return do_add_annotation(ann);
}

static bool do_add_annotation(object ann)
{
    aoAnnotations += ({ ann });
    ann->set_annotating(this());
    require_save();
    return true;
}

/**
 * Remove an annotation from the object. The function just removes
 * the annotation from the list of annotations.
 *  
 * @param object ann - the annotation to delete
 * @return if removing was successfull.
 * @see add_annotation
 */
static bool remove_annotation(object ann)
{
    if ( !IS_PROXY(ann) )
	THROW("Fatal error: annotation is not a proxy !", E_ERROR);
    if ( search(aoAnnotations, ann) == -1 )
	THROW("Annotation not present at document !", E_ERROR);

    aoAnnotations -= ({ ann });
    ann->set_annotating(0);
    require_save();
    return true;
}

/**
 * Remove all annotations. This will move the annotation to their
 * authors. The function is called when the object is deleted.
 *  
 */
static void remove_all_annotations() 
{
    mixed err;

    foreach( aoAnnotations, object ann ) {
	if ( objectp(ann) && ann->get_environment() == null ) {
	    object creator = ann->get_creator();
	    object trash = creator->query_attribute(USER_TRASHBIN);
	    err = catch {
		if ( objectp(trash) )
		    ann->move(trash);
		else
   		    ann->move(creator);
	    };
            if ( err != 0 )
		ann->delete();
	}
    }
}

/**
 * This function returns a copied list of all annotations of this
 * object.
 *  
 * @return the array of annotations
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_annotations_for
 */
array(object) get_annotations(void|int from_obj, void|int to_obj)
{
    array annotations = ({ });

    if ( !arrayp(aoAnnotations) )
	aoAnnotations = ({ });

    aoAnnotations -= ({ 0 }); // remove 0 values of deleted annotations
    for (int i = sizeof(aoAnnotations) - 1; i >= 0; i-- ) 
    {
	object ann = aoAnnotations[i];
	if ( i >= from_obj && ( !to_obj || i < to_obj ) )
	    annotations += ({ ann });
    }
    return annotations;
}

/**
 * Get the object we are annotating.
 *  
 * @return the object we annotated
 */
object get_annotating()
{
    return oAnnotates;
}

/**
 * Set the annotating object.
 *  
 * @param object obj - the annotating object
 */
void set_annotating(object obj)
{
    if ( !objectp(oAnnotates) || CALLER == oAnnotates )
	oAnnotates = obj;
    require_save();
}

/**
 * Get only the annotations for a specific user. If no user is given
 * this_user() will be used.
 *  
 * @param object|void user - the user to get the annotations for
 * @return array of annotations readable by the user
 * @see get_annotations
 */
array(object) 
get_annotations_for(object|void user, void|int from_obj, void|int to_obj)
{
    if ( !objectp(user) ) user = this_user();
    
    array(object) user_annotations = ({ });
    if ( !intp(from_obj) )
	from_obj = 1;

    foreach ( aoAnnotations, object annotation ) {
	if ( !objectp(annotation) ) continue;

	mixed err = catch {
	    _SECURITY->check_access(
		annotation, user, SANCTION_READ, ROLE_READ_ALL, false);
	};
	if ( err == 0 )
	    user_annotations = ({ annotation }) + user_annotations;
    }
    if ( !to_obj )
	return user_annotations[from_obj-1..];
    return user_annotations[from_obj-1..to_obj-1];
}


/**
 * Retrieve annotations is for storing the annotations in the database.
 * Only the global _Database object is able to call this function.
 *  
 * @return Mapping of object data.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see restore_annotations
 */
final mapping retrieve_annotations()
{
    if ( CALLER != _Database )
	THROW("Caller is not the Database object !", E_ACCESS);
    return ([ "Annotations":aoAnnotations,
	      "Annotates": oAnnotates, ]);
}

/**
 * Called by database to restore the object data again upon loading.
 * 
 * @param mixed data - the object data
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see retrieve_annotations
 */
final void
restore_annotations(mixed data)
{
    if ( CALLER != _Database )
	THROW("Caller is not the Database object !", E_ACCESS);
    aoAnnotations = data["Annotations"];
    oAnnotates = data["Annotates"];
    if ( !arrayp(aoAnnotations) )
	aoAnnotations = ({ });
    require_save();
}

