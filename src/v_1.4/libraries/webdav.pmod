#define TYPE_DATE  (1<<16)
#define TYPE_DATE2 (1<<17)
#define TYPE_FSIZE (1<<18)


static mapping properties = ([
    "getcontentlength": 1|TYPE_FSIZE,
    "getlastmodified":3|TYPE_DATE,
    "creationdate":2|TYPE_DATE,
    ]);

static array _props = ({"getcontenttype","resourcetype"})+indices(properties);
			    
array(string) get_dav_properties(array fstat)
{
    if ( fstat[1] < 0 )
	return _props - ({ "getcontentlength" });
    else
	return _props - ({ "getcontenttype" });
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
string retrieve_props(string file, mapping xmlbody, array|void fstat) 
{
    string response = "";
    string unknown_props;
    array        __props;
    string      property;

    DAV_WERR("retrieve_props("+file+")");
    if ( !arrayp(fstat) )
	fstat = conf->stat_file(file, this_object());

    if ( !arrayp(fstat) ) {
	DAV_WERR("Failed to find file: " + file);
	return "";
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
	if ( xmlbody->getcontenttype || xmlbody->allprop )
	    response+="<D:getcontenttype>httpd/unix-directory"+
		"</D:getcontenttype>\r\n";
    }
    else { // normal file
	if ( xmlbody->resourcetype || xmlbody->allprop )
	    response += "<D:resourcetype/>\r\n";
    }
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
	}
    }
    response+="</D:prop>\r\n";
    response+="<D:status>HTTP/1.1 "+Caudium.Const.errors[200]+"</D:status>\r\n";
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

