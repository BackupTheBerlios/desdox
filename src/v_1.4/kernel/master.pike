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
inherit "/master";

#include <macros.h>
#include <coal.h>
#include <assert.h>
#include <database.h>
#include <attributes.h>
#include <config.h>
#include <exception.h>

#define LMESSAGE(s) if(llog) MESSAGE(s)
#define __DATABASE mConstants["_Database"]
#define MODULE_FILEPATH oServer->get_module("filepath:tree")
#define MODULE_SECURITY   oServer->get_module("security")

#undef MESSAGE_ERR
#define MESSAGE_ERR(x) (oServer->get_module("log")->log_error(x))

//#define MOUNT_TRACE 1

object old_master;// = master();
object first, last, border;
int          llog;
int     iInMemory;

private static Thread.Local db_busy;
#define debug_upgrade 0
#define debug_noncrit 0

#if debug_upgrade
private static Thread.Local log_file;
#endif

private static object       oActiveUser;
private static array(object)    oaPorts;
private static array(program) paSockets;
private static array(object)    oaUsers;
private static mapping       mConstants;
private static mapping          mErrors;
private static object           oServer;
private static mapping       mFunctions;//mapping of functions for each program
private static program         _loading;// object that is currently loaded
private static int           iCacheSize;
private static int             iSwapped;
private static mapping           mPorts;

#ifdef THREAD_READ
private static Thread.Mutex cmd_mutex = Thread.Mutex();
private static object                         oCmdLock;
#endif

void create() 
{
    oaPorts   = ({ });
    paSockets = ({ });
    oaUsers   = ({ });
    mFunctions = ([ ]);
    mErrors = ([ ]);
    mPorts  = ([ ]);

    LMESSAGE("New Master exchange !\n");
    old_master = master();
    object new_master = this_object();

    foreach( indices(old_master), string varname ) {
	catch { new_master[varname] = old_master[varname]; };
    }
    oActiveUser = thread_local();
    db_busy = Thread.Local();

#if debug_upgrade
    log_file = Thread.Local();
#endif
    
    oServer = 0;
}


string stupid_describe(mixed d, int l)
{
    return sprintf("%O", d);
}

void insert(object proxy)
{
    mixed err = catch {
        proxy["oNext"] = first;
        proxy["oPrev"] = 0;
        if (!first)
            last = proxy;
        else
            first["oPrev"] = proxy;
        first = proxy;
    };
    if ( err != 0 )
	MESSAGE("Failed to insert proxy:\n"+sprintf("%O\n", err));
}

void remove(object proxy)
{
    if (proxy == first)
	first = proxy["oNext"];
    else
	proxy["oPrev"]["oNext"] = proxy["oNext"];

    if (proxy == last)
	last = proxy["oPrev"];
    else
	proxy["oNext"]["oPrev"] = proxy["oPrev"];
    proxy["oNext"] = 0;
    proxy["oPrev"] = 0;
}

void front(object proxy)
{
    if (first!=proxy)
    {
	if (!proxy["oNext"] && !proxy["oPrev"])
	    insert(proxy);
	else
	{
	    remove(proxy);
	    insert(proxy);
	}
    }
}

void tail(object proxy)
{
    if (last!=proxy)
    {
        if (!proxy["oNext"] && !proxy["oPrev"])
            append(proxy);
        else
        {
            if (border==proxy)
                border = proxy["oPrev"];
            remove(proxy);
            append(proxy);
        }
    }
}

void got_loaded(object proxy)
{
    object oDrop;
    iInMemory++;
    front(proxy);
    
    if (!iCacheSize)
    {
        object oServer;
        if (oServer = mConstants["_Server"])
            iCacheSize = oServer->get_config("cachesize");
    }
    if (iInMemory > (iCacheSize < 1000 ? 1000: iCacheSize))
    {
        if (!border)
            border = last;
        while (border->status() <= 0)
            border = border["oPrev"];
        oDrop = border;
        border = border["oPrev"];
        if (oDrop->status() == PSTAT_SAVE_PENDING)
            mConstants["_Database"]->low_save_object(oDrop);
        //	if ( oDrop->get_access_time() - time() < 600 )
        //	  werror("Access time too new - cannot swap (10 minutes) !\n");
        //      else
        if ( oDrop != proxy && oDrop->check_swap() ) {
	    werror("Loading: "  + proxy->get_identifier() + ", Dropping: "+
		   oDrop->get_identifier()+"\n");
	    oDrop->drop();
	    iSwapped++;
	}
    }
    // werror("OBJECTS in Memory = " + iInMemory + "\n");
}

void got_dropped(object proxy)
{
    iInMemory--;
    tail(proxy);
}

int get_in_memory() {
    return iInMemory;
}

int get_swapped() {
    return iSwapped;
}

void append(object proxy)
{
    mixed err = catch {
        proxy["oNext"]= 0;
        proxy["oPrev"]= last;
        if (!last)
            first = proxy;
        else
            last["oNext"] = proxy;
        last = proxy;
    };
}

array(array(string)) p_list()
{
    array(array(string)) res = ({});
    object proxy = first;
    string name;
    array errres;
    mixed fun;
    
    while (objectp(proxy))
    {
	
	fun=proxy->find_function("query_attribute");
	if (!functionp(fun))
	    name = "---";
	else
	{
	    errres = catch {name = fun(OBJ_NAME);};
	    if (arrayp(errres))
		name = errres[0][0..20];
	    if (!stringp(name))
		name = "***";
	}
	
	res +=
	    ({
		({ (string) proxy->get_object_id(),
		       ( (proxy->status()==1) ? " " +
			 describe_program(object_program(proxy->get_object()))
			       : "on disk" ),
		       (stringp(name) ? name : "empty"),
		       PSTAT(proxy->status())
		       })
		    });
	//	MESSAGE("running through: object "+proxy->get_object_id());
	proxy = proxy["oNext"];
    }
    //    MESSAGE("List done ...");
    return res;
}


array(program) dependents(program p)
{
    program prog;
    string  progName;
    array(program) ret = ({});

    //    write("---"+stupid_describe_comma_list(({p}),2000)+"---\n");
    foreach (indices(programs), progName) {
	prog = programs[progName];
	if ( !programp(prog) )
	    continue;
        //        LOG(progName+":"+
        //sprintf("%O",Program.all_inherits(prog))+"\n");
	if (programp(prog) && search(Program.all_inherits(prog), p)>=0)
	    ret += ({prog});
    }
    //write("\n----------------------------------------\n");
    return ret;
}

array(string) pnames(array(program) progs)
{
    program prog;
    array(string) names = ({});
    foreach (progs, prog) { 
	names += ({ describe_program(prog) });
    }
    return names;
}

/**
 *  class ErrorContainer,
 *  it provides means to catch the messages sent from the pike binary to the
 *  compile_error from master.
 *  ErrorContainer.compile_error is called by compile_error
 *                               if an Instance of ErrorContainer is set
 * 
 *  got_error and got_warning provide the messages sent to the ErrorContainer
 */


class ErrorContainer
{
    string d;
    string errors="", warnings="";

    string get() {
	return errors;
    }
    
    final mixed `[](mixed num) {
         switch ( num ) {
	     case 0:
	          return errors;
             case 1:
	          return ({ });
        }
        return "";
    }

    string get_warnings() {
	return warnings;
    }

    void got_error(string file, int line, string err, int|void is_warning) {
	if (file[..sizeof(d)-1] == d) {
	    file = file[sizeof(d)..];
	}
	if( is_warning)
	    warnings+=
		sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
	else
	    errors +=
		sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
    }
    
    // called from master()->compile_error
    void compile_error(string file, int line, string err) {
	got_error(file, line, "Error: " + err);
    }

    void compile_warning(string file, int line, string err) {
	got_error(file, line, "Warning: " + err, 1);
    }
    
    void create() {
	d = getcwd();
	if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
	    d += "/";
    }
};


object getErrorContainer()
{
    return ErrorContainer();
}

/**
 * clear all broken compilations
 */
void clear_compilation_failures()
{
  foreach (indices (programs), string fname)
    if (!programs[fname]) m_delete (programs, fname);
}

/**
 * upgrade a program and all its instances.
 * @param    program to update
 * @return   -1 Force needed
 * @return   -2 no program passed
 * @return   number of dropped objects
 * @return   error from compile (with backtrace)
 */
int|string upgrade(program p, void|int force)
{

    
    if (!p)
    {
        clear_compilation_failures();
        return -2;
    }
    
    if (p == programs["/kernel/proxy.pike"])
        throw(({"Its impossible to upgrade a proxy object - You have to "+
                "restart the server", backtrace()}));

    clear_compilation_failures();
    array(program) apDependents = dependents(p)+({ p });
    string fname = search(programs, p);


#if debug_upgrade
    int close = 0;
    object f;
    if (f = log_file->get())
        f->write("| running rekursive upgrades ....\n");
    else {
        f = Stdio.File("logs/programs.log", "wct");
        log_file->set(f);
        close = 1;
        // f->write(sprintf("programs:\n%O\n\n", programs));
    }
    
    f->write(sprintf("upgrading program %s (%d)\n", describe_program(p), force));
    foreach(apDependents, program p)
    {
        f->write(search(programs, p)+"\n" );
    }
    f->write(")\n");
#endif
    program tmp;

    ErrorContainer e = ErrorContainer();

#if debug_upgrade
    f->write("(Upgrade) File: " + fname + ", PRG:"+describe_program(p)+"\n");
#endif
   
    m_delete(mErrors, fname);
    set_inhibit_compile_errors(e);
    mixed err = catch{
	tmp = compile_string(master_read_file(fname), fname);
    };
    set_inhibit_compile_errors(0);
    
    if (err!=0) // testcompile otherwise don't drop !
    {

	//	MESSAGE_ERR(ctime(time())+"-"*20+"\n"+err[0]+"\n"+
	//		describe_backtrace(err[1]));
	//	return err[0] + "\n" +describe_backtrace(err[1])+"\n";

#if debug_upgrade
    f->write("after failed compilation (programs) ---\n");
    f->write(sprintf("%O\n",mkmapping(indices(programs), values(programs))));
#endif
#if debug_upgrade
    f->write("-------------------- (resolv_cache) ---\n");
    f->write(sprintf("%O\n",resolv_cache));
#endif
#if debug_upgrade    
    if (close)
        f->close();
#endif

        clear_compilation_failures();
        werror("setting %s for %s\n", e->get(), fname);
        mErrors[fname]= e->get() /"\n";
	return "Failed to compile "+fname+"\n"+
	    e->get() + "\n" +
	    e->get_warnings();
    }
    
    // assume compilation is ok, or do we have to check all dependents ?



    object o = first;
    array aNeedDrop = ({ });

#if debug_upgrade
    f->write("start building droplist\n");
#endif
    
    while ( objectp(o) && o->status )
    {
        if (o->status()>PSTAT_DISK) // if not in memory don't drop
        {

            if ( search(apDependents, object_program(o->get_object())) >= 0 )
            {
#if debug_upgrade
                f->write(" maybe ("+sprintf("%O", o->check_upgrade)+")["+
			 o->check_upgrade()+"]");
#endif
                if (!zero_type(o->check_upgrade) && o->check_upgrade())
                {
#if debug_upgrade
            f->write(sprintf("%O with status (%d)",
                             o->get_object(), o->status()));
#endif
                    aNeedDrop += ({o});
                }
#if debug_upgrade                
		f->write("\n");
#endif
            }
        }
        o = o["oNext"];
    }
    

#if debug_upgrade
    f->write("starting to call sub-upgrades");
#endif
    
    foreach(aNeedDrop, object o)
    {
        if (functionp(o->ugrade))
        {
#if debug_upgrade
            f->write(sprintf("calling upgrade in %O\n", o));
#endif
            o->upgrade();
        }
    }

    sleep(1);
#if debug_noncrit
    f->write("starting to drop objects");
#endif
    
    if (!db_busy->get())
        db_busy->set(__DATABASE->wait_for_db_lock());

    foreach(aNeedDrop, object o)
    {
#if debug_upgrade        
	f->write(sprintf("OBJ: %d status %d",o->get_object_id(), o->status()));
        //   search(programs, object_program(o->get_object())));
#endif        
        int dropped = o->drop();
        
#if debug_upgrade
        f->write((dropped ? " dropped" : " not dropped"));
	f->write(sprintf("OBJ: %d status %d\n",o->get_object_id(), o->status()));
#endif            
    }

#if debug_upgrade
    f->write("\n\n");
#endif
    
    foreach(apDependents, program prg) {
	string pname = search(programs, prg);

#if debug_upgrade
        f->write(sprintf("removing program %s from programs\n", pname));
#endif
	m_delete(programs, pname);

        //        destruct(prg);
    }
    
#if debug_upgrade
    if (close)
        f->close();
#endif

    db_busy->set(0);
    return sizeof(aNeedDrop);
}

void 
register_constants()
{
    mConstants = all_constants();
}

void 
register_server(object s)
{
    if ( !objectp(oServer) )
	oServer = s;
}

object 
get_server()
{
    return oServer;
}

void 
register_user(object u)
{
    int i;
    
    //MESSAGE("register_user("+describe_object(u)+")");
    if ( search(oaPorts, CALLER) == -1 )
	THROW("Caller is not a port object !", E_ACCESS);
    
    for ( i = sizeof(oaUsers) - 1; i >= 0; i-- ) {
	if ( oaUsers[i] == u )
	    return;
        else if ( oaUsers[i]->is_closed() ) {
           destruct(oaUsers[i]); 
        }
    }
    oaUsers -= ({ 0 });
    oaUsers += ({ u });
}

bool is_user(object u)
{
    int i;
    for ( i = sizeof(oaUsers) - 1; i >= 0; i-- ) {
	if ( oaUsers[i] == u )
	    return true;
    }
    return false;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
int set_this_user(object obj)
{
    program prg;

#ifdef THREAD_READ
    if ( obj == 0 ) {
	oActiveUser->set(0);
	if ( objectp(oCmdLock) )
	    destruct(oCmdLock); // unlocked again
	return 1;
    }
#endif

    if ( !is_user(CALLER) || (objectp(obj) && !is_user(obj)) ) {
	MESSAGE("failed to set active user...("+describe_object(obj)+")");
	MESSAGE("CALLER: " + describe_object(CALLER));
	foreach(oaUsers, object u) {
	    MESSAGE("User:"+describe_object(u));
	}
	error("Failed to set active user!\n");
	return 0;
    }

#ifdef THREAD_READ
    oCmdLock = cmd_mutex->lock();
#endif
    if ( objectp(obj) ) {
	oActiveUser->set(obj); // use proxy 
    }
    else {
	oActiveUser->set(0);
    }
    return 1;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
object
this_user()
{
    if ( !objectp(oActiveUser) ) return 0;

    object tu = oActiveUser->get();
    if ( !objectp(tu) )
	return 0;
    return tu->get_user_object();
}

void
register_port(object s)
{
    if ( CALLER == oServer ) {
	oaPorts += ({ s });
	paSockets += ({ s->get_socket_program() });
    }
}

array(object) get_ports()
{
  oaPorts -= ({ 0 }); 
  return oaPorts;
}

object get_port(string name)
{
  foreach(oaPorts, object port )
    if ( objectp(port) && port->get_port_name() == name )
      return port;
  return 0;
}

array(object) get_users()
{
    return copy_value(oaUsers);
}


/**
 * bool
 * system_object(object obj)
 * {
 *    program prg;
 *
 *   if ( obj == mConstants["_Security"] || obj == mConstants["_Database"] )
 *	return true;
 *   if ( is_user(obj) )
 *	return true;
 *   prg = object_program(obj);
 *   if ( prg == (program)"classes/object.pike" ||
 *	 prg == (program)"classes/container.pike" ||
 *	 prg == (program)"classes/exit.pike" ||
 *	 prg == (program)"classes/room.pike" ||
 *	 prg == (program)"classes/user.pike" ||
 *	 prg == (program)"classes/group.pike" ||
 *	 prg == (program)"proxy.pike" ||
 *       prg == (program)"/home/steam/pikeserver/kernel/steamsocket.pike" )
 *	return true;
 *   return false;
 * }
 */

mixed parse_URL_TYPE(string f)
{
    string path;
    int id;
    string ext;

    if ( sscanf(f, "/DB:%s", path) > 0 ) // its db
    {
        if (sscanf(path, "#%d.%s", id, ext))
        {
            if (ext=="pike")
                return ({ URLTYPE_DB, id });
            else
                return ({ URLTYPE_DBO, id });
        } else
            return ({ URLTYPE_DBFT, path });
    }
    return ({URLTYPE_FS,0});
}

/*
 * void
 * register_system_program(program prg) 
 * {
 *   if ( CALLER ==  mConstants["_Database"] )
 *	;
 * }
 */

#if 1

array(array(string)) mount_points;

int mount(string source, string dest)
{
    // make sure we have proper prefixes
    if (source[strlen(source)-1]!='/')  
	source += "/";                  
    if (dest[strlen(dest)-1]!='/')
	dest += "/";

    if (source == "/")
	set_root(dest);
    // insert them according to strlen
    int i;
    if (!arrayp(mount_points))
	mount_points = ({ ({ source, dest }) });
    else
    {
	i = 0;
	while( i < sizeof(mount_points) &&
	       (strlen(mount_points[i][0])<strlen(source)))
	{
	    i++;
	}
	
	mount_points= mount_points[..i-1] +
	    ({({ source, dest })}) +
	    mount_points[i..];
    }
}

//! Run the server in a chroot environment
void run_sandbox()
{
  function change_root, switch_user;
#if constant(System)
  change_root= System.chroot;
  switch_user= System.setuid;
#else
  change_root = chroot;
  switch_user = setuid;
#endif

  // try to copy files first
  mkdir("server/etc");
  Stdio.write_file("server/etc/resolv.conf",
		   Stdio.read_file("/etc/resolv.conf"));
#if 0
  mixed err = catch {
      mkdir("server/var");
      mkdir("server/var/run");
      mkdir("server/var/run/mysqld");
      Stdio.cp("/var/run/mysqld/mysqld.sock", 
	       "server/var/run/mysqld/mysqld.sock");
  };
#endif

  if ( change_root(getcwd()+"/server") ) {
        werror("Running in chroot environment...\n");
	object dir = Stdio.File("/etc","r");
	if ( !objectp(dir) )
	    error("Failed to find etc/ directory - aborting !");

	array system_users = get_all_users();
	foreach(system_users, array user_info) {
	    if ( arrayp(user_info) && sizeof(user_info) > 3 ) {
		if ( user_info[0] == "steam" ) {
		    if ( switch_user(user_info[2]) ) {
			werror("Switched to user steam ["+user_info[2]+"]\n");
		    }
		}
	    }
	}
	mount_points = ({ ({ "/", "/" }), ({ "/include", "/include" }) });
	pike_include_path += ({ "/include" });
	pike_module_path += ({ "/libraries" });
    }
}


string apply_mount_points(string orig)
{

    int i;
    string res;
    
    if (!arrayp(mount_points))
	return orig;

    if (orig[0]!='/' && orig[0]!='#')
	orig = "/"+orig;
    res = orig;
    for (i=sizeof(mount_points);i--;)
	if (search(orig, mount_points[i][0]) == 0)
	{
	    res= mount_points[i][1]+orig[strlen(mount_points[i][0])..];
	    break;
	}
    return res;
}

object master_file_stat(string x)
{
    object       p;
    int    TypeURL;
    mixed    path;

#ifdef MOUNT_TRACE
    werror("[master_file_stat("+x+") ->");
#endif
    [TypeURL, path] = parse_URL_TYPE(x);
    switch (TypeURL)
    {
      case  URLTYPE_FS:
	  x = apply_mount_points(x);
#ifdef MOUNT_TRACE
          werror("fs("+x+")\n");
#endif
	  return ::master_file_stat(x);
      case URLTYPE_DB:
	  //MESSAGE("stat says db:"+path + "on master_file_stat("+x+")");
#ifdef MOUNT_TRACE
          werror(sprintf("db(%d)]\n",path));
#endif
          p = __DATABASE->find_object(path);
          if (objectp(p))
              return p->stat();
      case URLTYPE_DBO:
#ifdef MOUNT_TRACE
          werror(sprintf("dbo(%d)]\n",path));
#endif
          return 0;
      case URLTYPE_DBFT:
#ifdef MOUNT_TRACE
          werror(sprintf("dbft(%s)]\n", path));
#endif
          p = MODULE_FILEPATH->path_to_object(path);
	  if (objectp(p)) 
	      return p->stat();
    }
    return 0;
}


private static void
doc_describe_function(string func, string synopsis, string keywords,
		  string desc, mapping descriptions)
{
    array args, nargs;
    int            sz;
    
//    MESSAGE(sprintf("Description:%O\n", descriptions));
    if ( !mappingp(mFunctions[_loading]) )
	mFunctions[_loading] = ([ ]);

    if ( descriptions["param"] == 0 )
	args = ({ });
    else if ( stringp(descriptions["param"]) )
	args = ({ descriptions["param"] });
    else
	args = descriptions["param"];
    
    nargs = ({ });
    for ( int i = sizeof(args) - 1; i >= 0; i-- ) {
	if ( stringp(args[i]) && search(args[i], " - ") >= 0 )
	    nargs += ({ args[i] });
    }
    if ( !stringp(desc) || strlen(desc) < 10 ) {
	Stdio.File f = Stdio.File("documentation.txt", "wa");
	f->write("The function " + func + " is undocumented ("+describe_program(_loading)+")\n");
	f->close();
	desc = "*** This function is undocumented :( ****";
	descriptions["undescribed"] = true;
    }
    sz = sizeof(nargs);
    m_delete(descriptions, "param");
    mFunctions[_loading][func] = ({ sz, synopsis, keywords, desc, nargs,
				    descriptions });
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
mapping
get_local_functions(program prg)
{
    mapping functions;
    functions = copy_value(mFunctions[prg]);
    return functions;
}

mapping
get_functions(void|object|program obj)
{
    mapping functions;
    program       prg;

    if ( programp(obj) )
	prg = obj;
    else if ( objectp(obj) ) {
	if ( MODULE_SECURITY->valid_proxy(obj) )
	    obj = obj->get_object();
	prg = object_program(obj);
    }
    else {
	return copy_value(mFunctions);
    }
    //ASSERTINFO(mappingp(mFunctions[prg]),
    //"No function index of " + stupid_describe(obj, 255));
    functions = copy_value(mFunctions[prg]);
    foreach(Program.all_inherits(prg), program p) {
	//ASSERTINFO(mappingp(mFunctions[p]), "no function index of " +
	//stupid_describe(p, 255));
	if ( mappingp(mFunctions[p]) )
	    functions += copy_value(mFunctions[p]);
    }
    return functions;
}

array(program) 
get_programs()
{
    array(program) prgs;
    int               i;
    
    prgs = ({ });
    foreach(indices(mFunctions), program prg) {
	prgs += ({ prg });
    }
    return prgs;
}

/**
 * Access the program pointer currently registered for programname
 *
 * @param   string pname - the program to look up
 * @return  program      - the associated program
 * @see     upgrade, new
 * @author Ludger Merkens 
 */
program lookup_program(string pname)
{
    return programs[pname];
}

program compile_file(string file,
                     object|void handler,
                     void|program p,
                     void|object o)
{
    int    TypeURL;
    string    path;
    string content;
    object     tmp;
 
    llog = 0;
    LMESSAGE("compile_file("+file+")");
    [ TypeURL, path ] = parse_URL_TYPE(file);
    
    switch (TypeURL)
    {
      case URLTYPE_FS:
          file = apply_mount_points(file);
          tmp = Stdio.File(file, "r");
          content = tmp->read();
          tmp->close();
          break;
          //return ::compile_file(file);
      case URLTYPE_DBO: 
          return 0;       // dump files not supported in database
      case URLTYPE_DB:
          tmp = __DATABASE->find_object((int)path);
          LOG("DB:compile("+file+")["+tmp->get_identifier()+"]");
          content = tmp->get_source_code();
          break;
      case URLTYPE_DBFT:
          tmp = MODULE_FILEPATH->path_to_object(path);
          MESSAGE("DB:compile("+file+")["+tmp->get_identifier()+"}");
          content = tmp->get_source_code();
          break;
    }
    if (objectp(tmp)) {
        program _loading;
	if ( !stringp(content) || strlen(content) == 0 ) {
            FATAL("No content of file to compile...\n");
            return 0;
	}
        //	_loading = compile(cpp(content, file));	
        if ( stringp(file) )
            m_delete(mErrors, file);
#if (__MINOR__ > 2) 
        _loading= compile(cpp(content,
                              file,
                              1,
                              handler,
                              compat_major,
                              compat_minor),
                          handler,
                          compat_major,
                          compat_minor,
                          p,
                          o);
#endif
#if (__MINOR__ ==2)
        _loading =
            compile(cpp(content, file, 1,
                    handler, compat_major, compat_minor),
            handler, compat_major, compat_minor);
#endif

	return _loading;
    }
    llog = 0;
    throw(({"Cant resolve filename\n", backtrace()}));
}

/*object cast_to_object(string oname, string current_file)
{
    MESSAGE("cast_to_object ("+oname+","+current_file+")");
    return ::cast_to_object(oname, current_file);
}
*/


program cast_to_program(string pname, string current_file)
{
    // MESSAGE("cast_to_program ("+pname+","+current_file+")");
    if ( search(pname, "/DB:") == 0 ) {
	program p = lookup_program(pname[4..]);
	if ( programp(p) ) return p;
    }
    return ::cast_to_program(pname, current_file);
}


mixed resolv(string symbol, string filename, object handler)
{
    if (symbol != "Slotter")
        return ::resolv(symbol,filename, handler);

#ifdef MOUNT_TRACE
    werror("[resolve("+symbol+","+filename+sprintf(",%O)\n",handler));
#endif

    mixed erg=::resolv(symbol, filename, handler);

#ifdef MOUNT_TRACE
    werror("[resolve returns:"+sprintf("%O\n",erg));
#endif
    return erg;
}

string id_from_dbpath(string db_path)
{
    int   type_URL;
    string   _path;
    
    [type_URL, _path] = parse_URL_TYPE(db_path);
    if (type_URL == URLTYPE_DB)
    {
	if (search(_path,"#")==0)
	    return _path;
	else
	{
	    object p;
	    p = MODULE_FILEPATH->path_to_object(db_path);
	    if(objectp(p))
		return "#"+ p->get_object_id();
	    return 0;
	}
    }
    return db_path;
}

mapping get_errors()
{
    return mErrors;
}

array get_error(string file)
{
    if (mErrors[file])
        return ({ file+"\n" }) + mErrors[file];
    else
        return 0;
}

void compile_error(string file, int line, string err)
{ 
    if ( !arrayp(mErrors[file]) )
	mErrors[file] = ({ });
    mErrors[file] += ({ sprintf("%s:%s\n", line?(string)line:"-",err) });
    ::compile_error(file, line, err);
}

string handle_include(string f, string current_file, int local_include)
{
    array(string) tmp;
    string path;

    if(local_include)
    {
	tmp=current_file/"/";
	tmp[-1]=f;
	path=combine_path_with_cwd((tmp*"/"));
	if (parse_URL_TYPE(path)[0] == URLTYPE_DB)
	    path = id_from_dbpath(path);
    }
    else
    {
	foreach(pike_include_path, path) {
	    path=combine_path(path,f);
	    if (parse_URL_TYPE(path)[0] == URLTYPE_DB)
		path = id_from_dbpath(path);
	    else
		if(master_file_stat(path))
		    break;
		else
		    path=0;
	}
    }
    
    return path;

}
    

string read_include(string f)
{
    llog = 0;
    LMESSAGE("read_include("+f+")");
    llog = 0;
    if (search(f,"#")==0) // #include <%45>
    {
	object p;
	p = mConstants["_Database"]->find_object((int)f[1..]);
	//p = find_object((int)f[1..]);
	if (objectp(p))
	    return p->get_source_code();
	return 0;
    }
    return ::read_include(apply_mount_points(f));
}

#endif

int
get_type(mixed var)
{
    if ( intp(var) )
	return CMD_TYPE_INT;
    else if ( stringp(var) )
	return CMD_TYPE_STRING;
    else if ( objectp(var) )
	return CMD_TYPE_OBJECT;
    else if ( floatp(var) )
	return CMD_TYPE_FLOAT;
    else if ( arrayp(var) )
	return CMD_TYPE_ARRAY;
    else if ( mappingp(var) )
	return CMD_TYPE_MAPPING;
    else if ( functionp(var) )
	return CMD_TYPE_FUNCTION;
    return CMD_TYPE_UNKNOWN;
}

string sRoot;
void set_root(string root)
{
    sRoot = root;
}

/** most probably never used **/
string get_cwd()
{
    if (sRoot)
	return "/";
    return predef::getcwd();
}
/**/

string dirname(string x)
{
    if ((stringp(sRoot)) && search(x, sRoot)==0)
	return dirname(x[strlen(sRoot)..]);
    return ::dirname(x);
}

//string master_read_file(string file)
//{
//    LMESSAGE("master_read_file("+file+")");
//    return ::master_read_file(file);
//}

string master_read_file(string file)
{
    int TypeURL;
    string path;
    mixed p;

#ifdef MOUNT_TRACE    
    werror("master_read_file("+file+")");
#endif
    
    [TypeURL, path ] = parse_URL_TYPE(file);
    //MESSAGE("master_read_file("+file+")");
    switch (TypeURL)
    {
      case URLTYPE_FS:
	  //MESSAGE("calling compile_file("+file+")");
	  file = apply_mount_points(file);
#ifdef MOUNT_TRACE
          werror("-->"+file+"\n");
#endif
	  return ::master_read_file(file);
	  //return ::compile_file(file);
      case URLTYPE_DB:
#ifdef MOUNT_TRACE
          werror(sprintf("db(%s)\n",path));
#endif
          p = __DATABASE->find_object((int)path);
          if (p==1)
              throw(({"sourcefile deleted", backtrace()}));
          else
              if (!objectp(p))
                  throw(({"failed to load sourcefile", backtrace()}));
	  return p->get_source_code();
      case URLTYPE_DBO:
#ifdef MOUNT_TRACE
          werror(sprintf("db(%s)\n",path));
#endif
          return 0;
      case URLTYPE_DBFT:
#ifdef MOUNT_TRACE
          werror(sprintf("db(%s)\n",path));
#endif
          p = MODULE_FILEPATH->path_to_object(path);
          return p->get_source_code();
    }
    throw(({"Failed to load file"+file, backtrace()}));
}

/*object findmodule(string fullname)
{
    object o;
    llog = 0;
    LMESSAGE("findmodule("+fullname+", called by " + describe_object(CALLER));
    o=::findmodule(fullname);
    llog = 0;
    return o;
}
*/

string describe_mapping(mapping m, int maxlen)
{
    mixed keys = indices(m);
    mixed values = values(m);
    string out= "";
    for (int i=0;i<sizeof(keys);i++)
    {
	out += stupid_describe(keys[i], maxlen) +
	    ":" + detailed_describe(values[i], maxlen)
	    + (i<sizeof(keys)-1 ? "," :"");
    }
    return out;
}

string describe_array(array a, int maxlen)
{
    string out="";
    for (int i=0;i<sizeof(a);i++)
    {
	out += detailed_describe(a[i], maxlen) + (i<sizeof(a)-1 ? "," :"");
    }
    return out;
}

string describe_multiset(multiset m, int maxlen)
{
    mixed keys = indices(m);
    string out= "";
    for (int i=0;i<sizeof(keys);i++)
    {
	out += stupid_describe(keys[i], maxlen) + (i<sizeof(keys)-1 ? "," :"");
    }
    return out;
}

string detailed_describe(mixed m, int maxlen)
{
    if (maxlen == 0)
	maxlen = 2000;
    string typ;
    if (catch (typ=sprintf("%t",m)))
	typ = "object";		// Object with a broken _sprintf(), probably.
    switch(typ)
    {
      case "int":
      case "float":
	  return (string)m;
	  
      case "string":
	  if(sizeof(m) < maxlen)
	  {
	      string t = sprintf("%O", m);
	      if (sizeof(t) < (maxlen + 2)) {
		  return t;
	      }
	      t = 0;
	  }
	  if(maxlen>10)
	  {
	      return sprintf("%O+[%d]",m[..maxlen-5],sizeof(m)-(maxlen-5));
	  }else{
	      return "string["+sizeof(m)+"]";
	  }
      
      case "array":
	  if(!sizeof(m)) return "({})";
	  return "({" + describe_array(m,maxlen-2) +"})";
      
      case "mapping":
	  if(!sizeof(m)) return "([])";
	  return "([" + describe_mapping(m, maxlen-2) + "])";

      case "multiset":
	  if(!sizeof(m)) return "(<>)";
	  return "(<" + describe_multiset(m, maxlen-2) + ">)";
	  return "multiset["+sizeof(m)+"]";
      
      case "function":
	  if(string tmp=describe_program(m)) return tmp;
	  if(object o=function_object(m))
	      return (describe_object(o)||"")+"->"+function_name(m);
	  else {
	      string tmp;
	      if (catch (tmp = function_name(m)))
		  // The function object has probably been destructed.
		  return "function";
	      return tmp || "function";
	  }

      case "program":
	  if(string tmp=describe_program(m)) return tmp;
	  return typ;

      default:
	  if (objectp(m))
	      if(string tmp=describe_object(m)) return tmp;
	  return typ;
    }
}

/**
 * perform the call-out, but save the previous user-object
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
static void f_call(function f, object user, array(mixed) args)
{
    mixed err;
    object old_user = user;
    
    oActiveUser->set(user);
    err = catch(f(@args));
    oActiveUser->set(old_user);
    if ( err )
      FATAL("Error on call_out:"+sprintf("%O\n", err));
}

/**
 * call a function delayed. The user object is saved.
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
mixed
f_call_out(function f, float|int delay, mixed ... args)
{
    return call_out(f_call, delay, f, oActiveUser->get(), args);
}


/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
array(string) get_dir(string dir)
{
    string fdir = apply_mount_points(dir);
    //    MESSAGE("Getting dir of " + fdir);
    return predef::get_dir(fdir);
}


/**
 * This Function is the mount-point aware of the rm command
 * rm removes a file from the filesystem
 *
 * @param string f
 * @return 0 if it fails. Nonero otherwise
 * @author Ludger Merkens (balduin@upb.de)
 * @see get_dir
 * @caveats this command is limited to removing filesystem files
 */
int rm(string f)
{
    string truef = apply_mount_points(f);
    return predef::rm(truef);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
private static void run_thread(function f, object user, mixed ... args)
{
    //    LOG(sprintf("run_thread %O, %O, %d\n",f, user, sizeof(args)));
    oActiveUser->set(user);
    f(@args);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void start_thread(function f, mixed ... args)
{
    //    LOG(sprintf("master.start_thread %O, %d\n", f, sizeof(args)));
    predef::thread_create(run_thread, f, this_user(), @args);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mixed file_stat(string f)
{
    string ff = apply_mount_points(f);
    return predef::file_stat(ff);
}

#if 0
mapping get_ports()
{
    return mPorts;
}

void use_port(int pid)
{
    mPorts[pid] == 1;
}
#endif

int free_port(int pid)
{
    return mPorts[pid] != 1;
}

void dispose_port(int pid)
{
    mPorts[pid] = 0;
}

/**
 * Find out if a given object is a socket (this means it 
 * has to be in the list of sockets.
 *  
 * @param object o - the socket object
 * @return true or false (0 or 1)
 */
int is_socket(object o)
{
    return (search(paSockets, object_program(o)) >= 0  );
}

object this() { return this_object(); }
function find_function(string f) { return this_object()[f]; }

#if (__MINOR__ > 3) // this is a backwards compatibility function
object new(string|program program_file, mixed|void ...args)
{
    return  ((program)program_file)(@args);
}
#endif




