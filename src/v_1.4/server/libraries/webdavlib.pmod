import httplib;

#define WEBDAV_DEBUG

#ifdef WEBDAV_DEBUG
#define DAV_WERR(s) werror((s)+"\n")
#else
#define DAV_WERR(s) 
#endif

#define TYPE_DATE  (1<<16)
#define TYPE_DATE2 (1<<17)
#define TYPE_FSIZE (1<<18)
#define TYPE_EXEC  (1<<19)

class WebdavHandler {
// the stat file function should additionally send mime type
    function stat_file; 
    function get_directory;
}


static mapping properties = ([
    "getlastmodified":3|TYPE_DATE,
    "creationdate":2|TYPE_DATE,
    ]);

static array _props = ({"getcontenttype","resourcetype", "getcontentlength", "href"})+indices(properties);
			    
array(string) get_dav_properties(array fstat)
{
    return _props;
}



/**
 * Retrieve the properties of some file by calling the
 * config objects stat_file function.
 *  
 * @param string file - the file to retrieve props
 * @param mapping xmlbody - the xmlbody of the request
 * @param array|void fstat - file stat information if previously available
 * @return xml code of properties
 */
string retrieve_props(string file, mapping xmlbody, array fstat) 
{
    string response = "";
    string unknown_props;
    array        __props;
    string      property;

    if ( !arrayp(fstat) ) {
	error("Failed to find file: " + file);
	return "";
    }

    if ( sizeof(fstat) < 8 ) {
	if ( fstat[1] < 0 )
	    fstat += ({ "httpd/unix-directory" });
	else
	    fstat += ({ "application/x-unknown-content-type" });
    }

    unknown_props = "";
    __props = get_dav_properties(fstat);
    
    if ( !xmlbody->allprop ) {
	foreach(indices(xmlbody), property ) {
	    if ( property == "allprop" || property == "")
		continue;
	    if ( search(__props, property) == -1 ) 
		unknown_props += "<i0:"+property+"/>\r\n";
	}
    }
    
    
    response += "<D:response"+
	(strlen(unknown_props) > 0 ? " xmlns:i0=\"DAV:\"":"") + 
 	"  xmlns:lp0=\"DAV:\">\r\n";
    
    if ( fstat[1] < 0 && file[-1] != '/' ) file += "/";

    response += "<D:href>"+file+"</D:href>\r\n";
    
    if ( xmlbody->propname ) {
	response += "<D:propstat>\r\n";	   
	// only the normal DAV namespace properties at this point
	response += "<D:prop>";
	foreach(__props, property) {
	    if ( fstat[1] < 0 )
		response += "<"+property+"/>\r\n";
	}	
	response += "</D:prop>";
	response += "</D:propstat>\r\n";
    }


    response += "<D:propstat>\r\n";
    response += "<D:prop>\r\n";

    if ( fstat[1] < 0 ) { // its a directory
	if ( xmlbody->resourcetype || xmlbody->allprop ) 
	    response+="<D:resourcetype><D:collection/></D:resourcetype>\r\n";
	if ( xmlbody->getcontentlength || xmlbody->allprop )
	    response += "<D:getcontentlength></D:getcontentlength>\r\n";
    }
    else { // normal file
	if ( xmlbody->resourcetype || xmlbody->allprop )
	    response += "<D:resourcetype/>\r\n";
	if ( xmlbody->getcontentlength || xmlbody->allprop )
	    response += "<D:getcontentlength>"+fstat[1]+
		"</D:getcontentlength>\r\n";
    }
    if ( xmlbody->getcontenttype || xmlbody->allprop )
	response+="<D:getcontenttype>"+fstat[7]+
	    "</D:getcontenttype>\r\n";
    
    foreach(indices(properties), string prop) {
	if ( xmlbody[prop] || xmlbody->allprop ) {
	    if ( properties[prop] & TYPE_DATE ) {
		response += "<lp0:"+prop+" xmlns:b="+
		    "\"urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/\""+
		    " b:dt=\"dateTime.rfc1123\">";
		response += http_date(fstat[properties[prop]&0xff]);
		response += "</lp0:"+prop+">\r\n";
	    }
	    else if ( properties[prop] & TYPE_FSIZE ) {
		int sz = fstat[(properties[prop]&0xff)];
		if ( sz >= 0 ) { 
		    response += "<lp0:"+prop+">";
		    response += sz;
		    response += "</lp0:"+prop+">\r\n";
		}
	    }
	    else if ( properties[prop] & TYPE_EXEC ) {
		//int stats = fstat[0][
	    }
	}
    }
    response+="</D:prop>\r\n";
    response+="<D:status>HTTP/1.1 200 OK</D:status>\r\n";
    response+="</D:propstat>\r\n";

    // props not found...
    if ( strlen(unknown_props) > 0 ) {
	response += "<D:propstat>\r\n";
	response += "<D:prop>\r\n";
	response += unknown_props;
	response += "</D:prop>\r\n";
	response += "<D:status>HTTP/1.1 404 Not Found</D:status>\r\n";
	response += "</D:propstat>\r\n";
    }

    response += "</D:response>\r\n";    
    return response;
}

/**
 * Retrieve the properties of a colletion - that is if depth
 * header is given the properties of the collection and the properties
 * of the objects within the collection are returned.
 *  
 * @param string path - the path of the collection
 * @param mapping xmlbody - the xml request body
 * @return the xml code of the properties
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string
retrieve_collection_props(string colpath, mapping xmlbody, WebdavHandler h)
{
    string response = "";
    int                i;
    mapping       fstats;
    array      directory;


    int len,filelen;
    array     fstat;
    
    directory = h->get_directory(colpath);
    len = sizeof(directory);
    
    string path;
    fstats = ([ ]);
    
    for ( i = 0; i < len; i++) {
	DAV_WERR("stat_file("+colpath+"/"+directory[i]);
	if ( strlen(colpath) > 0 && colpath[-1] != '/' )
	    path = colpath + "/" + directory[i];
	else
	    path = colpath + directory[i];
	fstat = h->stat_file(path, this_object());
	if ( fstat[1] >= 0 )
	    response += retrieve_props(path, xmlbody, fstat);
	else
	    fstats[path] = fstat;
    }
    foreach(indices(fstats), string f) {
	string fname;

	if ( f[-1] != '/' ) 
	    fname = f + "/";
	else
	    fname = f;
	response += retrieve_props(fname, xmlbody, fstats[f]);
    }
    return response;
}

/**
 * Converts the XML structure into a mapping for prop requests
 *  
 * @param object node - current XML Node
 * @param void|string pname - the name of the previous (father) node
 * @return mapping
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mapping convert_to_mapping(object node, void|string pname)
{
    string tname = node->get_tag_name();
    int                               t;

    if ( (t=search(tname, ":")) >= 0 ) 
	tname = tname[t+1..]; // no namespace prefixes
    
    mapping m = ([ ]);
    if ( pname == "prop" || tname == "allprop" ) {
	m[tname] = node->get_text();
    }
    array(object) elements = node->get_children();
    foreach(elements, object n) {
	m += convert_to_mapping(n, tname);
    }
    return m;
}      


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping get_xmlbody_props(string data)
{
    mapping xmlData;
    object     node;

    if ( !stringp(data) || strlen(data) == 0 ) {
	xmlData = ([ "allprop":"", ]); // empty BODY treated as allprop
    }
    else {
	mixed err = catch {
	    node = Parser.XML.Tree.parse_input(data);
	    xmlData = convert_to_mapping(node);
	};
	if ( err != 0 )
	    xmlData = ([ "allprop":"", ]); // buggy http ?
    }
    DAV_WERR("Props mapping:\n"+sprintf("%O", xmlData));
    return xmlData;
}

array(object) get_xpath(object node, array(string) expr)
{
    array result = ({ });
    
    if ( expr[0] == "/" )
	throw( ({ "No / in front of xpath expresions", backtrace() }) );
    array childs = node->get_children();
    foreach(childs, object c) {
	string tname;
	tname = c->get_tag_name();
	DAV_WERR("TAG:"+tname);
	sscanf(tname, "%*s:%s", tname); // this xpath does not take care of ns
	
	if ( tname == expr[0] ) {
	    if ( sizeof(expr) == 1 )
		result += ({ c });
	    else
		result += get_xpath(c, expr[1..]);
	}
    }
    return result;
}

mapping|string resolve_destination(string destination, string host)
{
    string dest_host;

    if ( sscanf(destination, "http://%s/%s", dest_host, destination) == 2 )
    {
	if ( dest_host != host ) 
	    return low_answer(502, "Bad Gateway");
    }
    return destination;
}
/**
 *
 *  
 * @param 
 * @return 
 * @see 
 */
mapping get_properties(object n)
{
    mapping result = ([ ]);
    foreach(n->get_children(), object c) {
	string tname = c->get_tag_name();
	if ( search(tname, "prop") >= 0 ) {
	    foreach (c->get_children(), object prop) {
		if ( prop->get_tag_name() == "" ) continue;
		result[prop->get_tag_name()] = prop->value_of_node();
	    }
	}
    }
    return result;
}

/**
 *
 *  
 * @param 
 * @return 
 * @see 
 */
int set_property(string prop, string value, mapping namespaces)
{
    string ns;
    if ( sscanf(prop, "%s:%s", ns, prop) == 2 ) {
	
    }
    return 1;
}


mapping|void 
proppatch(string url, mapping request_headers, string data, WebdavHandler h)
{
    mapping result, xmlData;
    object             node;
    array(object)     nodes;
    string         response;
    string host = request_headers->host;
    
    DAV_WERR("Proppatch:\n"+sprintf("%s\n%O\n", data, mkmapping(indices(this_object()), values(this_object()))));

    if ( !stringp(url) || strlen(url) == 0 )
	url = "/";
    
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    response+="<D:multistatus xmlns:D=\"DAV:\">\n";
    response+="<D:response>\n";
    
    array fstat = h->stat_file(url, this_object());
    response += "<D:href>http://"+host+url+"</D:href>\n";

    node = Parser.XML.Tree.parse_input(data);

    nodes = get_xpath(node, ({ "propertyupdate" }) );
    if ( sizeof(nodes) == 0 )
	error("Failed to parse webdav body.");
    mapping namespaces = nodes[0]->get_attributes();
    DAV_WERR("Namespaces:\n"+sprintf("%O", namespaces));
    array sets    = get_xpath(nodes[0], ({ "set" }));
    array updates = get_xpath(nodes[0], ({ "update" }));
    array removes = get_xpath(nodes[0], ({ "removes" }));

    object n;
    foreach(sets+updates, n) {
	mapping props = get_properties(n);
	foreach (indices(props), string prop) {
	    int patch;
	    response += "<D:propstat>\n";
	    patch = set_property(prop, props[prop], namespaces);
	    response += "<D:prop><"+prop+"/></D:prop>\n";
	    response += "<D:status>HTTP/1.1 "+
		(patch ? " 200 OK" : " 403 Forbidden")+ "</D:status>\r\n";
	    response += "</D:propstat>\n";
	}
	DAV_WERR("Properties:\n"+sprintf("%O", props));
    }
    foreach(removes, n) {
	DAV_WERR("REMOVE:\n");
    }
	


    response+="</D:response>\n";
    response+="</D:multistatus>\n";
    DAV_WERR("RESPONSE="+response);
    result = low_answer(207, response);
    result["type"] = "text/xml; charset=\"utf-8\"";
    result["rettext"] = "207 Multi-Status";
    return result;
}

mapping|void 
propfind(string raw_url,mapping request_headers,string data,WebdavHandler h)
{
    mapping result, xmlData;
    object             node;
    string         response;

    
    DAV_WERR("Propfind: "+raw_url+"\n"+sprintf("%O\n",request_headers)+data);
    xmlData = get_xmlbody_props(data);
	
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    
    if ( !stringp(raw_url) || strlen(raw_url) == 0 )
	raw_url = "/";
    
    array fstat = h->stat_file(raw_url, this_object());
    
    if ( !stringp(request_headers->depth) )
	request_headers["depth"] = "infinity";
    
    if ( !arrayp(fstat) ) {
#if 0
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	response += "<D:response>\r\n";
	response += "<D:href>"+raw_url+"</D:href>\r\n";	
	response += "<D:status>HTTP/1.1 404 Not Found</D:status>\r\n";
	response += "</D:response\r\n";
	response += "</D:multistatus>\r\n";
#endif
	return low_answer(404,"");
    }
    else if ( fstat[1] < 0 ) {
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	if ( request_headers->depth != "0" ) 
	    response += retrieve_collection_props(raw_url, xmlData, h);
	response += retrieve_props(raw_url, xmlData, fstat);
	response += "</D:multistatus>\r\n";
    }
    else {
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	response += retrieve_props(raw_url, xmlData, h->stat_file(raw_url));
	response += "</D:multistatus>\r\n";
    }
    result = low_answer(207, response);
    result["rettext"] = "207 Multi-Status";
    result["type"] = "text/xml; charset=\"utf-8\"";
    return result;
}

mapping low_answer(int code, string str)
{
    return ([ "error": code, "data": str, "extra_heads": ([ "DAV": "1", ]), ]);
}






