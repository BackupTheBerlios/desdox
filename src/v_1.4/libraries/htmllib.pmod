#include <classes.h>

import httplib;

string ahref_link_navigate(object obj, void|string prefix)
{
    if ( !stringp(prefix) ) prefix = "";
    return "<a "+href_link_navigate(obj)+">"+prefix+obj->get_identifier()+
	"</a>";
}

string href_link_navigate(object obj, void|string prefix)
{
    string path;
    string href;
    object dest = obj;

    if ( !stringp(prefix) ) prefix = "";

    if ( obj->get_object_class() & CLASS_EXIT ) {
	dest = obj->get_exit();
	path = get_module("filepath:tree")->object_to_filename(dest);
	href = "href=\""+path+"\"";
    }
    else 
	href = "href=\""+prefix+replace_uml(obj->get_identifier())+"\"";
    return href;
}

