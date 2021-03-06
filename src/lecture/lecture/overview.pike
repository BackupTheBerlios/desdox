inherit "/classes/Script";

#include <config.h>
#include <database.h>

mixed execute(mapping vars) 
{
    string html;
	
    if ( stringp(vars->modify) ) {
	foreach(indices(vars), string v) {
	  int grp_id;
	  if ( sscanf(v, "raum_%d", grp_id) == 1 ) {
	      find_object(grp_id)->set_attribute("raum", vars[v]);
	  }
	  else if ( sscanf(v, "zeit_%d", grp_id) == 1 ) {
	      find_object(grp_id)->set_attribute("zeit", vars[v]);
          }
	  else if ( sscanf(v, "tutor_%d", grp_id) == 1 ) {
	     find_object(grp_id)->set_attribute("tutor", find_object((int)vars[v]));
	  }
        }
    }    

    mapping lecture_vars = do_query_attribute("vars");

    html = 
	"<form action=\"overview\"><input type=\"hidden\" name=\"modify\" value=\"true\"/>"+
	"<TABLE BORDER='0' CELLPADDING='0' CELLSPACING='0' WIDTH='785' ALIGN='CENTER' CLASS='bgbrowser'>"+
	"<TR><TD>{text_veranstaltung_beschreibung}</TD>"+
	"<TD>Arbeitsbereich: <a href=\"https://"+_Server->get_server_name()+
	"/home/{veranstaltung_name}/\">/home/{veranstaltung_name}</a>"+
	"<BR/><BR/><BR/>Webauftritt: "+
	"<a href=\"http://"+_Server->get_server_name()+
	"{veranstaltung_url}/\">{veranstaltung_url}/</a></TD></TR>"+
	"<TR><TD><BR/><BR/>Gruppen</TD><TD>";
	html += "<ul>";
	 foreach(do_query_attribute("gruppen"), object grp ) {
	    html +=
		"<li><a href=//"+_Server->query_config(CFG_WEBSERVER)+":"+
		"/scripts/navigate.pike?object="+
		grp->get_object_id()+"/>"+grp->get_identifier()+"</a> &#160;&#160;"+
		"Tutor: "+make_selection("tutor_"+grp->get_object_id(),do_query_attribute("tutor_group"), do_query_attribute("tutor"))+"&#160;&#160; Raum: <input type='text' name='raum_"+grp->get_object_id()+"' value='"+grp->query_attribute("raum")+"'/> &#160; &#160; Zeit: <input type='text' name='zeit_"+grp->get_object_id()+"' value='"+grp->query_attribute("zeit")+"'/></li>";
	  }
	html +="</ul>";
    html += "</TD></TR><TR><TD colspan='2'>&#160;&#160;&#160;&#160;	Nehmen sie Benutzer in die " +
	nav_link(do_query_attribute("tutor_group"), "Tutoren Gruppe") + " auf.";
    
    html +=
	"</TD></TR><TR><TD colspan='2'><BR/><BR/>"+
	"<a href=\"xsl_config\">Konfiguration</a> der Webansicht"+
	"</TD></TR></TABLE><input type='submit' value='modifizieren'/></form>";
    html = html_template(html, lecture_vars);
    return result_page(html,"JavaScript:history.back();");
}



