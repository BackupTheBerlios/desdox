inherit "/classes/Document";


#include <macros.h>
#include <database.h>
#include <attributes.h>
#include <config.h>
#include <classes.h>

#define _XMLCONVERTER _Server->get_module("Converter:XML")

private static string sContentCache = 0; // holds the content (in html)
private static int     iSessionPort = 0;


mapping identify_browser(array id, mapping req_headers)
{
    return httplib->identify_browser(id, req_headers);
}

object get_stylesheet()
{
    object xsl = query_attribute("xsl:document"); 
    if ( !objectp(xsl) ) {
	if ( do_query_attribute("xsl:use_public") )
	    return query_attribute("xsl:public");
    }
    return xsl;
}

/**
 * get the content callback function.
 *  
 * @return the callback function that sends the content
 * @author Thomas Bopp (astra@upb.de) 
 */
function get_content_callback(mapping vars)
{
    object caller = CALLER;
    function cb;
    int pos;

    LOG("get_content_callback() by " + caller->get_client_class());
    cb = ::get_content_callback(vars);
		   
    object xsl = get_stylesheet();

    string clcl = caller->get_client_class();

    if ( !stringp(clcl) || search(clcl, "http") == -1 || !objectp(xsl) )
        return cb;


    sContentCache = "";
    string buf;
    pos = 0;
    while ( stringp(buf = cb(pos)) ) {
	LOG("Position="+pos);
	sContentCache += buf;
	pos += strlen(buf);
    }

    LOG("Content:\n" + sContentCache);

    string xml;
    xml = sContentCache;

    // browser identification
    mapping client_map = identify_browser(
	vars["__internal"]["client"],
	vars["__internal"]["request_headers"]);

    vars |= client_map;
    
    sContentCache = get_module("libxslt")->run(xml, xsl, vars);
    return send_content_xml;
}

/**
 * Get the content size of the XML document. This may differ because
 * it is possible to directly transform xml with XSL transformation.
 *  
 * @return the content size of the XML code or the generated code.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_content_callback
 */
int get_content_size()
{
    if ( !(CALLER->get_object_class() & CLASS_USER) || 
	 (functionp(CALLER->get_client_class && 
		    CALLER->get_client_class() == "ftp" ) ) )
        return ::get_content_size();
    if ( stringp(sContentCache) && strlen(sContentCache) > 0 )
	return strlen(sContentCache);
    else
	return ::get_content_size();
}

/**
 * Send the raw xml content data of this XML Document.
 *  
 * @param int pos - read position and DB_CHUNK_SIZE bytes
 * @return DB_CHUNK_SIZE bytes of the content.
 * @author Thomas Bopp (astra@upb.de) 
 */
string
send_content_xml(int pos)
{
    string result;
    
    if ( !stringp(sContentCache) )
	return 0; // finished

    if ( strlen(sContentCache) < DB_CHUNK_SIZE ) {
	result = copy_value(sContentCache);
	sContentCache = 0;
    }
    else {
	result = sContentCache[..DB_CHUNK_SIZE];
	sContentCache = sContentCache[DB_CHUNK_SIZE..];
    }
    return result;
}

int get_object_class() { return ::get_object_class() | CLASS_DOCXML; }
