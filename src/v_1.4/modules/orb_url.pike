inherit "/kernel/secure_mapping";
inherit "/kernel/orb";

#include <macros.h>
#include <attributes.h>
#include <exception.h>
#include <types.h>
#include <classes.h>
#include <events.h>

/**
 * Conversion function.
 *  
 * @param object obj - the object to convert.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void convert_url(object obj)
{
    if ( obj->this() == this )
	return;
    mixed old_value = obj->query_attribute("url");
    obj->set_acquire_attribute("url",this());
    if ( stringp(old_value) )
	obj->set_attribute("url", old_value);
}

/**
 * Callback function when the module is installed. Registers
 * the 'url' attribute in the object factory.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 */
void install_module()
{
    LOG("install_module() inside orb_url.pike !");
    object obj_factory = _Server->get_factory(CLASS_OBJECT);
    obj_factory->register_attribute("url", CMD_TYPE_STRING, "url", 
				    0, EVENT_ATTRIBUTES_CHANGE, this(),
				    CONTROL_ATTR_USER, "", convert_url);
}

/**
 * The 'url' attribute is acquired from this module and all url change
 * calls on objects will end up here.
 *  
 * @param string|int key - attribute to change, should be 'url'.
 * @param mixed val - new value of 'url' attribute.
 * @return true or new value.
 * @author Thomas Bopp (astra@upb.de) 
 * @see query_attribute
 */
mixed set_attribute(string|int key, mixed val)
{
    int                      id;
    object obj = CALLER->this();
    object            urlObject;
    string                  url;

    if ( key == "url" && obj != this() ) {
	if ( val == "none" || val == "" )
	    val = 0;
	if ( stringp(val) ) {
	    id = get_value(val);
	}
	
	LOG("Setting URL !(id="+id+", val="+val+", key="+key+")");
		
	if ( id > 0 ) {
	    urlObject = find_object(id);
	    if ( objectp(urlObject) && urlObject != obj ) {
		THROW("Trying to set url to conflicting value!",E_ERROR);
	    }
	}
	url = get_value(obj->get_object_id());
	if ( stringp(url) )
	    set_value(url, 0);
        set_value(id, 0);
	
	if ( stringp(val) )
	    set_value(val, obj->get_object_id());
	set_value(obj->get_object_id(), val);
	LOG("Value set !");
	return true;
    }
    else {
	return ::set_attribute(key, val);
    }
}
    
/**
 * Query an attribute, but should be 'url' in general for
 * other objects whose acquiring end up here.
 *  
 * @param string|int key - attribute to query.
 * @return value for url in database or this modules attribute value.
 * @author Thomas Bopp (astra@upb.de) 
 * @see set_attribute
 */
mixed query_attribute(string|int key)
{ 
    if ( key == "url" ) {
	object obj = CALLER->this();
	return get_value(obj->get_object_id());
    }
    return ::query_attribute(key);
}

/**
 * Get the acquired attribute. No URL to get no loops.
 *  
 * @param string|int key - the key of the attribute.
 * @return the acquire object or function.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mixed get_acquire_attribute(string|int key)
{
    if ( key == "url" )
	return 0;
    return ::get_acquire_attribute(key);
}

void set_acquire_attribute(string|int key, mixed val)
{
    if ( key == "url" )
	return;
    ::set_acquire_attribute(key, val);
}

/**
 * Resolve a path with the url module by getting the saved value for
 * 'path' and returning the appropriate object.
 *  
 * @param object uid - the uid for compatibility with orb:filepath
 * @param string path - the path to resolve.
 * @return the saved object value for 'path'.
 * @author Thomas Bopp (astra@upb.de) 
 */
object
resolve_path(object uid, string path)
{
    return find_object(get_value(path));
}

/**
 * Returns an object for the given path if some object is registered
 * with value 'path'.
 *  
 * @param string path - the path to process.
 * @return looks up an object in the database.
 * @author Thomas Bopp (astra@upb.de) 
 * @see resolve_path
 */
object path_to_object(string path)
{
    int l = strlen(path);
    int              oid;
    string             p;
    object           obj;
    
    if ( l > 1 ) {
	if ( path[0] != '/' ) {
	    path = "/"+path;
	    l++;
	}
    }
    else if ( l == 0 ) {
	path = "/";
	l = 1;
    }
    LOG("url:path_to_object("+path+")");
  
    p = path;
    oid = get_value(p);
    // if the path is the path to a directory, try to find the index files
    if ( oid == 0 && l >= 1 && path[l-1] == '/' ) {
	p = path + "index.xml";
	oid = get_value(p);
	if ( oid == 0 ) {
	    p = path + "index.html";
	    oid = get_value(p);
	}
	if ( oid == 0 ) {
	    p = path+"index.htm";
	    oid = get_value(p);
	}
    }

    // if we find no registered object we should try to get any registered
    // prefix container of this and use normal filepath handling from there.
    if ( oid == 0 ) {
	array prefixes = path / "/";
	if ( sizeof(prefixes) >= 2 ) {
	    for ( int i = sizeof(prefixes) - 1; i >= 0; i-- ) {
		p = prefixes[..i]*"/";
		oid = get_value(p);
		if ( oid == 0)
		    oid = get_value(p+"/"); // try  also containers with / at the end
		
		if ( oid != 0 ) {
		    obj = find_object(oid);
		    object module = _Server->get_module("filepath:tree");
		    if ( objectp(module) )
			return module->resolve_path(
			              obj, (prefixes[i+1..]*"/"));
		}
	    }
	}
    }

    LOG("Found object: " + oid);
    obj = find_object(oid);
    
    if ( obj == 0 )
	set_value(p, 0);
    return find_object(oid);
}

/**
 * Gets the path for an object by looking up the objects id in the
 * database and returns a path or 0.
 *  
 * @param object obj - the object to get a path for.
 * @return the path for object 'obj'.
 * @author Thomas Bopp (astra@upb.de) 
 */
string object_to_path(object obj)
{
    string path = get_value(obj->get_object_id());
    if ( !stringp(path) ) {
	path = "";
	object env = obj->get_environment();
	// check if environment is registered
	if ( objectp(env) ) {
	    path = object_to_path(env);
	}
	if ( path[-1] != '/' )
	    path += "/";
	path += obj->get_identifier();
    }
    return path;
}

/**
 * Get environment from a given path. This checks if the directory
 * prefix of 'url' is also registered in the database.
 *  
 * @param string url - path to get the environment object for.
 * @return the environment object or 0.
 * @author Thomas Bopp (astra@upb.de) 
 */
object path_to_environment(string url)
{
    sscanf(url, "/%s/%*s", url);
    return get_value(url);
}

string get_identifier() { return "filepath:url"; }
string get_table_name() { return "orb_url"; }
