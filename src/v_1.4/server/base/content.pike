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
inherit Thread.Mutex : w_mutex;

#include <macros.h>
#include <config.h>
#include <assert.h>

private static int              iContentID;
private static int       iContentSize = -1;
private static object        oDbFileHandle;

private static object           oLockWrite;
private static array(string) asUploadCache;

static bool add_data_storage(function a, function b);
static void download_finished();
static void require_save() { _Database->require_save(); }

/**
 * This callback function is registered via add_data_storage to provide
 * necessary data for serialisation. The database object calls this function
 * to save the values inside the database.
 *
 * @param  none
 * @return a mixed value containing the new introduced persistent values
 *         for content
 * @see    restore_content_data
 * @see    add_data_storage
 * @author Ludger Merkens 
 */
mixed retrieve_content_data()
{
    if ( CALLER != _Database )
	THROW("Illegal call to retrieve_content_data()", E_ACCESS);
    return ({ iContentSize, iContentID });
}

/**
 * This callback function is used to restore data previously read from
 * retrieve_content_data to restore the state of reading
 *
 * @param  a mixed value previously read via retrieve_content_data
 * @return void
 * @see    retrieve_content_data
 * @see    add_data_storage
 * @author Ludger Merkens 
 */
void restore_content_data(mixed data)
{
    if ( CALLER != _Database )
	THROW("Illegal call to restore_content_data()", E_ACCESS);
    
    [ iContentSize, iContentID ] = data;
}


/**
 * Initialize the content. This function only sets the data storage
 * and retrieval functions.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void init_content()
{
    add_data_storage(retrieve_content_data, restore_content_data);
}

/**
 * The function returns the function to download the content. The
 * object is configured and locked for the download and the
 * returned function send_content has to be subsequently called
 * in order to get the data. 
 * 
 * @param  none
 * @return function "send_content" a function that returns the content
 *         of a given range.
 * @see    send_content
 * @author Ludger Merkens 
 */
function get_content_callback(mapping vars)
{
    int t;
    float tf;
    
    if ( iContentID == 0 )
	LOG_DB("get_content_callback: missing ContentID");
    
    if ( objectp(oLockWrite) )
      error("Someone is writting content.");

    oDbFileHandle = _Database->new_db_file_handle(iContentID,"r");
    ASSERTINFO(objectp(oDbFileHandle), "No File handle found !");
    LOG("db_file_handle() allocated, now sending...\n");
    return send_content;
}

/**
 * This function gets called from the socket object associated with a user
 * downloads a chunk. It cannot be called directly - the function 
 * get_content_callback() has to be used instead.
 *
 * @param  int startpos - the position
 * @return a chunk of data | 0 if no more data is present
 * @see    receive_content
 * @see    get_content_callback
 * @author Ludger Merkens 
 */
private static string
send_content(int startpos)
{
    if ( !objectp(oDbFileHandle) )
	return 0;
    
    string buf = oDbFileHandle->read(DB_CHUNK_SIZE);
    if ( stringp(buf) ) {
	//LOG_DB("Sending " + strlen(buf) + " bytes...");
	return buf;
    }

    destruct(oDbFileHandle);

    // callback to notify about finished downloading
    download_finished();

    return 0;
}


/**
 * Allocate a file handle.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
private final static void allocate_file_handle()
{
    oLockWrite = w_mutex::trylock(); // one upload only
    if (!oLockWrite)
	THROW("no simultanous write access on content", E_ACCESS);
    
    LOG_DB("content.receive_content preparing upload to cID:"+iContentID);
    oDbFileHandle = _Database->new_db_file_handle(iContentID,"wtc");
    if (!iContentID)
    {
	iContentID = oDbFileHandle->dbContID();
	LOG_DB("created new cID:"+iContentID);
    }
    if (!iContentID)
	LOG_DB("missing iContentID");
}

/**
 * This function gets called to initialize the download of a content.
 * The returned function has to be called subsequently to write data.
 * After the upload is finished the function has to be called with
 * the parameter 0.
 *
 * @param  int content_size -- the size of the content that will be
 *         passed in chunks to the function returned
 * @return a function, that will be used as call_back by the object
 *         calling receive_content to actually store the data.
 * @see    save_chunk
 * @see    send_content
 * @author Ludger Merkens 
 */
function receive_content(int content_size)
{
    allocate_file_handle();
    iContentSize = 0;
    return save_chunk;
}

/**
 * This function gets called, when an upload is finished. All locks
 * are removed and the object is marked for the database save demon
 * (require_save()).
 *  
  * @see save_chunk
 */
static void
content_finished()
{
    iContentSize=oDbFileHandle->sizeof();
    LOG_DB("content.content_finished for cID:"+iContentID+"with size="+
	   iContentSize);
    destruct(oDbFileHandle); // will call close() and unlock
    require_save();
    if ( objectp(oLockWrite) )
	destruct(oLockWrite);    // release write lock
    return ;
}


/**
 * save_chunk is passed from receive_content to a data storing process, 
 * to store one chunk of data to the database.
 *
 * @param   string chunk - the data to store
 * @param   int start    - start position of the chunk relative to complete
 *                         data to store.
 * @param   int end      - similar to start
 * @return  void
 * @see     receive_content
  */
void save_chunk(string chunk)
{
    LOG_DB("content.save_chunk: "+(stringp(chunk) ? "(str)"+strlen(chunk): "0")+
	   " bytes"+"cID("+iContentID+")");
    if ( !stringp(chunk) )
    {
	content_finished();
	return;
    }
    oDbFileHandle->write(chunk);
    iContentSize += strlen(chunk); // save content size in between??

}


/**
 * update_content_size - reread the content size from the database
 * this is a hot-fix function, to allow resyncing with the database tables,
 * this function definitively should be obsolete.
 *
 * @param none
 * @return nothing
 * @author Ludger Merkens
 */
void update_content_size()
{
    object db_handle = _Database->new_db_file_handle(iContentID,"r");
    iContentSize = db_handle->sizeof();
    //	LOG("get_content_size @OBJ"+iContentID+" is:"+iContentSize);
    destruct(db_handle);     // will call close()
    require_save();
}

/**
 * evaluate the size of this content
 *
 * @param  none
 * @return int - size of content in byte
 * @author Ludger Merkens 
 */
int 
get_content_size()
{
    //    LOG_DB("content.get_content_size for cID:"+iContentID);
    //    if (iContentID==0)
    //	LOG_DB("content.get_content_size: missing iContentID");

    if ( objectp(oLockWrite) )
        error("Content is being written.");

    mixed cerr = catch
    {
	if ( iContentSize <= 0 )
	{
	    //	LOG_DB("reading content size from database");
	    object db_handle = _Database->new_db_file_handle(iContentID,"r");
	    iContentSize = db_handle->sizeof();
	    //	LOG("get_content_size @OBJ"+iContentID+" is:"+iContentSize);
	    destruct(db_handle);     // will call close()
	    require_save();
	}
	//    LOG_DB("content size from cache");
    };
    
    if (cerr)
	throw(cerr);
    
    return iContentSize;
}


/**
 * Get the ID of the content in the database.
 *  
 * @return the content id
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
int get_content_id()
{
    return iContentID;
}

/**
 * Get the content of the object directly. For large amounts
 * of data the download function should be used. It is possible
 * to pass a len parameter to the function so only the first 'len' bytes
 * are being returned.
 *  
 * @param int|void len
 * @return the content
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static string
_get_content(int|void len)
{
    string buf;
    // LOG_DB("content.get_content() of " + iContentID);
    
    mixed cerr = catch
    {
	object db_handle = _Database->new_db_file_handle(iContentID,"r");
	buf = db_handle->read(len);
	destruct(db_handle);
    };

    if (cerr)
	throw(cerr);
    
    return buf;
}

string get_content(int|void len)
{
    return _get_content(len);
}

/**
 * set_content, sets the content of this instance.
 *
 * @param  string cont - this will be the new content
 * @return int         - content size (or -1?)
 * @see    receive_content, save_content
 *
 * @author Ludger Merkens 
 */

int
set_content(string cont)
{
    function save = receive_content(strlen(cont));
    save(cont);  // set the content
    save(0);     // flush the buffers
    return strlen(cont);
}

/**
 * When the object is deleted its content has to be removed too.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final static void 
delete_content()
{
    mixed err = catch {
	allocate_file_handle();
	save_chunk("");
	save_chunk(0);
    };
    if ( err != 0 )
	FATAL("Failed to delete content.\n"+err[0]+
	      sprintf("\n%O", err[1]));
}

