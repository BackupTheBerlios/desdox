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

//! server is the most central part of sTeam, loads and handles factories
//! and modules.
private static object                   nmaster;
private static int                  iLastReboot;
private static object                 oDatabase;
private static mapping       mGlobalBlockEvents;
private static mapping      mGlobalNotifyEvents;
private static mapping                 mConfigs;
private static mapping                 mClasses;
private static mapping                 mModules;
private static mapping                  mErrors;
private static mapping              mReadConfig;
private static mapping              mInitMemory;

#include <config.h>
#include <macros.h>
#include <classes.h>
#include <database.h>
#include <attributes.h>
#include <assert.h>
#include <access.h>
#include <roles.h>
#include <events.h>
#include <functions.h>

#define MOUNT_FILE mConfigs["config-dir"] + "mount.txt"
#define CONFIG_FILE mConfigs["config-dir"] + "config.txt"
#define MODULE_FILE mConfigs["config-dir"] + "modules.txt"

#define MODULE_SECURITY mModules["security"]
#define MODULE_FILEPATH mModules["filepath:tree"]
#define MODULE_GROUPS   mModules["groups"]
#define MODULE_USERS    mModules["users"]
#define MODULE_OBJECTS  mModules["objects"]

string get_identifier() { return "Server Object"; }

private static string sContext;

private static int cb_context(Parser.HTML p, string tag)
{
    if ( tag == "config" || tag == "/config" || tag[0] == '?' )
	return 0;
    tag = p->parse_tag_name(tag);
    if ( tag[0] == '?' )
      return 0;
    tag = tag[1..strlen(tag)-2];
    sContext = tag;
    return 0;
}

private static string cb_context_mount(Parser.HTML p, string tag)
{
    sscanf(tag, "%*sposition=\"%s\"%*s", sContext);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static int read_mount(Parser.HTML p, string data) 
{
    if ( strlen(data) == 0 || data == "\n" )
	return 0;
    MESSAGE("Mounting " + sContext + " on " + data);
    nmaster->mount(sContext, data);
    return 0;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static void read_mounts()
{
    string       content;

    MESSAGE("read_mounts()");
    content = Stdio.read_file(MOUNT_FILE);
    object p = Parser.HTML();
    p->_set_tag_callback(cb_context_mount);
    p->_set_data_callback(read_mount);
    p->feed(content);
    p->finish();
} 



/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static int read_config(Parser.HTML p, string data)
{ 
    int d;

    if ( sContext[0] == '/' ) return 0;
    
    MESSAGE("Configuration: " + sContext + "="+data);
    if ( sscanf(data, "%d", d) == 1 && (string)d == data )
	mConfigs[sContext] = d;
    else
	mConfigs[sContext] = data;
    return 0;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static void read_configs()
{
    string content;

    content = Stdio.read_file(CONFIG_FILE);
    if ( !stringp(content) || strlen(content) == 0 ) {
	content = Stdio.read_file(CONFIG_FILE+".steam");
    }
    object p = Parser.HTML();
    p->_set_tag_callback(cb_context);
    p->_set_data_callback(read_config);
    p->feed(content);
    p->finish();

    if ( !Stdio.exist(CONFIG_FILE+".steam") ) {
	object g = Stdio.File(CONFIG_FILE+".steam", "wct");
	g->write(content); // have config.txt.steam only once
    }
}

/**
 * load configurations from admin group (attribute 'configs')
 *  
 */
private static void load_configs()
{
    mapping confs = ([ ]);
    object  groups, admin;

    groups = mModules["groups"];
    if ( objectp(groups) ) {
	admin = groups->lookup("admin");
	if ( objectp(admin) ) {
	    confs = admin->query_attribute("configs");
	    if ( !mappingp(confs) )
		confs = ([ ]);
	}
	// cleanup unnecessary config parameters
	m_delete(confs, "ip");
	m_delete(confs, "pw");
	m_delete(confs, "root_pw");
	m_delete(confs, "?xm");
	m_delete(confs, "config");
	m_delete(confs, "name");
	m_delete(confs, "root");
	m_delete(confs, "password");
	m_delete(confs, "program_path");
	m_delete(confs, "include_path");
	m_delete(confs, "mysql_admin");
	m_delete(confs, "steam_server");
	m_delete(confs, "username");
	m_delete(confs, "caudium");
	m_delete(confs, "localtion");
	m_delete(confs, "cfg_path");
	m_delete(confs, "config-dir");
	m_delete(confs, "lib_path");
	m_delete(confs, "local_path");
	m_delete(mConfigs, "?xm");
	m_delete(mConfigs, "config");
    }
    if ( confs->installed ) {
	mConfigs = confs | mConfigs;
	save_configs();
    }
    else {
	mConfigs |= confs;
	save_configs();
    }

    MESSAGE("After loadings configs:\n"+sprintf("%O", mConfigs));
    // now make sure config file on disk only contains database string 
    // so its possible to change values on disk.
    mixed err = catch {
	object f = Stdio.File(CONFIG_FILE, "wct");
	f->write("<?xml version='1.0' encoding='iso-8859-1'?>\n");
	f->write("<config>\n<database>"+mConfigs->database+"</database>\n"+
		 "<ip>"+mConfigs->ip+"</ip>\n"+
		 "<machine>"+mConfigs->machine+"</machine>\n"+
		 "<installed>true</installed>\n"+
		 "<port>"+mConfigs->port+"</port>\n"+
		 "<https_port>"+mConfigs->https_port+"</https_port>\n"+
		 "</config>\n");
	f->close();
    };
    if ( err != 0 )
	MESSAGE("Error writting config file !");
}

string get_configs_xml()
{
    string config = "<config>\n";
    foreach ( indices(mConfigs), string cfg ) {
	config += sprintf("<%s>%s</%s>\n", 
			  cfg, (string)mConfigs[cfg], cfg);
    }
    config += "</config>\n";
    return config;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static void save_configs()
{
    object groups = mModules["groups"];
    if ( objectp(groups) ) {
	object admin = groups->lookup("Admin");
	if ( objectp(admin) ) {
	    admin->set_attribute("configs", mConfigs);
	    MESSAGE("Configurations saved.");
	}
    }
	
}

/**
 * Save the modules (additional ones perhaps).
 *  
 */
private static void save_modules()
{
    object groups = mModules["groups"];
    if ( objectp(groups) ) {
	object admin = groups->lookup("Admin");
	if ( objectp(admin) ) {
	    admin->set_attribute("modules", mModules);
	    MESSAGE("Modules saved.");
	}
    }
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void report_undocumented()
{
    return;
    mapping functions = nmaster->get_functions();
    foreach(indices(functions), program prg) {
	foreach(indices(functions[prg]), string func) {
	    string email;
	    mapping description = functions[prg][func][5];
	    
	    if ( description["undescribed"] && stringp(description->author) &&
		 sscanf(description->author,"<a href=\"mailto:%s\">%*s", email)
		 >= 0 ) 
	    {
		array(string) users;
		users = MODULE_USERS->index();
		foreach(users, string u) {
		    object uobj = MODULE_USERS->lookup(u);
		    if ( uobj->query_attribute(USER_EMAIL) == email ) {
			uobj->message(
			    "Your function: "+ func + " in "+ 
			    master()->describe_program(prg) + 
			    " is undocumented !\n");
		    }
		}
	    }
	}
    }
}

/**
 */
static int start_server()
{
    add_module_path("server/libraries");

    mGlobalBlockEvents  = ([ ]);
    mGlobalNotifyEvents = ([ ]);
    mClasses            = ([ ]);
    
    iLastReboot = time();

    Stdio.File f = Stdio.File("documentation.txt", "wct");
    f->close();
  
    nmaster = ((program)"kernel/master.pike")();
    replace_master(nmaster);
    read_configs();
    if ( !stringp(mConfigs->machine) )
	THROW("Configuration parameter <machine> not found, but required !",
	      E_ERROR);
    
    read_mounts();

    add_constant("_Server", this_object());
    add_constant("vartype", nmaster->get_type);
    add_constant("new", nmaster->new);
    add_constant("this_user", nmaster->this_user);
    add_constant("get_type", nmaster->get_type);
    add_constant("get_functions", nmaster->get_functions);
    add_constant("get_dir", nmaster->get_dir);
    add_constant("rm", nmaster->rm);
    add_constant("file_stat", nmaster->file_stat);
    add_constant("get_local_functions", nmaster->get_local_functions);
    add_constant("_exit", shutdown);
    add_constant("call_out", nmaster->f_call_out);
    add_constant("start_thread", nmaster->start_thread);
    add_constant("call_mod", call_module);
    add_constant("get_module", get_module);
    add_constant("get_factory", get_factory);
    add_constant("steam_error", steam_error);
    add_constant("set_this_user", nmaster->set_this_user);

    MESSAGE("Loading Database..."+mConfigs->database);

#if __MINOR__ > 3
    oDatabase = ((program)"database.pike")();
#else
    oDatabase = new("database.pike");
#endif
    
    MESSAGE("Database is "+ master()->describe_object(oDatabase));
    
    add_constant("_Database", oDatabase);
//    add_constant("require_save", oDatabase->require_save);
    add_constant("find_object", oDatabase->find_object);
    add_constant("serialize", oDatabase->serialize);
    add_constant("unserialize", oDatabase->unserialize);
    
    oDatabase->enable_modules();
    MESSAGE("Database module support enabled.");

    nmaster->register_server(this_object());
    nmaster->register_constants();


    mixed err = catch {
	load_modules();
	load_configs();
	load_factories();
	load_modules_db();
	load_objects();
	load_programs();
    };
    if ( err != 0 )
	MESSAGE(err[0] + "\n"+sprintf("%O\n", err));
    
    install_modules();
        
    MESSAGE("Initializing objects.... " + (time()-iLastReboot) + "seconds");
    iLastReboot = time();
    MESSAGE("Setting defaults... " + (time()-iLastReboot) + "seconds");

    open_ports();
    iLastReboot = time();
    report_undocumented();
    // check if root-room is ok...
    ASSERTINFO(objectp(MODULE_OBJECTS->lookup("rootroom")), 
	       "Root-Room is null!!!");
    MESSAGE("Server started on " + ctime(time()));

    // load debug and threads modules
    mInitMemory = Debug.memory_usage();
    Thread.all_threads();
    
    nmaster->run_sandbox();
    return -17;
}

mixed query_config(mixed config)
{
    if ( config == "database" )
	return 0;
    return mConfigs[config];
}

mapping debug_memory(void|mapping debug_old)
{
  mapping dmap = Debug.memory_usage();
  if (!mappingp(debug_old) )
    return dmap;
  foreach(indices(dmap), string idx)
    dmap[idx] = (dmap[idx] - debug_old[idx]);
  return dmap;
}

string debug_bytes(int num)
{
  if ( num < 4096 )
    return num + "b";
  if ( num >= 4096 && num < 1024*1024 )
    return (num/1024)+ "k";
  else
    return (num/(1024*1024))+ "m";
}

string plusminus(int num)
{
  return ( num > 0 ? "+"+num: (string)num);
}

void debug_out(void|mapping debug_old)
{
  mapping dmap = debug_memory(debug_old);
  mapping imap = debug_memory(mInitMemory);
  mapping usage = Debug.memory_usage();
  
  array(string) unin = 
  ({ "num_multisets", "num_callbacks", "num_callables", "num_frames" });

  MESSAGE("------------- MEMORY CHANGE ----------------------------");
  foreach(indices(dmap), string idx) {
    if ( search(idx, "bytes") >= 0 ) continue;
    if ( search(unin, idx) >= 0 ) continue;
    string bid = idx[4..strlen(idx)-2]+"_bytes";

    MESSAGE("%d\t%-10s\t(%s)\tinit:\t%s(%s)\t\tcmd: %s(%s)", 
	    usage[idx], idx[4..], debug_bytes(usage[bid]), 
	    plusminus(imap[idx]), debug_bytes(imap[bid]),
	    plusminus(dmap[idx]), debug_bytes(dmap[bid]));
  }
  
}

string get_database()
{
    MESSAGE("CALLERPRG="+master()->describe_program(CALLERPROGRAM));
    if ( CALLER == oDatabase || 
	 CALLERPROGRAM==(program)"/kernel/steamsocket.pike" )
	return mConfigs["database"];
    MESSAGE("NO ACCESS !!!!!!!!!!!!!!!!!!!!!!!\n\n");
    return "no access";
}

mapping get_configs()
{
    mapping res = copy_value(mConfigs);
    res["database"] = 0;
    return res;
}

mixed get_config(mixed key)
{
    return  mConfigs[key];
}


string get_version()
{
    return STEAM_VERSION;
}

int get_last_reboot()
{
    return iLastReboot;
}

static private void got_kill(int sig)
{
    //configFile->write(get_configs_xml());
    //configFile->close();
    MESSAGE("Shutting down !\n");
    oDatabase->wait_for_db_lock();
    _exit(1);  
}

static private void got_hangup(int sig)
{
    MESSAGE("sTeam: hangup signal received...");
}

mapping get_errors()
{
    return mErrors;
}

void add_error(int t, mixed err)
{
    mErrors[t] = err;
}

int main(int argc, array(string) argv)
{
    MESSAGE("Params:"+sprintf("%O", argv));
    
    mErrors = ([ ]);
    mConfigs = ([ ]);
    int i;
    string path;
    int pid = getpid();

    path = getcwd();

    // check the version
    string ver = version();
    string cver =  Stdio.read_file("version");
    if ( stringp(cver) )
    {
	MESSAGE("sTeam was configured with " + cver);
	if ( cver != ver ) {
	    FATAL("Version mismatch "+
		  "- used Pike version different from configured !");
	    exit(-1);
	}
    }


    string pidfile = path + "/steam.pid";
    
    mConfigs["config-dir"] = "config/";

    for ( i = 1; i < sizeof(argv); i++ ) {
	string cfg, val;
	if ( sscanf(argv[i], "--%s=%s", cfg, val) == 2 ) {
	    int v;
	    
	    if ( cfg == "pid" ) {
		pidfile = val;
	    }
	    else if ( sscanf(val, "%d", v) == 1 )
		mConfigs[cfg] = v;
	    else
		mConfigs[cfg] = val;
	}
	else if ( sscanf(argv[i], "-D%s", cfg) == 1 ) {
	  add_constant(cfg, 1);
	}
    }
    mixed err = catch {
	Stdio.File f=Stdio.File (pidfile,"wac");
	f->write(" " + (string)pid+"\n");
	f->close;
    };
    if ( err != 0 )
	FATAL("There was an error writting the pidfile...\n");
    
    signal(signum("QUIT"), got_kill);
    signal(signum("SIGHUP"), got_hangup);
    signal(signum("SIGINT"), got_hangup);
    return start_server();
}

mixed get_module(string module_id)
{
    object module;
    module = mModules[module_id];
    if ( objectp(module) )
	return module->this();
     return 0;
}

mixed call_module(string module, string func, mixed ... args)
{
    object mod = mModules[module];
    if ( !objectp(mod) ) 
	THROW("Failed to call module "+ module + " - not found.", E_ERROR);
    function f = mod->find_function(func);
    if ( !functionp(f) )
	THROW("Function " + func + " not found inside Module " + module +" !", E_ERROR);
    if ( sizeof(args) == 0 )
	return f();
    return f(@args);
}


mapping get_modules()
{
    return copy_value(mModules);
}

array(object) get_module_objs()
{
    return values(mModules);
}

/**
 * Open all ports of the server.
 * See the /net/port/ Directory for all available ports.
 *  
 */
static void open_ports()
{
    object         port;
    array(string) ports;
    
    
    ports = nmaster->get_dir("/net/port");
    MESSAGE("Opening ports ...");
    for ( int i = sizeof(ports) - 1; i >= 0; i-- ) {
	if ( ports[i][0] == '#' || ports[i][0] == '.' || ports[i][-1] == '~' )
	    continue;
	if ( sscanf(ports[i], "%s.pike", ports[i]) != 1 ) continue;
	port = nmaster->new("/net/port/"+ports[i]);
	if ( !port->open_port() && port->port_required() ) {
	    MESSAGE("Opening required port " + ports[i] + " failed.");
	    exit(1);
	}
	nmaster->register_port(port);
    }
}

int close_port(object p)
{
    if ( _ADMIN->is_member(nmaster->this_user()) ) {
	p->close_port();
	if ( objectp(p) )
	    destruct(p);
	return 1;
    }
    return 0;
}

int restart_port(object p)
{
    if ( _ADMIN->is_member(nmaster->this_user()) ) {
	program prg = object_program(p);
	if ( functionp(p->close_port) )
	    p->close_port();
	if ( objectp(p) )
	    destruct(p);
	p = prg();
	if ( p->open_port() ) 
	    MESSAGE("Port restarted ....");
	else {
	    MESSAGE("Restarting port failed.");
	    return 0;
	}
	nmaster->register_port(p);
	return 1;
    }
    return 0;
}

/**
 * Install all modules of the server.
 *  
 */
void install_modules()
{
    mapping modules = get_modules();
    
    foreach ( indices(modules), string module ) {
	mixed err = catch {
	    modules[module]->runtime_install();
	};
    }
}

/**
 * register a module - can only be called by database !
 *  
 * @param object mod - the module to register
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final void register_module(object mod)
{
    if ( CALLER == oDatabase ) {
	mModules[mod->get_identifier()] = mod;
	save_modules();
    }
}

/**
 * Load a module
 *  
 * @param string mpath - the filename of the module
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static object load_module(string mpath)
{
    if ( sscanf(mpath, "%s.pike", mpath) != 1 )
	return 0;
     MESSAGE("LOADING MODULE:" + mpath);
    /* dont load the module that keeps the list of all modules
     * because it is loaded by database 
     */
    if  ( mpath == "modules" ) 
	return 0;
    
    object module = 0;
    int database_id = oDatabase->get_variable("#"+mpath);
    if ( database_id != 0 )
       module = oDatabase->find_object(database_id);

    if ( objectp(module) ) // we found an already existing one
    {
	if ( objectp(module->get_object()) )
	    mModules[module->get_identifier()] = module;
	else
	    FATAL("Failed to create instance of "+mpath);
    }
    else
    {
	MESSAGE("Creating New instance of "+mpath);
	mixed err = catch {
	    module = nmaster->new("/modules/"+mpath+".pike");
	};
	if ( err != 0 ) {
	    MESSAGE("Error while creating " + mpath + "\n"+
		    err[0] + "\n" + sprintf("%O\n", err[1]));
	}
	err = catch {
	if (objectp(module))
	{
	    if (!functionp(module->this) ) /* check existance of function */
	    {
		MESSAGE("unable to register module \""+mpath+
			"\" it has to inherit /kernel/module or at least "+
			"/classes/Object");
		module = 0;
	    }
	    else
	    {
		oDatabase->set_variable("#"+mpath,
					module->get_object_id());
		module = module->this();
		module->created();
		mModules[module->get_identifier()] = module;
	    }
	  
	}
	};
	if ( err != 0 )
	    MESSAGE("Error registering module:\n"+sprintf("%O", err));
    }

    if (objectp(module)) 
	MESSAGE("Module "+mpath+" alias "+ module->get_identifier()+
		" OID("+module->get_object_id()+
                ( functionp(module->find_function("get_table_name")) ?
                  ") connected with "+module->get_table_name()+"\n" : ")\n"));
    return module;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
void load_modules()
{
    int    i, database_id;
    
    object         module;
    array(string) modules;
    
    mModules = ([]);
    modules = nmaster->get_dir("/modules");
    
    array(string) priority_load = ({ 
	"log.pike", "security.pike", "groups.pike", "objects.pike", 
	"filepath.pike", "message.pike", "mailbox.pike",
	"xml_converter.pike" });
    
    modules -= priority_load;
    modules = priority_load + modules;
    
    for ( i = 0; i < sizeof(modules); i++ ) {
	if ( search(modules[i], "~") >= 0 ) continue;
	if ( modules[i][0] == '#' || modules[i][0] == '.' ) continue;
	// only load pike programms !
	load_module(modules[i]);
    }

    MESSAGE("Loading modules finished...");
}

void load_programs()
{
    string cl;
    array(string) classfiles = nmaster->get_dir("/classes");
    foreach(classfiles, cl) {
	if ( cl[0] == '.' || cl[0] == '#' || search(cl, "~") >= 0 ) continue;

	MESSAGE("Preparing class: " + cl);
	program prg = (program) ("/classes/"+cl);
    }
    classfiles = nmaster->get_dir("/kernel");
    foreach(classfiles, cl) {
	if ( cl[0] == '.' || cl[0] == '#' || search(cl, "~") >= 0 ) continue;

	MESSAGE("Preparing class: " + cl);
	program prg = (program) ("/kernel/"+cl);
    }

}

/**
 * Load all modules from the database ( stored in the admin group )
 *  
 */
static void load_modules_db()
{
    MESSAGE("Loading registered modules from database...");
    mixed err = catch {
	object groups = mModules["groups"];
	if ( objectp(groups) ) {
	    object admin = groups->lookup("Admin");
	    if ( !objectp(admin) )
		return;
	    mapping modules = admin->query_attribute("modules");
	    if ( !mappingp(modules) ) {
		MESSAGE("No additional modules registered yet!");
		return;
	    }
	    // sync modules saved in admin group with already loaded
	    foreach ( indices(modules), string m ) {
		if ( !mModules[m] )
		    mModules[m] = modules[m];
	    }
	}
	MESSAGE("Loading modules from database finished.");
    };
    if ( err != 0 ) 
	FATAL("Loading Modules from Database failed.\n"+sprintf("%O\n",err));
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
void load_factories()
{
    int      i, database_id;
    string     factory_name;
    object          factory;
    object            proxy;
    mixed               err;
    array(string) factories;
    
    factories = nmaster->get_dir("/factories");
    for ( i = sizeof(factories) - 1; i >= 0; i-- ) {
	if ( sscanf(factories[i], "%s.pike", factory_name) == 0 )
	    continue;

	if ( search(factory_name, "~") >= 0 || search(factory_name, "~")>=0 ||
	     search(factory_name, ".") == 0 || search(factory_name,"#")>=0 )
	    continue;

	proxy = MODULE_OBJECTS->lookup(factory_name);
	if ( !objectp(proxy) ) {
	    err = catch {
		factory = nmaster->new("/factories/"+factory_name+".pike", 
				       factory_name);
	    };
	    if ( err != 0 ) {
		MESSAGE("Error while loading factory " + factory_name + "\n"+
			err[0] + sprintf("\n%O\n", err[1]));
		continue;
	    }
	    
	    proxy = factory->this();
            proxy->created();
	    MODULE_OBJECTS->register(factory_name, proxy);
	}
	mClasses[proxy->get_class_id()] = proxy;
        err = catch {
	   proxy->unlock_attribute(OBJ_NAME);
	   proxy->set_attribute(OBJ_NAME, proxy->get_identifier());
	   proxy->lock_attribute(OBJ_NAME);
        };
        if ( err != 0 ) {
            FATAL("There was an error loading a factory...\n"+
		sprintf("%O",err));
        }
    }
    MESSAGE("Loading factories finished...");
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
void load_objects()
{
    object factory, root, room, admin, world, steam, guest, postman;
    int               i;
    string factory_name;
    mapping vars = ([ ]);
    
    
    MESSAGE("steam group...");
    steam = MODULE_GROUPS->lookup("sTeam");
    if ( !objectp(steam) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "sTeam";
	steam = factory->execute(vars);
	ASSERTINFO(objectp(steam), "Failed to create sTeam group!");
	steam->set_attribute(OBJ_DESC, "The group of all sTeam users.");
    }
    add_constant("_GroupAll", steam);
    
    world = MODULE_GROUPS->lookup("Everyone");
    if ( !objectp(world) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "Everyone";
	world = factory->execute(vars);
	ASSERTINFO(objectp(world), "Failed to create world user group!");
	world->set_attribute(
	    OBJ_DESC, "This is the virtual group of all internet users.");
    }
    object hilfe = MODULE_GROUPS->lookup("help");
    if ( !objectp(hilfe) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "help";
	hilfe = factory->execute(vars);
	ASSERTINFO(objectp(hilfe), "Failed to create hilfe group!");
	hilfe->set_attribute(
	    OBJ_DESC, "This is the help group of steam.");
    }
    hilfe->sanction_object(steam, SANCTION_READ|SANCTION_ANNOTATE);

    bool rootnew = false;

    root = MODULE_USERS->lookup("root");
    if ( !objectp(root) ) {
	rootnew = true;
	factory = get_factory(CLASS_USER);
	vars["name"] = "root";
	vars["pw"] = "steam";
	vars["email"] = "";
	vars["fullname"] = "Root User";
	root = factory->execute(vars);
	root->activate_user(factory->get_activation());
	ASSERTINFO(objectp(root), "Failed to create root user !");
	root->set_attribute(
	    OBJ_DESC, "The root user is the first administrator of sTeam.");
     }

    guest = MODULE_USERS->lookup("guest");
    if ( !objectp(guest) ) {
	factory = get_factory(CLASS_USER);
	vars["name"] = "guest";
	vars["pw"] = "guest";
	vars["email"] = "none";
	vars["fullname"] = "Guest";
	guest = factory->execute(vars);
	
	ASSERTINFO(objectp(guest), "Failed to create guest user !");
	guest->activate_user(factory->get_activation());
	steam->remove_member(guest); // guest shouldnt be a member of steam
	guest->sanction_object(world, SANCTION_MOVE); // move around guest
	object guest_wr = guest->query_attribute(USER_WORKROOM);
	guest_wr->sanction_object(guest, SANCTION_READ|SANCTION_INSERT);
	guest->set_attribute(
	    OBJ_DESC, "Guest is the guest user.");
    }
    ASSERTINFO(guest->get_identifier() == "guest", "False name of guest !");

    postman = MODULE_USERS->lookup("postman");
    if ( !objectp(postman) ) 
    {
        factory = get_factory(CLASS_USER);
        vars["name"] = "postman";
        vars["pw"] = Crypto.randomness.pike_random()->read(10); //disable passwd
        vars["email"] = "";
        vars["fullname"] = "Postman";
        postman = factory->execute(vars);

        ASSERTINFO(objectp(postman), "Failed to create postman user !");
        postman->activate_user(factory->get_activation());
        postman->sanction_object(world, SANCTION_MOVE); // move postman around
        object postman_wr = postman->query_attribute(USER_WORKROOM);
        postman_wr->sanction_object(postman, SANCTION_READ|SANCTION_INSERT);
        postman->set_attribute(OBJ_DESC, 
               "The postman delivers emails sent to sTeam from the outside.");
    }
    ASSERTINFO(postman->get_identifier() == "postman", "False name of postman !");


    mixed err = catch {
	 room = MODULE_OBJECTS->lookup("rootroom");
	 if ( !objectp(room) ) {
	     factory = get_factory(CLASS_ROOM);
	     vars["name"] = "root-room";
	     room = factory->execute(vars);
	     ASSERTINFO(objectp(room), "Failed to create root room !");
	     room->sanction_object(steam, SANCTION_READ);
	     ASSERTINFO(MODULE_OBJECTS->register("rootroom", room),
			"Failed to register room !");
	     root->move(room);
	     room->set_attribute(
		 OBJ_DESC, "The root room contains system documents.");
	 }
    };
    guest->move(room);
    postman->move(room);
    root->move(room);
    
    if ( rootnew ) {
	// only create the exit in roots workroom if the user has
	// been just created
	object workroom = root->query_attribute(USER_WORKROOM);
	if ( objectp(workroom) ) {
	    object exittoroot;
	    factory = get_factory(CLASS_EXIT);
	    exittoroot = factory->execute((["name":"root-room",
					   "exit_to":room,]));
	    exittoroot->move(workroom);
	    object f = Stdio.File("config/root_bild.jpg", "r");
	    object icon = get_factory(CLASS_DOCUMENT)->execute(([
		"url":"root_bild.jpg", ]));
	    icon->set_content(f->read());
	    icon->sanction_object(world, SANCTION_READ);
	    root->set_attribute(OBJ_ICON, icon);
	    icon->move(workroom);
	    f->close();
	}
    }
    
    admin = MODULE_GROUPS->lookup("Admin");
    if ( !objectp(admin) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "Admin";
	admin = factory->execute(vars);
	ASSERTINFO(objectp(admin), "Failed to create Admin user group!");
	admin->set_permission(ROLE_ALL_ROLES);
	admin->add_member(root);
	admin->sanction_object(root, SANCTION_ALL);
	admin->set_attribute(
	    OBJ_DESC, "The admin group is the group of administrators.");
    }
    MESSAGE("Permissions for admin group="+admin->get_permission());
    if ( admin->get_permission() != ROLE_ALL_ROLES )
	admin->set_permission(ROLE_ALL_ROLES);
    
    ASSERTINFO(admin->get_permission() == ROLE_ALL_ROLES, 
	       "Wrong permissions for admin group !");

    object groups = MODULE_GROUPS->lookup("PrivGroups");
    if ( !objectp(groups) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "PrivGroups";
	groups = factory->execute(vars);
	ASSERTINFO(objectp(groups), "Failed to create PrivGroups user group!");
	groups->set_attribute(OBJ_DESC, 
			      "The group to create private groups in.");
	groups->sanction_object(_STEAMUSER, SANCTION_INSERT|SANCTION_READ);
	// everyone can add users and groups to that group!
    }
    
    // as soon as the coder group has members, the security is enabled!
    object coders = MODULE_GROUPS->lookup("coder");
    if ( !objectp(coders) ) {
	factory = get_factory(CLASS_GROUP);
	vars["name"] = "coder";
	coders = factory->execute(vars);
	ASSERTINFO(objectp(coders), "Failed to create coder user group!");
	coders->set_attribute(OBJ_DESC, 
			      "The group of people allowed to write scripts.");
	//coders->add_member(root);
    }
	

    object cont = null;
    err = catch { cont = MODULE_FILEPATH->path_to_object("/factories"); };
    if ( arrayp(err) ) MESSAGE(PRINT_BT(err));
    
    if ( !objectp(cont) )
    {
	factory = get_factory(CLASS_CONTAINER);
	vars["name"] = "factories";
	cont = factory->execute(vars);
	ASSERTINFO(objectp(cont),"Failed to create the factories container!");
	cont->set_attribute(OBJ_DESC, "This container is for the factories.");
    }
    ASSERTINFO(objectp(cont), "/factories/ not found");
    cont->move(room);
    
    factory = get_factory(CLASS_USER);
    factory->sanction_object(world, SANCTION_READ|SANCTION_EXECUTE);
    
    for ( i = 31; i >= 0; i-- ) {
	factory = get_factory((1<<i));
	if ( objectp(factory) ) {
	    factory->sanction_object(admin, SANCTION_EXECUTE);
	    if ( objectp(cont) ) 
		factory->move(cont);
	}
    }
    // temporary ?
    get_factory(CLASS_DOCUMENT)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_ROOM)->sanction_object(steam, SANCTION_EXECUTE); 
    get_factory(CLASS_CONTAINER)->sanction_object(steam, SANCTION_EXECUTE); 
    get_factory(CLASS_DOCEXTERN)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_DRAWING)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_LINK)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_EXIT)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_GROUP)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_OBJECT)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_MESSAGEBOARD)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_ENTRY)->sanction_object(steam, SANCTION_EXECUTE);
    get_factory(CLASS_CALENDAR)->sanction_object(steam, SANCTION_EXECUTE);
    
    factory = get_factory(CLASS_MESSAGEBOARD);
    object steamroom = steam->query_attribute(GROUP_WORKROOM);
    object board;
    board = MODULE_OBJECTS->lookup("bugs");
    if ( !objectp(board) ) {
	board = factory->execute((["name":"bugs",
				  "description": "Bugs found inside sTeam",
				  ]));
	board->move(steamroom);
	MODULE_OBJECTS->register("bugs", board);
    }
    board = MODULE_OBJECTS->lookup("ideas");
    if ( !objectp(board) ) {
	board = factory->execute((["name":"ideas",
				  "description": "Ideas about sTeam",
				  ]));
	board->move(steamroom);
	MODULE_OBJECTS->register("ideas", board);
    }
    object home = get_module("home");
    if ( objectp(home) ) {
	home->set_attribute(OBJ_NAME, "home");
	home->move(room);
    }
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
static void f_run_global_event(int event, int phase, object obj, mixed args)
{
    int i, sz;
    mapping m;
    

    if ( phase == PHASE_NOTIFY ) 
	m = mGlobalNotifyEvents;
    else 
	m = mGlobalBlockEvents;
    
    if ( !arrayp(m[event]) ) 
	return;
    foreach(m[event], array cb_data) {
	if ( !arrayp(cb_data) ) continue;
	string fname = cb_data[0];
	object o = cb_data[1];
	
	function f = o->find_function(fname);
	
	if ( functionp(f) && objectp(function_object(f)) )
	    f(obj, @args);
    }
}

/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void run_global_event(int event, int phase, object obj, mixed args)
{
    if ( CALLER->this() != obj ) 
	return;
    f_run_global_event(event, phase, obj, args);
}


/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void 
add_global_event(int event, function callback, int phase)
{
    // FIXME! This should maybe be secured
    object   obj;
    string fname;

    fname = function_name(callback);
    obj   = function_object(callback);
    if ( !objectp(obj) ) 
	THROW("Fatal Error on add_global_event(), no object !", E_ERROR);
    if ( !functionp(obj->this) )
	THROW("Fatal Error on add_global_event(), invalid object !", E_ACCESS);
    obj   = obj->this();
    if ( !objectp(obj) ) 
	THROW("Fatal Error on add_global_event(), no proxy !", E_ERROR);

    if ( phase == PHASE_NOTIFY ) {
	if ( !arrayp(mGlobalNotifyEvents[event]) ) 
	    mGlobalNotifyEvents[event] = ({ });
	mGlobalNotifyEvents[event] += ({ ({ fname, obj }) });
    }
    else {
	if ( !arrayp(mGlobalBlockEvents[event]) ) 
	    mGlobalBlockEvents[event] = ({ });
	mGlobalBlockEvents[event] += ({ ({ fname, obj }) });
    }
}

/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void
remove_global_events()
{
    array(int)         events;
    int                 event;
    function               cb;
    array(function) notifiers;

    events = indices(mGlobalNotifyEvents);
    foreach ( events, event ) {
	notifiers = ({ });
	foreach ( mGlobalNotifyEvents[event], array cb_data ) {
	    if ( cb_data[1] != CALLER->this() )
		notifiers += ({ cb_data });
	}
	mGlobalNotifyEvents[event] = notifiers;
    }
    events = indices(mGlobalBlockEvents);
    foreach ( events, event ) {
	notifiers = ({ });
	foreach ( mGlobalBlockEvents[event], array cb_data ) {
	    if ( cb_data[1] != CALLER )
		notifiers += ({ cb_data });
	}
	mGlobalBlockEvents[event] = notifiers;
    }
}

/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void
shutdown(void|int reboot)
{
    save_configs();
    if ( !_ADMIN->is_member(nmaster->this_user()) )
	THROW("Illegal try to shutdown server!",E_ACCESS);
    MESSAGE("Shutting down !\n");
    oDatabase->wait_for_db_lock();
    if ( !reboot )
	_exit(1);
    _exit(0);
}

/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void set_config(mixed type, mixed val)
{
    MESSAGE("Setting configuration:" + type + "="+val);
    mixed err = catch {
	MODULE_SECURITY->check_access(0, this_object(), 0, 
				      ROLE_WRITE_ALL, false);
    };
    if ( err != 0 ) {
	MESSAGE("Failed to set configuration !");
	return;
    }
    mConfigs[type] = val;
    save_configs();
}


/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
void register_class(int class_id, object factory)
{
    ASSERTINFO(MODULE_SECURITY->check_access(factory, CALLER, 0, 
					     ROLE_REGISTER_CLASSES, false), 
	       "CALLER must be able to register classes !");
    mClasses[class_id] = factory;
}

/**
  *
  *  
  * @param 
  * @return 
  * @author Thomas Bopp (astra@upb.de) 
  * @see 
  */
final object get_factory(int|object|string class_id)
{
    int i, bits;

    if ( stringp(class_id) ) {
	foreach(values(mClasses), object factory) {
	    if ( factory->get_class_name() == class_id )
		return factory;
	}
	return 0;
    }
    if ( objectp(class_id) ) {
	string class_name = 
	    master()->describe_program(object_program(class_id));
	//	MESSAGE("getting factory for "+ class_name);
	if ( sscanf(class_name, "/DB:#%d.%*s", class_id) >= 1 )
	    return oDatabase->find_object(class_id)->get_object();
	class_id = class_id->get_object_class();
    }

    for ( i = 31; i >= 0; i-- ) {
	bits = (1<<i);
	if ( bits <= class_id && bits & class_id ) {
	    if ( objectp(mClasses[bits]) ) {
		return mClasses[bits]->get_object();
	    }
	}    
    }
    return null;
}

/**
  * Check if a given object is the factory of the object class of CALLER.
  *  
  * @param obj - the object to check
  * @return true or false
  * @author Thomas Bopp (astra@upb.de) 
  * @see get_factory
  * @see is_a_factory
  */
bool is_factory(object obj)
{
    object factory;

    //    MESSAGE("server.is_factory"+master()->detailed_describe(CALLER));
    factory = get_factory(CALLER->get_object_class());
    if ( objectp(factory) && factory == obj )
	return true;
    return false;
}

/**
  * Check if a given object is a factory. Factories are trusted objects.
  *  
  * @param obj - the object that might be a factory
  * @return true or false
  * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
  * @see is_factory
  * @see get_factory
  */
bool is_a_factory(object obj)
{
    if ( !functionp(obj->this) )
	return false;
    return (search(values(mClasses), obj->this()) >= 0);

}

/**
  * get all classes and their factories.
  *  
  * @return the mapping of all classes
  * @author Thomas Bopp (astra@upb.de) 
  * @see is_factory
  * @see get_factory
  */
final mapping get_classes()
{
    return copy_value(mClasses);
}

/**
  *
  *  
  * @param 
  * @return 
  * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
  * @see 
  */
array(object) get_factories()
{
    return copy_value(values(mClasses));
}

/**
  *
  *  
  * @param 
  * @return 
  * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
  * @see 
  */
string get_functions_xml(string|program prg) 
{
    string xml = "";
    
    if ( !programp(prg) ) prg = (program)prg;

    if ( prg == 0 )
        return "";


    MESSAGE("Program...");
    xml += "<program>"+master()->describe_program(prg)+"</program>\n";
    mapping cmdMap = nmaster->get_local_functions(prg);
    string prg_name;

    xml += "<inherits>\n";
    foreach(Program.all_inherits(prg), program p) {
	prg_name = master()->describe_program(p);
	if ( stringp(prg_name) )
	    xml += "\t<inherit>"+prg_name+"</inherit>\n";
    }
    xml += "</inherits>\n";

    xml += "<dependents>\n";
    foreach(nmaster->dependents(prg), program p) {
	prg_name = nmaster->describe_program(p);
	xml += "\t<depend>"+prg_name+"</depend>\n";
    }
    xml += "</dependents>\n";
    mixed err = catch {
	if ( mappingp(cmdMap) )
	{
	    foreach(indices(cmdMap), string func) {

		array(mixed) descriptions = cmdMap[func];
		if ( !arrayp(descriptions) ) 
		continue;


		array(string) kw = ({ });
		mixed see = descriptions[_FUNC_ARGS]["see"];
		if ( stringp(see) ) see = ({ see });
		if ( !arrayp(see) ) see = ({ });

		if ( sizeof(descriptions) <= _FUNC_PARAMS || 
		     !arrayp(descriptions[_FUNC_PARAMS]) ) 
		{
		    MESSAGE("Too few descriptions to function " + func);
		    continue;
		}

		kw = descriptions[_FUNC_KEYWORDS] / " "; 

		xml += "\t<function name=\""+func+"\" " +
		"type=\""+(search(kw, "static") >= 0 ? "private":"public")+"\" "+
		">\n";
		xml += "\t\t<synopsis>"+descriptions[_FUNC_SYNOPSIS]+"</synopsis>\n";
		xml += "\t\t<keywords>"+descriptions[_FUNC_KEYWORDS]+"</keywords>\n";
		xml += "\t\t<description>"+descriptions[_FUNC_DESCRIPTION]+
		"</description>\n";
		for ( int i = 0; i < sizeof(descriptions[_FUNC_PARAMS]); i++ ) {
		    xml += "\t\t<argument>"+descriptions[_FUNC_PARAMS][i]+
			"\n\t\t</argument>\n";
		}
		foreach(see, string s) {
		    string path, func;

		    if ( !stringp(s)  ) continue;
		    if ( sscanf(s, "%s.%s", path, func) != 2 )
		    xml += "<see><object/><function>"+s+"</function></see>\n";
		    else
		    xml += "<see><object>"+path+"</object><function>"+
		    func+"</function></see>\n";
		} 

		xml += "<parsed>\n";
		foreach(indices(descriptions[_FUNC_ARGS]), mixed ind) {
		    if ( arrayp(descriptions[_FUNC_ARGS][ind]) ) {
			foreach(descriptions[_FUNC_ARGS][ind], string val ) {
			    xml += "\t\t<"+ind+">"+val+"</"+ind+">\n";
			}
		    }
		    else {
			xml += "\t\t<"+ind+">"+
			    descriptions[_FUNC_ARGS][ind]+"</"+ind+">\n";
		    }

		}
		xml += "</parsed>";
		xml += "\t</function>\n";
	    }
	}
    };
    if ( err != 0 ) {
	MESSAGE("Error: " + err[0] + "\n"+sprintf("%O", err[1]));
    }
    return xml;
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
object get_caller(object obj, mixed bt)
{
    int sz = sizeof(bt);
    object       caller;

    sz -= 3;
    for ( ; sz >= 0; sz-- ) {
	if ( functionp(bt[sz][2]) ) {
	    function f = bt[sz][2];
	    caller = function_object(f);
	    if ( caller != obj ) {
		return caller;
	    }
	}
    }
    return 0;
	
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void mail_password(object user)
{
    string pw = user->get_ticket(time() + 3600); // one hour
    get_module("smtp")->send_mail(user->query_attribute(USER_EMAIL),
				  "You Account Data for sTeam",
				  "Use the following link to login to "+
				  "the server\r\n and change your password "+
				  "within an hour:\r\n"+
				  "https://"+user->get_identifier()+":"+
				  pw+"@"+
				  query_config(CFG_WEBSERVER)+":"+
				  query_config(CFG_WEBPORT_HTTP)+
				  query_config(CFG_WEBMOUNT)+
				  "register/forgot_change.html");
}

mixed steam_error(string msg)
{
    error(msg+"\n");
}

string get_server_name()
{
    return query_config("machine") + "." + query_config("domain");
}

string get_server_url_presentation()
{
    int port = query_config(CFG_WEBPORT_PRESENTATION);
    
    return "http://"+get_server_name()+(port==80?"":":"+port)+"/";
}

string get_server_url_administration()
{
    int port = query_config(CFG_WEBPORT_ADMINISTRATION);
    
    return "https://"+get_server_name()+(port==443?"":":"+port)+"/";
}




int get_object_class() { return 0; }
int get_object_id() { return 0; }
object this() { return this_object(); }
function find_function(string fname) { return this_object()[fname]; }

