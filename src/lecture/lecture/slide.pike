inherit "/classes/Script";

#include <macros.h>

mixed execute(mapping vars)
{
    object obj = find_object((int)vars["id"]);
    object env = obj->get_environment();
    object audios = env->get_object_byname("audio");
    string identifier = obj->get_identifier();
    int id;
    string ext;
    string html = "<html><head><title>"+identifier+"</title></head><body>";
    sscanf(identifier, "Folie%d.%s", id, ext);
    html += "<TABLE><TR><TD>";
    if ( id > 1 ) {
	object prev = env->get_object_byname("Folie"+(id-1)+"."+ext);
	if ( objectp(prev) ) 
	    html += "<a href=\"slide?id="+prev->get_object_id()+
		"\"><img src=\"prev.gif\" border=\"0\"></a>";
    }
    else {
	html += "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
    }
    object next = env->get_object_byname("Folie"+(id+1)+"."+ext);
    if ( objectp(next) )
	html += "<a href=\"slide?id="+next->get_object_id()+
	    "\"><img src=\"next.gif\" border=\"0\"></a>";
    html += "</TD><TD>";
    if ( objectp(audios) ) {
	array files = audios->get_inventory();
	foreach(files, object audio) {
	    string str = audio->get_identifier();
	    int aid;
	    sscanf(str,"%d.mp3", aid);
	    if ( id == aid )
		html += "<a href=\"/scripts/get.pike?object="+
		    audio->get_object_id()+
		    "\"><img src=\"audio.gif\" border=\"0\"></a>";
	}
    }
    html += "</TD><TD align=\"right\"><a href=\"http://pds.upb.de/scripts/show.pike?object="+env->get_object_id()+"\"><img src=\"up.gif\" border=\"0\"></a>";
    
    html += 
	"</TD></TR><TR><TD COLSPAN=\"3\"><img src=\"/scripts/get.pike?object="+
	vars["id"]+"\"/></TD></TR></TABLE></body></html>";
    return html;
}
