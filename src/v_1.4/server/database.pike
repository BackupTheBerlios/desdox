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
inherit "/base/serialize";
inherit Thread.Mutex : muBusy;
inherit Thread.Mutex : muLowSave;

#include <macros.h>
#include <assert.h>
#include <attributes.h>
#include <database.h>
#include <config.h>
#include <classes.h>
#include <access.h>
#include <roles.h>
#include <events.h>
#include <exception.h>
#include <types.h>

#define MODULE_SECURITY _Server->get_module("security")
#define MODULE_USERS    _Server->get_module("users")

#define PROXY "/kernel/proxy.pike"

private static mapping(int:mapping(string:int))     mCurrMaxID;
private static mapping(int:object  )              mProxyLookup;
private static Thread.Mutex         loadMutex = Thread.Mutex();

private static int                     iCacheID;
private static object                 oSQLCache;
private static object                oSaveQueue;

private static object               oTlDbHandle;
private static object                 oDbHandle;
private static object                tSaveDemon;
private static object            oDemonDbHandle;
private static object                  oModules;
private static mapping(string:object)   mDbMaps;

private static string                   sDbUser;
private static string               sDbPassword;
private static int             idbMappingNaming;

#define DBM_UNDEF   0
#define DBM_ID      1
#define DBM_NAME    2

private static mapping(string:object) oModuleCache;

private static Calendar cal = Calendar.ISO->set_language("german");

//"mysql://sTEAM:sTEAM@localhost/steam")))


class SqlHandle {
    Sql.Sql oHandle;
    private string db_connect;

    void keep() {
        Sql.sql_result res =
            oHandle->big_query("select ob_class, ob_id from objects "+
                               "where ob_id = 13");
        res->fetch_row();
        call_out(keep, 14400); // every 4 hours
    }
    
    void create(string connect) {
        db_connect = connect;
        oHandle = Sql.Sql(db_connect);
        call_out(keep, 14400); // start keeping connection
    }
    
    int|object big_query(object|string q, mixed ... extraargs) {
        Sql.sql_result res;
        mixed err = catch { res=oHandle->big_query(q, @extraargs); };
        if (err)
        {
            FATAL(cal->Second()->format_nice()+
                   " Database Error ("+(string)oHandle->error()+")"+
		    master()->describe_backtrace(backtrace()));
	    throw(err);
        }
        return res;
    }
    
    array(mapping(string:mixed)) query(object|string q, mixed ... extraargs) {
        array(mapping(string:mixed)) res;
        mixed err = catch { res=oHandle->query(q, @extraargs);};
        if (err)
        {
            LOG(cal->Second()->format_nice()+
                   " Database Error("+(string)oHandle->error()+")");
            destruct(oHandle);
            oHandle = Sql.Sql(db_connect);
            res = oHandle->query(q, @extraargs);
            return res;
        }
        return res;
    }
    
    function `->(string fname) {
        switch(fname) {
          case "query": return query;
          case "big_query" : return big_query;
	  default : return oHandle[fname];
        }
    }
    string describe() { return "SqlHandle()"; }
}


/**
 * return a thread-local (valid) db-handle
 *
 * @param  none
 * @return the database handle
 */
private static Sql.sql db()
{
    if (this_thread() == tSaveDemon) // give saveDemon its own handle
	return oDemonDbHandle;

    // everybody else gets the same shared handle
    if (!objectp(oDbHandle))
    {
	oDbHandle = SqlHandle(STEAM_DB_CONNECT);
        if (!validate_db_handle(oDbHandle))
            setup_sTeam_tables(oDbHandle);
    }


    //    LOG(cal->Second()->format_nice()+": database handle requested.");
    return oDbHandle;
}
    
/**
 * mimick object id for serialization etc. 
 * @return  ID_DATABASE from database.h
 * @see    object.get_object_id
 * @author Ludger Merkens 
 */
final int get_object_id()
{
    return ID_DATABASE;
}

private static void db_execute(string db_query)
{
    db()->big_query(db_query);
}

/**
 * demon function to store pending object saves to the database.
 * This function is started as a thread and waits for objects entering
 * a queue to save them to the database.
 *
 * @param  nothing
 * @return void
 * @see    save_object
 * @author Ludger Merkens 
 */
void database_save_demon()
{
    MESSAGE("DATABASE SAVE DEMON ENABLED");
    mixed job;
    object lGuard;
    object lBusy;

    while(1)
    {
	job = oSaveQueue->read();

	if (!lBusy)
	    lBusy = muBusy::lock(); 

	mixed cerr = catch {
            if (objectp(job))
                low_save_object(job);
            else
                if (stringp(job))
                    db_execute(job);
        };
	if (oSaveQueue->size() == 0)
	    destruct(lBusy);

	if (arrayp(cerr))
	    FATAL("/**************** database_save_demon *************/\n"+
		  PRINT_BT(cerr));
    }
    //    LOG_DB("DB_SAVE_DEMON disabled");
}

/**
 * wait_for_db_lock waits until all pending database writes are done, and
 * afterwards aquires the save_demon lock, thus stopping the demon. Destruct
 * the resulting object to release the save demon again.
 *
 * @param nothing
 * @return the key object 
 * @see Thread.Mutex->lock
 * @author Ludger Merkens
 */
object wait_for_db_lock()
{
    return muBusy::lock();
}

/**
 * constructor for database.pike
 * - starts thread to keep objects persistent
 * - enables commands in database
 * @param   none
 * @return  void
 * @author Ludger Merkens 
 */
void create()
{
    //    sDbUser = dbUser;
    //    sDbPassword = dbPassword;
    mProxyLookup = ([ ]);
    mCurrMaxID = ([ ]);
    oSaveQueue = Thread.Queue();
    oTlDbHandle = thread_local();
    mDbMaps = ([]);
}

object enable_modules()
{
    //    oDemonDbHandle = Sql.sql(STEAM_DB_CONNECT);
    oDemonDbHandle = SqlHandle(STEAM_DB_CONNECT);
    if (!validate_db_handle(oDemonDbHandle))
	setup_sTeam_tables(oDemonDbHandle);
    
    tSaveDemon = thread_create(database_save_demon);
    oModules = ((program)"/modules/modules.pike")();
    oModuleCache = ([ "modules": oModules ]);
    return oModules;
}

void register_transient(array(object) obs)
{
    ASSERTINFO(CALLER==MODULE_SECURITY || CALLER== this_object(), 
	       "Invalid CALLER at register_transient()");
    object obj;
    foreach (obs, obj) {
	if (objectp(obj))
	    mProxyLookup[obj->get_object_id()] = obj;
    }
}


/**
 * set_variable is used to store database internal values. e.g. the last
 * object ID, the last document ID, as well as object ID of modules etc.
 * @param name - the name of the variable to store
 * @param int value - the value
 * @author Ludger Merkens
 * @see get_variable
 */
void set_variable(string name, int value)
{
  if(sizeof(db()->query("SELECT var FROM variables WHERE var='"+name+"'"))) 
  {
    db()->big_query("UPDATE variables SET value='"+value+
                    "' WHERE var='"+name+"'" );
  }
  else
  {
    db()->big_query("INSERT into variables values('"+name+"','"+value+"')");
  }
}

/**
 * get_variable reads a value stored by set_variable
 * @param name - the name used by set_variable
 * @returns int - value previously stored under given name
 * @author Ludger Merkens
 * @see set_variable
 */
int get_variable(string name)
{
    object res;
    res = db()->big_query("select value from variables where "+
                          "var ='"+name+"'");
    if (objectp(res) && res->num_rows())
        return (int) res->fetch_row()[0];
    
    return 0;
}
    
/**
 * reads the currently used max ID from the database and given table
 * and increments. for performance reasons this ID is cached.
 * 
 * @param  int       db - database to connect to
 * @param  string table - table to choose
 * @return int          - the calculated ID
 * @see    free_last_db_id
 * @author Ludger Merkens 
 */
private static
int create_new_database_id(string table)
{
    if (!mCurrMaxID[table])
    {
	string          query;
	int            result;
	Sql.sql_result    res;

        result = get_variable(table);
        if (!result)
        {
            switch(table)
            {
              case "doc_data" :
                  query = sprintf("select max(doc_id) from %s",table);
                  res = db()->big_query(query);
                  result = (int) res->fetch_row()[0];
                  break;
              case "objects":
                  query  = sprintf("select max(ob_id) from %s",table);
                  res = db()->big_query(query);
                  result = max((int) res->fetch_row()[0], 1);
            }
        }
        mCurrMaxID[table] = result;
    }
    mCurrMaxID[table] += 1;
    //    MESSAGE("Created new database ID"+(int) mCurrMaxID[table]);
    set_variable(table, mCurrMaxID[table]);
    return mCurrMaxID[table];
}

/**
 * called in case, a newly created database id is obsolete,
 * usually called to handle an error occuring in further handling
 *
 * @param  int       db - Database to connect to
 * @param  string table - table choosen
 * @return void
 * @see    create_new_databas_id()
 * @author Ludger Merkens 
 */
void free_last_db_id(string table)
{
    mCurrMaxID[table]--;
}

/**
 * creates a new persistent sTeam object.
 *
 * @param  string prog (the class to clone)
 * @return proxy and id for object
 *         note that proxy creation implies creation of associated object.
 * @see    kernel.proxy.create, register_user
 * @author Ludger Merkens 
 */
mixed new_object()
{
    int         new_db_id;
    string sData, sAccess;
    object p;
    // check for valid object has to be added
    // create database ID

    if (int id = CALLER->get_object_id())
    {
	ASSERTINFO((p=mProxyLookup[id])->get_object_id() == id,
		   "Attempt to reregister object in database!");
	return ({ id, p });
    }

    new_db_id = create_new_database_id("objects");
    p = new(PROXY, new_db_id, CALLER );
    if (!objectp(p->get_object())) // error occured during creation
    {
	free_last_db_id("objects");
	destruct(p);
    }

    // insert the newly created Object into the database
    string prog_name = master()->describe_program(object_program(CALLER));
    Sql.sql_result res = db()->big_query(
	sprintf("insert into objects values(%d,'%s','')",
		new_db_id, prog_name)
	);
    mProxyLookup[new_db_id] = p;       
    save_object(p);
    //    LOG("database.new_object: newly created object is:"+new_db_id);
    return ({ new_db_id, p});
}

/**
 * permanently destroys an object from the database.
 * @param  object represented by (proxy) to delete
 * @return (0|1)
 * @see    new_object
 * @author Ludger Merkens 
 */
bool delete_object(object p)
{
    if ( !MODULE_SECURITY->valid_object(CALLER) || CALLER->this() != p->this())
	THROW("Illegal call to database.delete_object", E_ACCESS);
    
    return do_delete(p);
}

private bool do_delete(object p)
{
    object proxy;
    int iOID = p->get_object_id();
    db()->big_query("delete from objects where ob_id = "+iOID);
    proxy = mProxyLookup[iOID];
    m_delete(mProxyLookup, iOID);
    //destruct(proxy);
    //proxy->drop();
    //proxy->set_status(PSTAT_FAIL_DELETED);
    return 1;
}


/**
 * load and restore values of an object with given Object ID
 * @param   int OID
 * @return  0, object deleted
 * @return  1, object failed to compile
 * @return  2, objects class deleted thus instance deleted
 * @return  the object
 * @see
 * @author Ludger Merkens 
 */
mixed load_object(int iOID)
{
    string      sClass;
    string       sData;
    object           o;
    int              i;
    array(string) inds;
    
    if ( object_program(CALLER) != (program)PROXY ) 
	THROW("Security Violation - caller not a proxy object ! ("+
	      CALLERCLASS+")", E_ACCESS);

        
    mixed catched;
    
    Sql.sql_result res = db()->big_query(
	sprintf("select ob_class, ob_data from objects where ob_id = %d",
		iOID) );
    
    mixed line = res->fetch_row();
    while (res->fetch_row());
    destruct(res);
    
    if ( !arrayp(line) || sizeof(line)!=2 ) {
	LOG_DB(PRINT_BT(
	    ({"database.load_object: Failed to load Object("+iOID+")"+
		  (arrayp(line) ? sizeof(line) : "- not found" ),
		  backtrace()})));
	return 0;
    }
    
    if (sClass == "-") {
        return 2;
    }
    
    [sClass, sData] = line;

    catched = catch {
	o = new(sClass, CALLER);
    };

    if (!objectp(o)) // somehow failed to load file
    {
        if ( catched ) {
            FATAL("/**** while loading:"+ sClass + "****/\n" +
                PRINT_BT(catched));
	    _Server->add_error(time(), catched);
#if 0
            werror(sprintf("\nthe \"programs\" cache\n%O\n", master()->programs));
            werror(sprintf("\nthe \"resolv cache\"%O\n", master()->resolv_cache));
#endif
	}
        
        FATAL("Failed to create instance - checking for ClassFile:"+sClass);
        if (!master()->master_file_stat(sClass))
        {
            FATAL("You may have stall objects in the database of class:"+
                  sClass);
            //            do_delete(CALLER);
            return 2;
        }
#if 0
        int iURLType;
        string sPath;
        [iURLType,sPath] = master()->parse_URL_TYPE(sClass);
        mixed oClass;
        if (iURLType==URLTYPE_DB)
        {
            FATAL("Classfile is from database - deleted ?");
            if (sPath[0]=='#')
            {
                Sql.sql_result res =
                    db()->big_query("select ob_class, ob_data from objects"+
                                    " where ob_id = "+(int)sPath[1..]);
                if (!objectp(res) || res->num_rows()==0) // classFile deleted
                {
                    FATAL("deleting instance");
                    do_delete(CALLER);
                    return 2;
                }
            }
        } 
#endif            
	return 1; // class exists but failes to compile
    }

    CALLER->set_steam_obj(o);
    mapping mData;
    
    catched = catch {
	mData = unserialize(sData); // second arg is "this_object()"
    };
    if ( catched ) {
	FATAL("While loading ("+iOID+","+sClass+"):\n"+ catched[0] +"\n"+
	      PRINT_BT(catched));
	CALLER->set_status(PSTAT_FAIL_UNSERIALIZE);
	return 0;
    }
    if ( mappingp(mData) ) {
	foreach(indices(mData), line) {
	    catched = catch(o[line](mData[line]));
	    if (arrayp(catched)) {
		FATAL(sprintf("%O\n", catched));
		LOG_ERR("Function:"+line+" on object="+
			master()->describe_object(o)+":\n"+
			PRINT_BT(catched));
		CALLER->set_status(PSTAT_FAIL_UNSERIALIZE);
	    }
	}
    } 

    mixed err = catch { o->loaded(); };
    return o;
}

/**
 * find an object from the global object cache or retreive it from the
 * database.
 *
 * @param  int - iOID ( object ID from object to find ) 
 * @return object (proxy associated with object)
 * @see    load_object
 * @author Ludger Merkens 
 */
final object find_object(int|string iOID)
{
    object p;
    
    if ( stringp(iOID) ) 
	return _Server->get_module("filepath:tree")->path_to_object(iOID);

    if ( !intp(iOID) )
	THROW("Wrong argument to find_object() - expected integer!",E_ERROR);

    if ( iOID == 0 ) return 0;
    if ( iOID == 1 ) return this_object();
    
    if ( objectp(p = mProxyLookup[iOID]) )
	return p;

    Sql.sql_result res =
	db()->big_query(sprintf("select ob_class, ob_data from objects "+
				"where ob_id = %d", iOID));

    if (!objectp(res) || res->num_rows()==0)
    {
        // create an proxy with status deleted
        // keep type information for filtering e.g. removal from database
        // tables
	// LOG_DB("No result on find_object("+iOID+")");
        //        LOG("creating \"deleted\" proxy\n");
        //p = new("/kernel/proxy.pike", iOID);
        //p->set_status(PSTAT_FAIL_DELETED);
        //mProxyLookup[iOID] = p;
	//return p;
        return 0;
    }

    // cache the query for a following load_object.
    iCacheID = iOID;
    if (objectp(oSQLCache))
	destruct(oSQLCache);
    oSQLCache = res;
    
    // create an empty proxy to avoid recursive loading of objects
    p = new(PROXY, iOID);
    mProxyLookup[iOID] = p;
    return p;
}

/**
 * The function is called to set a flag in an object for saving.
 * Additionally the functions triggers the global EVENT_REQ_SAVE event.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see save_object
 */
void require_save()
{
    object proxy = CALLER->this();
    
    _Server->run_global_event(EVENT_REQ_SAVE, PHASE_NOTIFY, this_object(), 
			      ({ proxy }) );
    save_object(proxy);
}


/**
 * callback-function called to indicate that an object has been modified
 * in memory and needs to be saved to the database.
 *
 * @param  object p - (proxy) object to be saved
 * @return void
 * @see    load_object
 * @see    find_object
 * @author Ludger Merkens 
 */
static void save_object(object proxy)
{
    if ( !objectp(proxy) )
	return;

    if (proxy->status() == PSTAT_SAVE_OK)
	proxy->set_status(PSTAT_SAVE_PENDING);

    //    LOG_DB("enqueue:"+proxy->get_object_id()+"("+PSTAT(proxy->status())+")");
    oSaveQueue->write(proxy);
}

/**
 * low level database function to store a given (proxy) object into the
 * database immediately.
 *
 * @param  object proxy - the object to be saved
 * @return void
 * @see    save_object
 * @author Ludger Merkens 
 */
void low_save_object(object p)
{
    mapping mData;
    string  sData;

#if 0
    LOG_DB("low_save_object:"+p->get_object_id()+"("+PSTAT(p->status())+") "+
		(p->status()>0 ? p->get_identifier() : ""));
#endif
    int stat = p->status();
    // saved twice while waiting
    if ( stat == PSTAT_SAVE_OK || stat == PSTAT_DISK )
	return;   // low is local so this will unlock also

    ASSERTINFO(!objectp(MODULE_SECURITY) ||
	       MODULE_SECURITY->valid_object(p),
	       "invalid object in database.save_object");
    Thread.MutexKey low=muLowSave::lock(1);    

    if (p->status() < PSTAT_SAVE_OK)
    {
	
	LOG_DB("a("+ p->get_object_id() +
	       ","+ master()->describe_object(p->get_object())+
	       ", status="+PSTAT(p->status())+")");
	return;
    }
#if 0
    LOG_DB("checking status");
#endif
    if (p->status()!= PSTAT_SAVE_PENDING)
	THROW("Invalid proxy status for object:"+
	      p->get_object_id()+"("+p->status()+")", E_MEMORY);

#if 0
    LOG_DB("preparing save "+p->get_object_id());
#endif
    mapping storage = p->get_data_storage();
    ASSERTINFO(mappingp(storage),
	       "Corrupted data_storage in "+master()->stupid_describe(p));

    
    array(function) fretriever = mappingp(storage) ? indices(storage): ({});
    array(function) frestorer = mappingp(storage) ? values(storage): ({});

    p->set_status(PSTAT_SAVE_OK);
    destruct(low);                    // status set, so unlock
    
    mData = ([ ]);
    for (int i = 0; i<sizeof(fretriever); i++)
	mData[function_name(frestorer[i])] = fretriever[i]();

    sData = serialize(mData);
#if 0
    LOG_DB("iOID="+p->get_object_id()+ctime(time())+"query ahead....");
#endif

    ASSERTINFO(sData && sData!="",
               sprintf("trying to insert empty data into object %d class %s",
                       p->get_object_id(),
                       master()->describe_program(p->get_object())));
    
    mixed error;
    error = catch
    {
	
	db()->big_query(sprintf("update objects set ob_data = '%s' "+
				  "where ob_id = %d", db()->quote(sData),
				  p->get_object_id()));
#if 0
	LOG_DB("iOID="+p->get_object_id()+" identifier: "+
	       p->get_identifier()+"\n"+db()->quote(sData));
#endif
    };
    if (error)
    {
#if 0
	LOG_DB("iOID="+p->get_object_id()+"update failed\n"+error[0]);
#endif
	db()->big_query(sprintf("insert into objects values(%d, '%s', "+
				"'%s', 0)", p->get_object_id(),
				master()->describe_program(p->get_object()),
				db()->quote(sData)));
    }

    // thread runs a global event, so objects can react !
    // be careful though, because this might cause problems with other threads!
    _Server->run_global_event(EVENT_SAVE_OBJECT,PHASE_NOTIFY,this_object(), 
			      ({ p }) );
    
}

/**
 * look up an module from the database via its name
 * e.g.   lookup_module("users");
 *
 * @param  string oname - the persistent name given to the module.
 * @return object       - a proxy-object representing the module.
 * @see    /kernel/db_mapping, /kernel/secure_mapping
 * @author Ludger Merkens 
 */
#if 0
object lookup_module(string oname)
{
    //    LOG("looking up module:"+oname);
    object module;
    module = oModuleCache[oname];
    if (objectp(module))
        return module;
    
    module = oModules->get_value(oname);  // throws if oModules uninitialised
    if (objectp(module))
    {
        oModuleCache[oname]=module;
        return module;
    }
    if (oname != "log")
        LOG("Lookup on " + oname + " failed !!!\n");
    return 0;
}
#endif

/**
 * register an module with its name
 * e.g. register_module("users", new("/modules/users"));
 *
 * @param   string - a unique name to register with this module.
 * @param   object module - the module object to register
 * @param   void|string source - a source directory for package installations 
 * @return  (object-id|0)
 * @see     /kernel/db_mapping, /kernel/secure_mapping
 * @author  Ludger Merkens 
 */
int register_module(string oname, object module, void|string source)
{
    object realObject;
    string version = "";

    LOG(sprintf("register module %s with %O source %O", 
		   oname, module, source));
    if ( CALLER != _Server && 
	 !MODULE_SECURITY->access_register_module(0, CALLER) )
	THROW("Unauthorized call to register_module() !", E_ACCESS);

    object mod;
    int imod = get_variable("#" + oname);
    
    if ( imod > 0 )
    {
	mod = find_object(imod); // get old module
	LOG(sprintf("attempting to get object for module %s", oname));
	if ( objectp(mod) ) {
	    object e = master()->getErrorContainer();
	    master()->inhibit_compile_errors(e);
	    realObject = mod->get_object();
	    master()->inhibit_compile_errors(0);
	    if (!realObject)
	    {
		LOG("failed to compile new instance - throwing");
		THROW("Failed to load module\n"+e->get()+"\n"+
		      e->get_warnings(), backtrace());
	    }
	    LOG(sprintf("module found is %O", realObject));
	}
    }
    if ( objectp(realObject) ) {
	LOG("Found previously registered version of module !");
	if ( objectp(module) && module->get_object() != realObject )
	    THROW("Trying to register a previously registered module.",
		  E_ERROR);
	
	version = realObject->get_version();
	
	mixed erg = master()->upgrade(object_program(realObject));
	LOG(sprintf("upgrade resulted in %O", erg));
	if (!intp(erg) ||  erg<0)
	{
	    if (stringp(erg))
		THROW(erg, backtrace());
	    else
	    {
		LOG("New version of "+oname+" doesn't implement old "+
		    "versions interface");
		master()->upgrade(object_program(mod->get_object()),1);
	    }
	}
	    LOG("Upgrading done !");
	    module = mod;
    }
    else if ( !objectp(module) ) 
    {
	// module is in the /modules directory.
	object e = master()->getErrorContainer();
	master()->inhibit_compile_errors(e);
	module = new("/modules/"+oname+".pike");
	master()->inhibit_compile_errors(0);
	if (!module)
	{
	    LOG("failed to compile new instance - throwing");
	    THROW("Failed to load module\n"+e->get()+"\n"+
		  e->get_warnings(), backtrace());
	}
    }
    
    LOG(sprintf("installing module %s", oname));
    if ( !stringp(source) )
	source = "";
    
    if ( module->get_object_class() & CLASS_PACKAGE ) {
	
	if ( module->install(source, version) == 0 )
	    return 0;
    }    
    _Server->register_module(module);

    _Server->run_global_event(EVENT_REGISTER_MODULE, PHASE_NOTIFY, 
			      this_object(), ({ module }) );
    LOG_DB("event is run");
    if ( objectp(module) ) 
    {
	set_variable("#"+oname, module->get_object_id());
	_Server->register_module(module);
	return module->get_object_id();
    }
    return 0;
}

/**
 * Check if a database handle is connected to a properly setup database.
 *
 * @param   Sql.sql handle - the handle to check
 * @return  true|false
 * @see     setup_sTeam_tables
 * @author  Ludger Merkens 
 */
int validate_db_handle(SqlHandle handle)
{
    multiset tables = (<>);
    array(string) aTables = handle->list_tables();

    foreach(aTables, string table)
	tables[table] = true;
    return tables["objects"] && tables["doc_data"];
}

/**
 * set up the base sTeam tables to create an empty database.
 *
 * @param  none
 * @return (1|0)
 * @author Ludger Merkens 
 */
int setup_sTeam_tables(SqlHandle handle)
{
    /* make sure no old tables exist and delete them properly */
    LOG("CHECKING for old tables.\n");

    //    Sql.sql_result res = handle->big_query("show tables");
    array(string) res = handle->list_tables();
    if (sizeof(res))
    {
        foreach(res, string table)
	{
	    LOG(sprintf("dropping (%s)\n",table));
	    handle->big_query("drop table "+table);
	}
    }
    else
	LOG("no old tables found");

    LOG("CREATING NEW BASE TABLES:");

    LOG("doc_data ");
    handle->big_query("create table doc_data (rec_data text, "+
		      "doc_id int not null, "+
		      "rec_order int not null, "+
                      "primary key (doc_id, rec_order))"+
                      "AVG_ROW_LENGTH=65535 MAX_ROWS=4194304");
    
    
    LOG("objects ");
    handle->big_query("create table objects (ob_id int primary key, "+
                      "ob_class text, ob_data text)");
    
    LOG("variables ");
    handle->big_query("create table variables (var char(20) primary key, "+
                      "value int)");
    
    res = handle->list_tables();
    if (sizeof(res)) {
	LOG("\nFATAL: failed to create base tables");
    }
    else
    {
	LOG("\nPOST CHECK retrieves: ");
        foreach(res, string table)
	    LOG(table+" ");
    }
    return 1;
}

/**
 * create and return a new instance of db_file
 *
 * @param  int iContentID - 0|ID of a given Content
 * @return the db_file-handle
 * @see    db_file
 * @see    file/IO
 * @author Ludger Merkens 
 */
object new_db_file_handle(int iContentID, string mode)
{
    return new("/kernel/db_file.pike", iContentID, mode);
}

/**
 * Check if a given gile handle is valid, eg inherits db_file.pike
 *  
 * @param object m - the db_file to check
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
private static bool valid_db_file(object m)
{
    if (Program.inherits(object_program(m), (program)"/kernel/db_file.pike"))
        return true;
    return false;
}

/**
 * connect_db_file, connect a /kernel/db_file instance with the database
 * calculate new content id if none given.
 *
 * @param    id
 * @return   function db()
 */
final mixed connect_db_file(int id)
{
    //    if (!(CALLINGFUNCTION == "get_database_handle" &&
    //	  valid_db_file(CALLER)))
    //	THROW("illegal access to database ", E_ACCESS);
    return ({ db, (id==0 ? create_new_database_id("doc_data") : id)});
}

/**
 * valid_db_mapping - check if an object pretending to be an db_mapping
 * really inherits /kernel/db_mapping and thus is a trusted program
 * @param     m - object inheriting db_mapping
 * @return    (TRUE|FALSE)
 * @see       connect_db_mapping
 * @author Ludger Merkens 
 */
private static bool valid_db_mapping(object m)
{
    if ( Program.inherits(object_program(m),
			  (program)"/kernel/db_mapping.pike") ||
         Program.inherits(object_program(m),
                          (program)"/kernel/db_n_one.pike") ||
         Program.inherits(object_program(m),
                          (program)"/kernel/db_n_n.pike") ||
         Program.inherits(object_program(m),
                          (program)"/kernel/searching.pike"))
	return true;
    return false;
}

/**
 * connect_mapping, connect a /kernel/db_mapping instance with the database
 * @param    none
 * @return   a pair ({ function db, string tablename })
 */
final mixed connect_db_mapping()
{
    if (!(CALLINGFUNCTION == "load_db_mapping" &&
	  valid_db_mapping(CALLER)))
	THROW("illegal access to database ", E_ACCESS);
    
    string sDbTable;
    // hack to allow the modules table to be a member of _Database

    werror("connect_db_mapping %s\n",
           master()->describe_program(CALLERPROGRAM));

    
    sDbTable = CALLER->get_table_name();


    if (!sDbTable)
        THROW(sprintf("Invalid tablename [%s] in module \"%s\"\n",sDbTable,
                      master()->describe_program(CALLERPROGRAM)), E_ERROR);
    /*    if (search(db()->list_tables("i_"+CALLER->get_object_id()),
               "i_"+CALLER->get_object_id())!=-1)
    {
        werror(sprintf("Detected invalid tablename %s - fix it by running "+
                      "check_database first - CALLER %s\n",
                      "i_"+CALLER->get_object_id(),
                       master()->describe_program(CALLERPROGRAM)));
        return ({ 0,0 });
        }*/
    werror(sprintf("sDbTable is [%s]\n", sDbTable));    
    return ({ db, sDbTable });
}

string get_identifier() { return "database"; }
int get_object_class() { return CLASS_DATABASE; }
object this() { return this_object(); }




/**
 * get_objects_by_class()
 * mainly for maintenance reasons, retreive all objects matching a given
 * class name, or program
 * @param class (string|object) - the class to compare with
 * @return array(object) all objects found in the database
 * throws on access violation. (ROLE_READ_ALL required)
 * @autoher Ludger Merkens
 */
final array(object) get_objects_by_class(string|program mClass)
{
    Sql.sql_result res;
    int i, sz;
    object security;
    array(object) aObjects;
    string sClass;
    
    if (security=MODULE_SECURITY)
        ASSERTINFO(security->
                   check_access(0, this_user(), 0, ROLE_READ_ALL, false),
                   "Illegal access on database.get_all_objects");

    if (objectp(mClass))
        sClass = master()->describe_program(mClass);
    else
        sClass = mClass;
    
    res = db()->big_query("select ob_id from objects where ob_class='"+
                          mClass+"'");

    aObjects = allocate((sz=res->num_rows()));

    for (i=0;i<sz;i++)
    {
        aObjects[i]=find_object((int)res->fetch_row()[0]);
    }
    return aObjects;
}


/**
 * get_all_objects()
 * mainly for maintenance reasons
 * @return array(object) all objects found in the database
 * throws on access violation. (ROLE_READ_ALL required)
 * @autoher Ludger Merkens
 */
final array(object) get_all_objects()
{
    Sql.sql_result res;
    int i, sz;
    object security;
    array(object) aObjects;

#if 0
    if ( !_Server->is_a_factory(CALLER) )
        THROW("Illegal attempt to call database.get_all_objects !", E_ACCESS);

    if (security=MODULE_SECURITY)
        ASSERTINFO(security->
                   check_access(0, this_user(), 0, ROLE_READ_ALL, false),
                   "Illegal access on database.get_all_objects");
#endif
    
    res = db()->big_query("select ob_id from objects where ob_class !='-'");
    aObjects = allocate((sz=res->num_rows()));

    for (i=0;i<sz;i++)
    {
        aObjects[i]=find_object((int)res->fetch_row()[0]);
    }
    return aObjects;
}

/**
 * visit_all_objects
 * loads all objects from the database, makes sure each object really loads
 * and calls the function given as "visitor" with consecutive with each object.
 * @param function visitor
 * @return nothing
 * @author Ludger Merkens
 * @see get_all_objects
 * @see get_all_objects_like
 * @caveats Because this function makes sure an object is properly loaded
 *          when passing it to function "visitor", you won't
 *          notice the existence of objects currently not loading.
 */
final void visit_all_objects(function visitor, mixed ... args)
{
    Sql.sql_result res = db()->big_query("select ob_id,ob_class from objects");
    int i;
    int oid;
    string oclass;
    object p;
    LOG("Number of objects found:"+res->num_rows());
    for (i=0;i<res->num_rows();i++)
    {
        mixed erg =  res->fetch_row();
        oid = (int) erg[0];  // wrong casting with 
        oclass = erg[1];     // [oid, oclass] = res->fetch_row()
        
        if (oclass[0]=='/') // some heuristics to avoid nonsene classes
        {
            p = find_object((int)oid);         // get the proxy
            catch{p->get_object();};      // force to load the object
            if (p->status() > PSTAT_DISK) // positive stati mean object loaded
                visitor(p, @args);
        }
    }
}

/**
 * Check for a list of objects, if they really exist in the database
 *
 * @param objects - the list of object to be checked
 * @return a list of those objects, which really exist.
 * @author Ludger Merkens
 * @see get_not_existing
 */
array(int) get_existing(array(int) ids)
{
    Sql.sql_result res;
    int i, sz;
    string query = "select ob_id from objects where ob_id in (";
    array(int) result;
    
    if (!ids || !sizeof(ids))
        return ({ });
    for (i=0,sz=sizeof(ids)-1;i<sz;i++)
        query +=ids[i]+",";
    query+=ids[i]+")";
    res = db()->big_query(query);

    result = allocate((sz=res->num_rows()));
    for (i=0;i<sz;i++)
        result[i]=(int) res->fetch_row()[0];

    return result;
}

/**
 * Get a list of the not-existing objects.
 *  
 * @param objects - the list of objects to be checked
 * @return a list of objects that are not existing
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
array(int) get_not_existing(array(int) ids)
{
    return ids - get_existing(ids);
}

object get_environment() { return 0; }
object get_acquire() { return 0; }

mapping get_xml_data()
{
    return ([ "configs":({_Server->get_configs, XML_NORMAL}), ]);
}

/**
 * clears lost content records from the doc_data table, used for the
 * db_file emulation. This function is purely for maintainance reasons, and
 * should be obsolete, since we hope no content records will get lost
 * anymore.
 * @param none
 * @returns a debug string containing the number of deleted doc_id's
 */
string clear_lost_content()
{
    Sql.sql h = db();
    LOG("getting doc_ids");
    Sql.sql_result res = h->big_query("select distinct doc_id from doc_data");
    array(int) doc_ids = allocate(res->num_rows());
    for(int i=0;i<sizeof(doc_ids);i++)
        doc_ids[i]=(int)res->fetch_row()[0];

    LOG("deleting '-' files");
    h->big_query("delete from objects where ob_class='-'");
    LOG("getting all objects");
    res = h->big_query("select ob_id from objects");
    int oid; object p; mixed a;
    while (a = res->fetch_row())
    {
        oid = (int)a[0];
        if (p=find_object(oid))
        {
            LOG("accessing object"+oid);
            object try;
            catch{try=p->get_object();};
            if (objectp(try) &&
                Program.inherits(object_program(try),
                                 (program)"/base/content"))
            {
                LOG("content "+p->get_content_id()+" is in use");
                doc_ids  -= ({ p->get_content_id() });
            }
        }
    }

    LOG("number of doc_ids to be deleted is:"+sizeof(doc_ids));

    foreach (doc_ids, int did)
    {
        h->big_query("delete from doc_data where doc_id = "+did);
        LOG("deleting doc_id"+did);
    }
    LOG("calling optimize");
    h->big_query("optimize table doc_data");
    return "deleted "+sizeof(doc_ids)+"lost contents";
}

