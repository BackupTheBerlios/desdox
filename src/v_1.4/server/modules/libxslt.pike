inherit "/kernel/module";

#include <macros.h>
#include <database.h>

private static object parser = xslt.Parser();

/**
 * callback function to find a stylesheet.
 *  
 * @param string uri - the uri to locate the stylesheet
 * @return the stylesheet content or zero.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static int match_stylesheet(string uri)
{
    if ( search(uri, "steam:") == 0 )
	return 1;
    return 0;
}

static object open_stylesheet(string uri)
{
    sscanf(uri, "steam:/%s", uri);
    return _FILEPATH->path_to_object(uri);
}

static string|int
read_stylesheet(object obj, string language, int position)
{
    if ( objectp(obj) ) {
	LOG("Stylesheet content found !");
	string contstr = obj->get_content(language);
	LOG("length="+strlen(contstr) + " of " + obj->get_object_id());
	return contstr;
    }
    LOG("No Stylesheet given for reading");
    return 0;
}

static void
close_stylesheet(object obj)
{
}

/**
 * Run the conversion and return the html code or whatever.
 *  
 * @param string xml - the xml code.
 * @param string|object xsl - the xsl stylesheet for transformation.
 * @param mapping vars - the variables passed to the stylesheet as params.
 * @return the transformed xml code.
 * @author Thomas Bopp (astra@upb.de) 
 */
string run(string xml, object|string xsl, mapping params)
{
    string content;
    float        t;
    string    html;
    mapping vars = copy_value(params);

    if ( !stringp(xml) || strlen(xml) == 0 )
	steam_error("Failed to transform xml - xml is empty.");
    
    mapping cfgs = _Server->get_configs();
    foreach ( indices(cfgs), string cfg) {
	 if ( intp(cfgs[cfg]) ) cfgs[cfg] = sprintf("%d", cfgs[cfg]);
	 vars[((cfg/":")*"_")] = (string)cfgs[cfg];
	 m_delete(cfgs, cfg);
    }
    foreach( indices(vars), string index) {
	if ( (stringp(vars[index]) && search(vars[index], "\0") >= 0 ) ||
	     !stringp(vars[index]) && !intp(vars[index]) )
	    vars[index] = 0;
	else if ( intp(vars[index]) )
	    vars[index] = (string)vars[index];
	else {
	    vars[index] = replace(vars[index], 
				  ({ "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß", "\""}),
				  ({ "%e4", "%f6", "%fc", "%c4", "%d6", "%dc",
					 "%df", "\\\"" }));
	}
    }

    parser->set_variables(vars);
    
    object stylesheet;
    if ( !stringp(vars["language"]) ) {
	werror("No language defined - setting english !\n");
	vars["language"] = "english";
    }
    if ( objectp(xsl) ) {
	string lang = vars["language"];
	stylesheet = xsl->get_stylesheet(lang);
    }
    else {
	stylesheet = xslt.Stylesheet();

	stylesheet->set_language(vars["language"]);
	stylesheet->set_include_callbacks(match_stylesheet,
					  open_stylesheet,
					  read_stylesheet,
					  close_stylesheet);
	stylesheet->set_content(xsl);
    }
    
    parser->set_xml_data(xml);
    mixed err = catch {
	t = gauge {
	    html = parser->run(stylesheet);
	};
	MESSAGE("XSL run takes " + t + " seconds !");
    };

    if ( arrayp(err) || objectp(err) ) {
	LOG("Error while processing xml !\n"+PRINT_BT(err));
	
	THROW("LibXSLT (version="+parser->get_version()+
	      ") xsl: Error while processing xsl ("
              +xsl->get_identifier()+" ):\n" + 
	      err[0] + "\n", E_ERROR);
    }
    return html;
}

string get_identifier() { return "libxslt"; }
string get_version() { return parser->get_version(); }

