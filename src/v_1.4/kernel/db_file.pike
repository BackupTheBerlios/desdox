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
 * /kernel/db_file
 * this is the database file emulation, which stores a binary file
 * in a sequence of 64k blobs in a SQL database.
 */

#include <macros.h>

private int                         iID;
private static int          iNextRecNbr;     /* last current read */
private static int             iCurrPos;      /* current position */
private static int           iMaxRecNbr; /*  last rec_order block */
private static int           iMinRecNbr; /* first rec_order block */
private static string             sMode;            /* read/write */
private static string       sReadBuf="";    
private static string      sWriteBuf="";
private static int         iFileSize=-1; /* not set otherwise >=0 */
private static Thread.Thread    tReader;       /* prefetch reader */
private static Thread.Fifo     ContFifo=Thread.Fifo(); /* the buffer*/
private static int        iStopReader=0;
private static Thread.MutexKey  mReader;
private static int          iPrefetch=1;
private function                    fdb;

array get_database_handle(int id)
{
    return _Database->connect_db_file(id);
}

void create(int ID, string mode) {
    open(ID, mode);
}

#define READ_ONCE 100

void read_from_db()
{
    Sql.sql_result odbData;
    array       fetch_line;

    //    werror("---- starting prefetch -----\n");
    mReader = Thread.Mutex()->lock(1);
    while ((iNextRecNbr <= iMaxRecNbr) && !iStopReader)
    {
        //        LOG("[select rec_data,rec_order from doc_data"+
        //            " where doc_id ="+iID+
        //            " and rec_order >="+iNextRecNbr+
        //            " and rec_order < "+(iNextRecNbr+READ_ONCE)+
        //            " order by rec_order]");
        odbData = fdb()->big_query("select rec_data,rec_order from doc_data"+
                                   " where doc_id ="+iID+
                                   " and rec_order >="+iNextRecNbr+
                                   " and rec_order < "+(iNextRecNbr+READ_ONCE)+
                                   " order by rec_order");
        
        while ((!iStopReader) && (fetch_line=odbData->fetch_row()))
        {
            ContFifo->write(fetch_line[0]);
            iNextRecNbr= (int)fetch_line[1] +1;
        }
	if ( iNextRecNbr == 0 ) {
	    ContFifo->write(0);
	    tReader = 0;
	    return;
	}
    }
    if (!iStopReader)
        ContFifo->write(0);
    LOG("------ prefetch done -------\n");
    LOG(sprintf("mReader after read_from_db %O\n", mReader));
    if (mReader)
        destruct(mReader);     // allow stop_reader to continue
    tReader = 0;           // thread stopped, so clear variable
}

/**
 * open a database content with given ID, if ID 0 is given a new ID
 * will be generated.
 *
 * @param   int ID      - (an Content ID | 0)
 * @param   string mode - 
 *               'r'  open file for reading  
 *               'w'  open file for writing  
 *               'a'  open file for append (use with 'w')  
 *               't'  truncate file at open (use with 'w')  
 *               'c'  create file if it doesn't exist (use with 'w')
 *		     'x'  fail if file already exist (use with 'c')
 *
 *          How must _always_ contain exactly one 'r' or 'w'.
 *          if no ID is given, mode 'wc' is assumed
 *          'w' assumes 'a' unless 't'
 *          't' overrules 'a'
 *
 * @return  On success the ID (>1) -- 0 otherwise
 * @see     Stdio.file
 * @author Ludger Merkens 
 */

int open(int ID, string mode) {
    sMode = mode;
    iID = ID;
    Sql.sql_result odbResult;    //	db = iID >> OID_BITS;
    
    if (!iID)
        sMode = "wc";
    [fdb, iID] = get_database_handle(iID);

    //    LOG("opened db_file for mode "+sMode+" with id "+iID);

    iCurrPos = 0;
    if (search(sMode, "r")!=-1)
    {
        odbResult =
            fdb()->big_query("select min(rec_order), max(rec_order) "+
                             "from doc_data where "+
                             "doc_id ="+iID);
        array res= odbResult->fetch_row();
        iMinRecNbr= (int) res[0];
        iMaxRecNbr= (int) res[1]; // both 0 if FileNotFound
        iNextRecNbr = iMinRecNbr;
        
        odbResult =
            fdb()->big_query("select rec_data from doc_data where doc_id="+iID+
                             " and rec_order="+iMinRecNbr);
        if (odbResult->num_rows()==1)
        {
            [sReadBuf] = odbResult->fetch_row();
            if (strlen(sReadBuf)<MAX_BUFLEN) // we got the complete file
                iFileSize = strlen(sReadBuf);
            else
                iPrefetch = 1;               // otherwise assume prefetching
            iNextRecNbr++;
        }
        
        return ID;
    }
    if (search(sMode, "w")==-1) // neither read nor write mode given
        return 0;

    // Append to database, calculate next RecNbr
    odbResult = fdb()->big_query("select max(rec_order) from "+
                                "doc_data where doc_id = "+iID);
    if (!objectp(odbResult))
        iNextRecNbr = -1;
    else
    {
        iNextRecNbr = ((int) odbResult->fetch_row()[0])+1;
    }
    if (search(sMode, "c")!=-1)
    {
        if ((search(sMode,"x")!=-1) && (iNextRecNbr != -1))
            return 0;
	    
        if (iNextRecNbr == -1)
            iNextRecNbr = 0;
    }

    if (search(sMode, "t")!=-1)
    {
        if (iNextRecNbr!=-1)
            fdb()->big_query("delete from doc_data where doc_id = "+
                            iID);
        iNextRecNbr = 1;
    }

    if (iNextRecNbr == -1) // 'w' without 'c' but file doesn't exist
        return 0;

    return iID;
}
    
private static void write_buf(string data) {
    //        LOG_DB("write_buf: "+strlen(data)+" RecNbr:"+iNextRecNbr);
    string line = "insert into doc_data values(\""+
        fdb()->quote(data)+"\", "+ iID +", "+iNextRecNbr+")";
    mixed c = catch{fdb()->big_query(line);};
    if (c) {
        LOG_DB("write_buf: "+c[0]+"\n"+master()->describe_backtrace(c[1]));
    }
    iMaxRecNbr=iNextRecNbr;
    iNextRecNbr++;
    iFileSize=-1;
}
	
int close() {
    //    LOG("closing db_file"+iID+" from mode "+sMode);
    if (search(sMode,"w")!=-1)
    {
        if (strlen(sWriteBuf) > 0)
            write_buf(sWriteBuf);
        iFileSize = (((iMaxRecNbr - iMinRecNbr)-1) * MAX_BUFLEN) +
            strlen(sWriteBuf);
    }
    if (search(sMode,"r")!=-1)
        stop_reader();
}

void destroy() {
    close();
}
    
string read(int|void nbytes, int|void notall) {
    array(string) lbuf = ({});
    mixed                line;
    int               iSumLen;
    Sql.sql_result    odbData;

    //    LOG("read from:"+iCurrPos+"("+nbytes+"/"+notall+")");
    
    //    LOG("iFileSize:"+iFileSize+" Queue:"+(tReader? "active": "stopped")+
    //        " iPrefetch:"+(iPrefetch?"yes":"no")+" FifoSize:"+ContFifo->size());
    
    if (search(sMode,"r")==-1)
        return 0;
	
    if (!nbytes)               // all the stuff -> no queuing
    {
        odbData = fdb()->big_query("select rec_data from doc_data "+
                                   "where doc_id="+iID+
                                   " order by rec_order");
        
        while (line = odbData->fetch_row())
            lbuf += ({ line[0] });
        return lbuf * "";
    } else
    {
        if (((iFileSize==-1) || (iFileSize> MAX_BUFLEN))
            && !tReader && !ContFifo->size() && iPrefetch)
        {
            //            werror("starting prefetch");
            tReader = Thread.thread_create(read_from_db);
        }
    }

    iSumLen = strlen(sReadBuf);
    lbuf = ({ sReadBuf });
    line ="";
    while ((iSumLen < nbytes) && stringp(line))
    {
        if (ContFifo->size() || tReader) // nowait check for Prefetched Content
        {
            //            LOG("found ContFifoSize to be:"+ContFifo->size());
            line = ContFifo->read();
            //            LOG(sprintf("%O",line));
        }
        else if (iNextRecNbr < iMaxRecNbr) // large files + seek
        {
            iPrefetch = 1;
            tReader = Thread.thread_create(read_from_db);
            line = ContFifo->read();
        }
        else
            line = 0; // small files
        if ( stringp(line) )
        {
            lbuf += ({ line });
            iSumLen += strlen(line);
        }
        if (notall)
            break;
    }
    sReadBuf = lbuf * "";

    //    LOG("sReadBuf("+strlen(sReadBuf)+")");
    if (!strlen(sReadBuf))
        return 0;

    if (strlen(sReadBuf) <= nbytes)  // eof or notall
    {
        line = sReadBuf;
        sReadBuf = "";
        iCurrPos += strlen(line);
        return line;
    }
    line = sReadBuf[..nbytes-1];
    sReadBuf = sReadBuf[nbytes..];
    iCurrPos += strlen(line);
    //    LOG("line("+strlen(line)+")");
    return line;
}

int write(string data) {
    int iWritten = 0;

    if (search(sMode, "w")==-1)
        return -1;

    //    LOG("wrote db_file "+iID+" for "+strlen(data)+" bytes");
    sWriteBuf += data;
    while (strlen(sWriteBuf) >= MAX_BUFLEN)
    {
        write_buf(sWriteBuf[..MAX_BUFLEN-1]);
        sWriteBuf = sWriteBuf[MAX_BUFLEN..];
        iWritten += MAX_BUFLEN;
    }
    iCurrPos += iWritten;
    return iWritten;
}

object stat()
{
    object s = Stdio.Stat();
    s->size = sizeof();
    return s;
}

int sizeof() {

    if (iFileSize!=-1)  // already calculated
        return iFileSize;
	
    Sql.sql_result res;
    int  iLastChunkLen;

    if (search(sMode, "w")!=-1)
    {
        int erg;
        iLastChunkLen = strlen(sWriteBuf);

        erg = ((iMaxRecNbr-iMinRecNbr) * MAX_BUFLEN) + iLastChunkLen;
        //        LOG("calculating sizeof for "+iID+" mode "+sMode+" ("+erg+")");
        return erg;
    }
    else
    {
        res = fdb()->big_query(
            "select length(rec_data) from doc_data "+
            "where doc_id ="+iID+" and rec_order="+iMaxRecNbr);
    
	mixed row = res->fetch_row();
	if ( arrayp(row) )
	    iLastChunkLen = ((int) res->fetch_row()[0]);
	else
	    iLastChunkLen = 0;
    }

    iFileSize = ((iMaxRecNbr-iMinRecNbr) * MAX_BUFLEN) + iLastChunkLen;
    //    LOG("calculating sizeof for "+iID+" mode "+sMode+" ("+iFileSize+")");
    return iFileSize;
}

int dbContID() {
    return iID;
}


private static void stop_reader()
{
    if (tReader)
    {
        iStopReader=1;
        ContFifo->read_array();             // discard prefetch
        mReader = Thread.Mutex()->lock(1);  // make sure reader stopped
    }
}

/**
 * seek in an already open database content to a specific offset
 * If pos is negative it will be relative to the start of the file,
 * otherwise it will be an absolute offset from the start of the file.
 * 
 * @param    int pos - the position as described above
 * @return   The absolute new offset or -1 on failure
 * @see      tell
 *
 * @caveats  The old syntax from Stdio.File->seek with blocks is not
 *           supported
 */

int seek(int pos)
{
    int SeekBlock;
    int SeekPos;
    Sql.sql_result odbResult;
    iPrefetch = 0;

    if (pos<0)
        SeekPos = iCurrPos-SeekPos;
    else
        SeekPos = pos;
    SeekBlock = SeekPos / MAX_BUFLEN;
    SeekBlock += iMinRecNbr;

    stop_reader();  // discard prefetch and stop read_thread
    odbResult = fdb()->big_query("select rec_data from doc_data where doc_id="+
                                 iID+" and rec_order="+SeekBlock);
    if (odbResult->num_rows()==1)
    {
        [sReadBuf] = odbResult->fetch_row();
        sReadBuf = sReadBuf[(SeekPos % iMinRecNbr)..];
        iCurrPos = SeekPos;
        iNextRecNbr = SeekBlock+1;
        return iCurrPos;
    }
    return -1;
}

/**
 * tell the current offset in an already open database content
 * @return   The absolute offset
 */

int tell()
{
    return iCurrPos;
}
