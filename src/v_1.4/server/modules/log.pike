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
inherit "/kernel/module";

#include <database.h>
#include <config.h>
#include <macros.h>
#include <attributes.h>

object oLogDatabase;
object oLogSecurity;
object  oLogLoadErr;
object     oLogBoot;
object    oLogEvent;
object    oLogDebug; 
int     iLogDebug=0;

static     int iRequests;
static mapping mRequests;
static     int iDownload;
static mapping   mMemory;
static mapping  mObjects;

void init_module()
{
    iRequests = 0;
    iDownload = 0;
    mRequests = ([ ]);
    mMemory   = ([ ]);
    mObjects  = ([ ]);

    oLogDatabase = Stdio.File(LOGFILE_DB, "wct");
    oLogSecurity = Stdio.File(LOGFILE_SECURITY, "wct");
    oLogLoadErr  = Stdio.File(LOGFILE_ERROR, "wct");
    oLogBoot     = Stdio.File(LOGFILE_BOOT, "wct");
    oLogEvent    = Stdio.File(LOGFILE_EVENT, "wct");
    oLogDebug    = Stdio.File(LOGFILE_DEBUG, "wct");
#ifdef DEBUG_MEMORY
    call_out(debug_mem, 60);
#endif
}

void debug_mem()
{
    int t = time();
    mMemory[t] = _Server->debug_memory();
    mObjects[t] = master()->get_in_memory();
    mRequests[t] = iRequests;
    call_out(debug_mem, 60);
}

mapping get_memory()
{ 
    return mMemory;
}

mapping get_objects()
{
  return mObjects;
}

mapping get_request_map()
{
  return mRequests;
}

void add_request()
{
  iRequests++;
}


int get_requests()
{
  return iRequests;
}

void add_download(int bytes)
{
  iDownload += bytes;
}

int get_download()
{
  return iDownload;
}

void log_error(string str) 
{
    oLogLoadErr->write("Error on " + ctime(time())+str+"\n");
}

void log_database(string str)
{
    oLogDatabase->write("-"*78+"\n"+backtrace()[-2][0]+" Line:"+
			backtrace()[-2][1]+"\n"+str+"\n");
}

void log_security(string str)
{
    oLogSecurity->write(str+"\n");
}

void log_boot(string str)
{
    oLogBoot->write(str+"\n");
}

void log_event(string str)
{
    oLogEvent->write(str+"\n");
}

void log_debug(string str)
{
    oLogDebug->write(CALLERCLASS+"->"+CALLINGFUNCTION+"()"+"\n"+
		     str+"\n");
}

void set_debug(int on)
{
    iLogDebug = on;
}

string get_identifier() { return "log"; }
