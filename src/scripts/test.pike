inherit "/classes/Script";
                                                                                                                             
#include <macros.h>
// #include <database.h> Das brauchen wir (noch) nicht, kann entfernt werden.

string
execute(mapping vars) {
    string html;
	int i = 0;
    html = "<html><head><title>Test</title>\n </head> \n <body>\n";
	html += "Aufgerufen von der Seite: " + this_user()->get_last_trail()->query_attribute(102) +"<br><br>" ;				
	if  (get_group_by_location () != null) {
		html += "Die aktuelle Gruppe ist: " + get_group_by_location ()->query_attribute(102) + " (wird das Skript aus einer \n<br>Untergruppe aufgerufen, wird die Obergruppe angegeben) und hat " + sizeof (get_group_by_location()->get_members(CLASS_USER))  + " Mitglied(er). <br><br>\n";
		html += "Caller ist: " +CALLER->describe() + "<br><br>";
		
		array (object) members = get_group_by_location () ->get_members(CLASS_USER);
		
			if (sizeof (members) != 0) {
			            html += "<table border=1\n><tr><td>Nr</td><td>Name:</td><td>Vorname</td><td>Matrikelnr.</td></tr>\n";
				do {
						html += "<tr>\n<td>" + i + "</td>" 
						     + "<td> "  + members [i]->query_attribute(612)                 +"</td>"
		        	         + "<td>"   + members [i]->query_attribute("user_firstname")    +"</td>"
        		    	     + "<td>"   + members [i]->query_attribute("MatrikelNr")        +"</td></tr>\n";
                			 //+"Studiengang: "  + members [i]->query_attribute("")    +";"
						i++;	
				}
				while (i < sizeof (members));
				
						html += "</table>\n" ;
			}
	
	}


    html += "</body></html>";
                                                                                                                             
    return html;
}

object get_group_by_location (int | void ebene) {

	int i = 0;
                                                                                                           
	array (object) myGroups = this_user()->get_groups();
	
	if (sizeof (myGroups) != 0) {

		do {
			if ( (myGroups [i] ->query_attribute(800)->get_object_id()) == (this_user()->get_last_trail()->get_object_id())) {

				if (myGroups [i]->get_parent() != null) {
					return myGroups [i]->get_parent();
				}
				else {
					return myGroups [i];
				}
			}

			i++;
		}
		while (i < sizeof (myGroups));
	}
		
	return null;
}
