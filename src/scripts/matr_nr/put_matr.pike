inherit "/classes/Script";
                                                                                                                             
#include <macros.h>

string
execute(mapping vars) {

if (vars->mnr != 0) {
   string html;

    html = "<html><head><title>Test</title>\n </head> \n <body>\n";
	html += "345Aufgerufen von " + this_user()->query_attribute(102) + " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
	html += "Aufgerufen von der Seite: " + this_user()->get_last_trail()->query_attribute(102) +"<br><br>" ;
//	this_user()->set_attribute("MatrikelNr", var->matr);
	html += "Aufgerufen von " + this_user()->query_attribute(102)+ " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
    html += "matnr: " +vars->mnr + "studiengang " + vars->studiengang;		
    this_user()->set_attribute("MatrikelNr", vars->mnr);
    this_user()->set_attribute("studiengang", vars->studiengang);
    
    html += "</body></html>";
    
   return html;
   


}

else {

     object rtmp = find_document("register.tmpl");
    if ( !objectp(rtmp) )
	return result_page("Die Registrierungs-Template-Datei 'register.tmpl'"+
			   " wurde nicht gefunden !",
			   "JavaScript:history.back();");

    return html_template(rtmp, ([ "SELECT_GROUP": "test"]));
                                                                                                                            

}

}