inherit "/classes/Script";
                                                                                                                             
#include <macros.h>

string
execute(mapping vars) {
    string html;

    html = "<html><head><title>Test</title>\n </head> \n <body>\n";
	html += "Aufgerufen von " + this_user()->query_attribute(102)+ " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
	html += "Aufgerufen von der Seite: " + this_user()->get_last_trail()->query_attribute(102) +"<br><br>" ;
//	this_user()->set_attribute("MatrikelNr", "846921");
		html += "Aufgerufen von " + this_user()->query_attribute(102)+ " mit der Matrikelnr " + this_user()->query_attribute("MatrikelNr") +"<br>";
    html += "</body></html>";
                                                                                                                             
    return html;
}