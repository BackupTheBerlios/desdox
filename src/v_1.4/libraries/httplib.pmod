#include <config.h>
#include <macros.h>
#include <attributes.h>
#include <classes.h>

constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });
constant months=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
	         "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
		 "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
	         "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);
constant montharr = ({ "Jan", "Feb", "Mar", "Apr", "Mai", "Jun", "Jul", "Aug",
			   "Sep", "Oct", "Nov", "Dec" });


/**
 * Identify a browser and return identified parameters
 * as a mapping:
 * client: MSIE|mozilla|opera
 * os: Linux|macosx|windows 95|windows 98|windows nt|windows
 * language: german|english|...
 * xres: resolution x (width)
 * yres: resolution y (height)
 *  
 * @param array id - components of client request header
 * @param mapping request_headers - the mapping of all request headers
 * @return mapping (see function description)
 */
mapping identify_browser(array id, mapping req_headers)
{
    int i;
    mapping client = ([ "language": "english", ]);

    if ( !arrayp(id) || !mappingp(req_headers) )
      return client;

    if ( (i=search(id, "MSIE")) >= 0 ) {
	client["client"] = "MSIE";
	client["client-version"] = id[i+1];
    }
    else {
	string sclient, sversion;
	sscanf(id[0],"%s/%s",sclient,sversion);
	client["client"] = client;
	client["client-version"] = version;
    }
    if ( search(id, "Linux") >= 0 )
	client["os"] = "linux";
    else if ( search(id, "Mac OS X") >= 0 )
	client["os"] = "macosx";
    else if ( search(id, "Windows NT 4.0") >= 0 )
	client["os"] = "windows nt";
    else if ( search(id, "Windows 95") >= 0 )
	client["os"] = "windows 95";
    else if ( search(id, "Windows 98") >= 0 )
	client["os"] = "windows 98";
    else if ( stringp(req_headers["user-agent"]) && 
	      search(req_headers["user-agent"], "Windows") >= 0 )
	client["os"] = "windows";
    else 
	client["os"] = "unknown";
    
    
    int xres, yres, tmp1, tmp2;
    xres = 1024;
    yres =  768;
    foreach(id, string modifier) {
	if ( sscanf(modifier, "%dx%d%*s", tmp1, tmp2) >= 2 ) {
	    xres = tmp1;
	    yres = tmp2;
	}
    }
    client["xres"] = (string)xres;
    client["yres"] = (string)yres;
    if ( mappingp(req_headers) ) {
	if ( stringp(req_headers["accept-language"]) ) {
	    int de, en;
	    de = search(req_headers["accept-language"], "de");
	    en = search(req_headers["accept-language"], "en");
	    if ( de == -1 )
		client["language"] = "english";
	    else if ( en == -1 || de < en ) 
		client["language"] = "german";
	    else
		client["language"] = "english";
	}
    }
    return client;
}

/**
 * Returns if time t is later than time/length string a, or len
 * differs from the length encoded in the string a.
 * Taken from caudium webserver.
 *  
 * @param string a - the timestamp (cached on client side?!)
 * @param int t - a timestamp, modification date with length.
 * @param void|int len - the current length of a file
 * @return 1 or 0, true or false.
 */
int is_modified(string a, int t, void|int len)
{
  mapping t1;

  int day, year, month, hour, minute, second, length;
  string m, extra;
  if(!a)
    return 1;
  t1=gmtime(t);
   // Expects 't' as returned from time(), not UTC.
  sscanf(lower_case(a), "%*s, %s; %s", a, extra);
  if(extra && sscanf(extra, "length=%d", length) && len && length != len)
    return 1;

  if(search(a, "-") != -1)
  {
    sscanf(a, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second);
    year += 1900;
    month=months[m];
  } else   if(search(a, ",") == 3) {
    sscanf(a, "%*s, %d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    if(year < 1900) year += 1900;
    month=months[m];
  } else if(!(int)a) {
    sscanf(a, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
    month=months[m];
  } else {
    sscanf(a, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
    month=months[m];
    if(year < 1900) year += 1900;
  }

  if(year < (t1["year"]+1900))                                
    return 1;
  else if(year == (t1["year"]+1900)) 
    if(month < (t1["mon"]))  
      return 1;
    else if(month == (t1["mon"]))      
      if(day < (t1["mday"]))   
	return 1;
      else if(day == (t1["mday"]))	     
	if(hour < (t1["hour"]))  
	  return 1;
	else if(hour == (t1["hour"]))      
	  if(minute < (t1["min"])) 
	    return 1;
	  else if(minute == (t1["min"]))     
	    if(second < (t1["sec"])) 
	      return 1;
  return 0;
}

string http_date(int t)
{
#if constant(gmtime)
  mapping l = gmtime( t );
#else
  mapping l = localtime(t);
  t += l->timezone - 3600*l->isdst;
  l = localtime(t);
#endif
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, montharr[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));

}

/**
 * Get a html page which redirects to the given URL.
 *  
 * @param string url - the URL to redirect to.
 * @return html code of redirection to url.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string redirect(string url, int|void refresh_time)
{
    return "<html><head>"+redirect_meta(url, refresh_time)+"</head></html>";
}

string redirect_meta(string url, int|void refresh_time)
{
    return "<meta http-equiv=\"refresh\" content=\""+
	refresh_time+";URL="+url+"\"/>";
}

/**
 * This function takes request and parses the given data,which
 * represents a MIME Message (the body of the request).
 * Returned is a mapping with the parts of the message.
 * HTTP create multipart messages with variable encoded as
 * parts of the body.
 * This function was taken out of caudium code.
 *  
 * @param object req - the request object
 * @param string data - the body of the message
 * @return mapping of parsed variables.
 */
mapping parse_multipart_form_data(object req, string data)
{
    mapping variables = ([ ]);
    
    MIME.Message messg = MIME.Message(data, req->request_headers);
    
    foreach(messg->body_parts||({}), object part) {
	if(part->disp_params->filename) {
	    variables[part->disp_params->name]=part->getdata();
	    string fname=part->disp_params->filename;
	    if( part->headers["content-disposition"] ) {
		array fntmp=part->headers["content-disposition"]/";";
		if( sizeof(fntmp) >= 3 && search(fntmp[2],"=") != -1 ) {
		    fname=((fntmp[2]/"=")[1]);
		    fname=fname[1..(sizeof(fname)-2)];
		}
		
	    }
	    variables[part->disp_params->name+".filename"]=fname;
	} else {
	    if(variables[part->disp_params->name])
		variables[part->disp_params->name] += "\0" + part->getdata();
	    else
		variables[part->disp_params->name] = part->getdata();
	}
    }
    //werror("parsed variables=\n"+sprintf("%O\n", variables));
    return variables;
}

/**
 * return a backtrace in html with <li>
 *  
 * @param array|string bt - the pike backtrace
 * @return html generated 
 */    
string backtrace_html(array|object|string bt)
{
    string errStr = "";
    
    if ( intp(bt) ) {
	werror("wrong backtrace format:\n"+
	       sprintf("%O\n",backtrace()));
	throw( ({
	    "Wrong backtrace format in backtrace_html().\n", backtrace() })) ;
    }
    
    if ( arrayp(bt) || objectp(bt) ) {
	errStr += "<ul>\n";
	for ( int i = sizeof(bt)-1; i >= 0; i-- ) {
	    array line = bt[i];
	    if ( stringp(line[0]) ) {
		string oname = line[0];
		int oid;
		if ( sscanf(oname, "/DB:#%d", oid) > 0 )
		    oname = get_module("filepath:tree")->
			object_to_filename(find_object(oid));
		errStr += sprintf("<li> %s,  line %d</li>\n", oname, line[1]);
	    }
	}
	errStr += "</ul>\n";
    }
    else 
	errStr += replace(bt, ({ "\r\n", "\n", "<", ">" }),
			  ({ "<BR/>", "<BR/>", "&lt;", "&gt;" }) );
    return errStr;
}

string html_backtrace(array|object|string bt)
{
    return backtrace_html(bt);
}


/**
 * return a page for displaying errors
 *  
 * @param message - the error message
 * @param back - what page to go back to (action back)
 * @return the html code for the page
 */
string error_page(string message, string|void back)
{
    object xsl;
    string xml;
    
    xsl = find_object("/stylesheets/errors.xsl");
    xml = "<?xml version='1.0' encoding='iso-8859-1'?>"+
      "<error><actions/>\n<message><![CDATA["+message+
	"]]></message></error>";
    return _Server->get_module("libxslt")->run(xml, xsl, (["back": back,]) );
}


/**
 * Remove umlaute from a string str and return the changed string.
 *  
 * @param string str - the string to convert.
 * @return the source string with umlaute removed.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string no_uml(string str)
{
    if ( !stringp(str) ) return "";
    return "<![CDATA["+replace_uml(str)+"]]>";
}

string replace_uml(string str)
{
    return replace(str, 
		   ({ "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß", "<", ">", "?", 
			  " ", "#", ":" }),
		   ({ "%e4", "%f6", "%fc", "%c4", "%d6", "%dc", "%df", 
			  "%3c", "%3e", "%3f", "%20", "%23", "%3a" }));
}

/**
 * Replace the Umlaute and other unpleasent chars.
 *  
 * @param string str - the string to replace.
 * @return replaced string
 */
string uml_to_html(string str)
{
    if ( !stringp(str) ) return "";
    return 
	replace(str, ({ "ä","ö","ü", "Ä", "Ö", "Ü", "<", ">", "&" }),
		({ "&auml;", "&ouml;", "&uuml;", "&Auml;", "&Ouml;",
		       "&Uuml;", "&lt;","&gt;", "&amp;" }));
}

string url_to_string(string str)
{
    return Protocols.HTTP.Server.http_decode_string(str);
#if 0
    int len = strlen(str);
    string res = "";
    
    for ( int i = 0; i < len; i++ ) {
	if ( str[i] == '%' && i < len - 2 ) {
	    int        val;
	    string v = str[i..i];
	    if ( sscanf(str[i+1..i+2], "%x", val) ) 
		v[0] = val;
	    res += v;
	    // jump over %xx value
	    i += 2;
	}
	else {
	    res += str[i..i];
	}
    }
    return res;
    return replace(str, 
		   ({ "%e4", "%f6", "%fc", "%c4", "%d6", "%dc", "%df", 
			  "%3c", "%3e", "%3f", "%20", "%5B", "%5D" }),
		   ({ "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß", "<", ">", "?", " ",
			  "[", "]" }));
#endif
}


/**
 * Get the html representation of text/plain content.
 *  
 * @param string text
 * @return the html representation
 */
string text_to_html(string text)
{
    return replace(text, ({ "\n", "  " }), ({ "<br/>", "&nbsp;" }));
}


/**
 * Return a result page in html with the message in the content
 * area.
 *  
 * @param string message - the message to print out.
 * @param string next - the next link in the header area.
 * @param string|void title - the title for the page.
 * @param string|void head - optional header arguments.
 * @return html result page.
 */
string 
result_page(string message, string next, string|void title, string|void head)
{
    object xsl;
    string xml;
    
    if ( !stringp(title) ) title = "Result";
    if ( !stringp(head) ) head = "";

    xsl = find_object("/stylesheets/result.xsl");
    xml = "<?xml version='1.0' encoding='iso-8859-1'?>"+
	"<result>"+
	"<head><![CDATA["+head+"]]></head>"+
	"<title>"+title+"</title><actions/>\n<message><![CDATA["+message+
	"]]></message></result>";
    return get_module("libxslt")->run(xml, xsl, (["back": next,]) );
}

/**
 * Return a mapping in appropriate format for Protocols.HTTP to handle.
 *  
 * @param int code - the http return code.
 * @return mapping suitable for Protocols.HTTP
 */
mapping low_answer(int code, string response)
{
    return ([ "error": code, "data": response, ]);
}

/**
 * Get a mapping of client informations from the submitted vars mapping.
 *  
 * @param mapping vars - the submitted variables.
 * @return mapping of client information
 */
mapping get_client_map(mapping vars)
{
    mapping client_map = identify_browser(
	vars["__internal"]["client"],
	vars["__internal"]["request_headers"]);
    string l = this_user()->query_attribute(USER_LANGUAGE);
    if ( stringp(l) )
	client_map->language = l;
    if ( client_map->language != "english" &&
	 client_map->language != "german" )
	client_map["language"] = "english";
    return client_map;
}



/**
 * Basic function to get html from a given object. The function
 * sets some parameters like ports and the hostname of this server.
 * If the variables source is set to true, then only the xml code
 * will be returned wrapped in a html page (inside <pre>).
 *  
 * @param object obj - the object to get xml/html code for
 * @param object xsl - the xsl stylesheet to be used for transformation
 * @return html (?) code as a string
 */
string run_xml(object|string obj, object xsl, mapping vars)
{
    string html, xml;

    if ( !vars->client ) {
	mapping client_map = get_client_map(vars);
	vars |= client_map;
    }

    vars["host"] = _Server->query_config(CFG_WEBSERVER);
    vars["port_ftp"] = (string)_Server->query_config("ftp_port");
    vars["port_http"] = (string)_Server->query_config("https_port");
    vars["port_irc"] = (string)_Server->query_config("irc_port");
    vars["user_id"] = (string)(this_user()->get_object_id());

    if ( stringp(obj) ) {
	xml = obj;
    }
    else {
	float t = gauge {
	    xml = get_module("Converter:XML")->get_xml(
		obj, xsl, vars, (int)vars["active"]);
	};
	MESSAGE("XML-Converting took " + t + " seconds...");
    }
    if ( vars->source == "true" )
	return xml;
    
    html = get_module("libxslt")->run(xml, xsl, vars);
	

    return html;
}


static object parse_rxml_tag(object node, mapping variables, mapping tags)
{
    object father = node->father;

    // is it registered rxml entity ?
    object tag = tags[node->name];
    if ( objectp(tag) ) {
	mixed err = catch {
	    variables->args = ([ ]);

	    // dont trust data in node->data, it does not contain tags
	    variables->args->body = node->get_sub_xml();
	    // convert the attributes into vars->args
	    foreach(indices(node->attributes), string idx) {
		variables->args[idx] = node->attributes[idx];
	    }
	    string result;
	    
	    if ( tag->get_object_class() & CLASS_DOCLPC ) 
	        result = tag->call_script(variables);
	    else
	        result = tag->execute(variables);
	    
	    // replace this node with text node with result !
	    node->replace_node(result);
	};
	if ( err != 0 ) {
	    if ( stringp(err) || intp(err) )
		node->replace_node("Some error occured: " + err);
	    else
		node->replace_node(
		    "An error occured on tag " + node->name + "<br/>"+
		    err[0]+"<br/><!---"+html_backtrace(err[1])+"--->");
	}
    }
    return father;
}

/**
 * Parse rxml tags inside html files. The html code needs to be
 * wellformed (xhtml).
 *  
 * @param string result - the html code to parse
 * @param mapping variables - a mapping of variables
 * @param mapping tags - tags to replace inside the html code.
 * @return resulting html code with rxml tags replaced.
 */
string rxml(string result, mapping variables, mapping tags)
{
    // parse result
    object root;
    float t = gauge {
    object parser = ((program)"/base/xml_parser")();
    object node = parser->parse_data(result);
    root = node->get_parent();
    
    // now traverse tree to bottom and from there replace rxml tags
    array(object) leafs = node->get_leafs();
    
    for ( int i = 0; i < sizeof(leafs); i++ ) {
	object leaf = leafs[i];
	object father =	parse_rxml_tag(leaf, variables, tags);
	// add the father to list for BFS
	if ( objectp(father) && search(leafs, father) == -1 )
	    leafs += ({ father });
    }
    };
    werror("RXML took " + t  + " seconds...\n");
    return root->get_last_child()->get_xml();
}



class testTag {
    string execute(mapping vars) {
	return "Hello World to " + vars->args->name;
    }
}

class tagTag {
    string execute(mapping vars) {
	return "<BODY>"+vars->args->body+"</BODY>";
    }
}

void test()
{
    // first test rxml
    string result = 
	"<html><body>Welcome! <h2><test name='test'/></h2></body></html>";

    result = rxml(result, ([ ]), ([ "test": testTag(), ]));
    if ( result !=
	 "<html><body>Welcome! <h2>Hello World to test</h2></body></html>" )
	error("rxml test failed - wrong result " + result);
    
    result =  "<a><b><c apply='1'>"+
	"<d name='x'/></c>"+
	"<d name='y'/></b></a>";

    result = rxml(result, ([ ]), ([ "d": testTag(), "c":tagTag(),]));
    if ( result != 
	 "<a><b><BODY>Hello World to x</BODY>Hello World to y</b></a>" )
	error("nested rxml test failed !");

    result = "<a><?xml version='1.0'?><x>test</x></a>";
    result = rxml(result, ([ ]), (["a": tagTag(), ]));
    if ( result != "<BODY><?xml version='1.0'?>\n\n<x>test</x></BODY>" )
	error("Failed test with rxml tag with xml in body.\n");

}
    
