
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


string get_thumbnail(int xsize, int ysize, bool|void maintain)
{
    object thumb;

    thumb= query_attribute(DOC_IMAGE_THUMBNAIL);
    if ( objectp(thumb) && thumb->query_attribute(DOC_IMAGE_SIZEX) == xsize )
      return thumb->get_content();
    return query_thumbnail(xsize, ysize, maintain);
}

string query_thumbnail(int xsize, int ysize, bool|void maintain)
{
    int        factor;
    mapping  imageMap;
    Image.Image image;
 
    [imageMap, image ] = get_image();

    int rxsize, rysize;

    if ( xsize == 0 )
	xsize = image->xsize();
    if ( ysize == 0 )
	ysize = image->ysize();

    if ( maintain ) {
	rxsize = image->xsize();
	rysize = image->ysize();
	factor = min(xsize*100/rxsize, ysize*100/rysize);
    }
    if ( factor > 100 )
	factor = 100;
    xsize = factor * rxsize / 100;
    ysize = factor * rysize / 100;

    object new_image = image->scale(xsize, ysize);
    
    string str = Image.JPEG.encode(new_image);
    destruct(image);
    destruct(new_image);
    return str;
}

string get_image_data()
{
    if ( intp(query_attribute(DOC_IMAGE_ROTATION)) &&
	 query_attribute(DOC_IMAGE_ROTATION) > 0  ) 
    {
	Image.Image image = get_image()[1];
	string str = Image.JPEG.encode(image);
	destruct(image);
	return str;
    }
    return ::get_content();
}

array get_image()
{
    string        mt;
    mapping imageMap;
    int       factor;
    
    mt = query_attribute(DOC_MIME_TYPE);

    switch ( mt ) {
    case "image/gif":
	imageMap = Image.GIF.decode_map(get_content());
	break;
    case "image/jpeg":
	imageMap = Image.JPEG._decode(get_content());
	break;
#if constant(Image.PNG) && constant(Image.PNG._decode) 
    case "image/png":
	imageMap = Image.PNG._decode(get_content());
	break;
#endif
    case "image/bmp":
	imageMap = Image.BMP._decode(get_content());
	break;
    default:
	imageMap = Image.ANY._decode(get_content());
	break;
    }
    
    Image.Image image = imageMap->image;
    if ( intp(query_attribute(DOC_IMAGE_ROTATION)) ) {
	image = image->rotate(query_attribute(DOC_IMAGE_ROTATION));
	imageMap->xsize = image->xsize();
	imageMap->ysize = image->ysize();
    }

    return ({ imageMap, image });
}

object create_thumb()
{
    object obj;
    
    obj = query_attribute(DOC_IMAGE_THUMBNAIL);
    if ( objectp(obj) )
	obj->delete();
    if ( get_content_size() == 0 )
        return 0;
    
    object factory = _Server->get_factory(CLASS_DOCUMENT);
    object thumb = factory->execute( 
	([ "name": "THUMB_"+get_identifier(),
         "acquire": this(), 
	 ]) 
	);
    thumb->set_attribute("thumb", "true");
    thumb->set_content(query_thumbnail(80, 80, true));
    thumb->set_attribute(DOC_IMAGE_SIZEX, 80);
    thumb->set_attribute(DOC_IMAGE_SIZEY, 80);
    set_attribute(DOC_IMAGE_THUMBNAIL, thumb);
    return thumb;
}

static void content_finished()
{
    ::content_finished();
    if ( query_attribute("thumb") != "true" ) {
	mixed err = catch {
	    create_thumb(); // prevent resursion
	};
	if ( err != 0 )
	    FATAL("Error creating thumbnail:\n"+sprintf("%O\n",err));
    }
}

int get_object_class() { return ::get_object_class() | CLASS_IMAGE; }
