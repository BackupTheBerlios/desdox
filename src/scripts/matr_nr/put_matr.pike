inherit "/classes/Script";
                                                                                                                             
#include <macros.h>

string
execute(mapping vars) {

if (vars->mnr != 0) {

	if (!this_user()->check_user_password(vars->pw)) {
		return error_page("Sie haben ein falsches Passwort eingegeben.");
	}

	if (this_user()->query_attribute("MatrikelNr") != UNDEFINED || this_user()->query_attribute("MatrikelNr") != "0000000") {
		return error_page("Ihre Matrikelnummer (" +this_user()->query_attribute("MatrikelNr") +") wurde schon gesetzt.<BR>Falls diese falsch sein sollte, kontaktieren Sie bitte den <a href=\"mailto:masterOfDesaster@uni-essen.de\">Admin</a>.");
	}	

   string html;
/*
    html = "<html><head><title>Test</title>\n </head> \n <body>\n";
	html += "Aufgerufen von " + this_user()->query_attribute(102) + " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
	html += "Aufgerufen von der Seite: " + this_user()->get_last_trail()->query_attribute(102) +"<br><br>" ;
//	this_user()->set_attribute("MatrikelNr", var->matr);
	html += "Aufgerufen von " + this_user()->query_attribute(102)+ " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
    html += "matnr: " +vars->mnr + "studiengang " + vars->studiengang;		
    
    html += "</body></html>";
       return html;
 */  
 
    this_user()->set_attribute("MatrikelNr", vars->mnr);
    this_user()->set_attribute("studiengang", vars->studiengang);
 

return result_page("Ihre Matrikelnummer ("+this_user()->query_attribute("MatrikelNr") + ") und ihr Studiengang (" +this_user()->query_attribute("studiengang") +") wurden erfolgreich eingetragen.",
			   "JavaScript:history.back();");

   


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