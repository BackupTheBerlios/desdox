inherit "/classes/Script";

#include <attributes.h>
#include <database.h>
#include <macros.h>
#include <classes.h>
#include <access.h>
#include <events.h>

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
array(object) get_selected(mapping vars, array(string)|void sels)
{
    array(object) selected = ({ });
    
    array(string) index = ({ });
    if ( !arrayp(sels) ) sels = ({ "objsel", "roomsel", "gateobjsel" });
    
    if ( stringp(vars["popup_id"]) && strlen(vars["popup_id"]) > 0 &&
	(int)vars["popup_id"] != 0 )
	return ({ find_object((int)vars["popup_id"]) });
    
    foreach ( sels, string sel ) {
      LOG("Selecting: "+ sel);
	if ( stringp(vars[sel]) )
	    index += (vars[sel]/"\0");
	else if ( arrayp(vars[sel]) ) {
	  LOG("direct array selection !");
	  index += vars[sel];
	}
    }

    foreach(index, string key) {
	int     oid;
	object  obj;
	if ( sscanf(key, "%d", oid) == 1 && objectp(obj=find_object(oid)) )
	{
	    LOG("Selection of " + oid);
	    selected += ({ obj });
	}
    }
    return selected;
}

mixed set_punkte(object user, int abgabe, float pts)
{
  mapping pkt = query_attribute("punkte");
  if ( !mappingp(pkt) )
    pkt = ([ ]);
  if ( !mappingp(pkt[user]) )
    pkt[user] = ([ abgabe: pts, ]);
  else
    pkt[user][abgabe] = pts;
  return set_attribute("punkte", pkt);
}

static mapping get_punkte(object u)
{
  mapping pkt = query_attribute("punkte");
  if ( mappingp(pkt) && mappingp(pkt[u]) )
    return pkt[u];
  return ([ 1:0.0, 2:0.0, 3:0.0, 4:0.0, 5:0.0, 6:0.0, 7:0.0, 8:0.0, ]);
}

mapping get_my_punkte()
{
    mapping pkt = query_attribute("punkte");
  if ( mappingp(pkt) && mappingp(pkt[this_user()]) )
    return pkt[this_user()];
}

mixed execute(mapping vars)
{
    object obj, bewertung, env, u;
    array(object) selection = get_selected(vars);
    string html, content, msg;
    array users;
    object punkte_obj = this_object();
    
    msg = "";


    switch(vars["_action"]) {
    case "show":
	try_event(EVENT_EXECUTE,CALLER, this());
      mapping m_punkte = query_attribute("punkte");
      html = "";
      foreach ( indices(m_punkte), u ) {
	html += u->get_identifier() + "," + u->query_attribute(USER_FULLNAME) +
	  "," + u->query_attribute("MatrikelNr");
	for ( int i = 1; i < 10; i++ )
	  html += "," + m_punkte[u][i];
	html += "\n";
      }
      return ({ html, "text/plain" });
      break;
    case "set_documentstatus":
	try_event(EVENT_EXECUTE,CALLER, this());

	string str = "";
	string status = 0;
	if ( vars["tutorials_status"] == "1" )
	    status = "processed";
	foreach(selection, obj) {
	    obj->set_attribute("lecture:status", status);
	    str += "setze: "+obj->get_identifier()+" auf bearbeitet! <BR />";
	}
	return result_page(str, "");
	break;
    case "give_points":
	try_event(EVENT_EXECUTE,CALLER, this());

	users = _STEAMUSER->get_members();
	int ufound = 0;
	foreach(users, u) {
	    if ( u->query_attribute("MatrikelNr") == vars["mnr"] ) {
		punkte_obj->set_punkte(u, (int)vars["blatt"], (float)vars["punkte"]);
		ufound = 1;
		break;
	    }
	}
	if ( !ufound ) 
	    return result_page("Der Benutzer mit Matrikelnummer '"+vars["mnr"]+
			       "' wurde nicht gefunden!",
			       "JavaScript:history.back();");
	//	return 
	//redirect("http://pds.upb.de:8080/scripts/execute.pike?script=12702");
	break;
    case "finish":
	object o;
	try_event(EVENT_EXECUTE,CALLER, this());

	obj = find_object((int)vars["object"]);
	int cnt = 0;
	foreach(obj->get_inventory(), o) {
	    if ( o->query_attribute("lecture:status") != "processed" ) 
		cnt++;
	}
	int ltime = obj->query_attribute("lecture:date");
	int abgabe_num;

	abgabe_num = obj->query_attribute("lecture:num");

	object cfactory = _Server->get_factory(CLASS_CONTAINER);
	object cont = cfactory->execute( ([ "name": "Abgabe_"+abgabe_num, ]) );
	cont->set_attribute("lecture:num", abgabe_num);
	cont->set_attribute("lecture:date", ltime);
	array(object) inv = obj->get_inventory();
	foreach(inv, o) {
	    if ( o->query_attribute("lecture:num") == 0 )
		o->move(cont);
	}
	cont->move(obj);
	cont->set_attribute("lecture:end", time()); 
	obj->set_attribute("lecture:date", time());
	obj->set_attribute("lecture:num", abgabe_num+1);
	return result_page("The tutorial rating is finished now.<BR/>"+
			   "&nbsp;&nbsp;"+cnt+" Abgaben nicht bewertet.",
			   "JavaScript:history.back();");
	break;
    case "rated":
	try_event(EVENT_EXECUTE,CALLER, this());

	obj = find_object((int)vars["object"]);
	bewertung = obj->query_attribute("lecture:assessment");
	if ( !objectp(bewertung) )
	{
	    object factory = _Server->get_factory(CLASS_DOCUMENT);
	    bewertung = factory->execute((["name":"bewertung.txt",]));
	    obj->set_attribute("lecture:assessment", bewertung);
	}
	obj->set_attribute("lecture:status", "processed");
	bewertung->set_content(vars["content"]);
	
	object g;

	foreach(indices(vars), string idx) {
	    int uid, aid;
	    float     pp;
	    object    uo;
	    
	    if ( sscanf(idx, "punkte_%d_%d", aid, uid) == 2 ) {
		pp = (float)vars[idx];
		uo = find_object(uid);
		punkte_obj->set_punkte(uo, aid, pp);
	    }
	}
	foreach ( obj->query_attribute("lecture:group"), g ) 
	    bewertung->sanction_object(g, SANCTION_READ);
	msg += "Die Lösung wurde bewertet !";
	break;
    case "rate":
	obj = find_object((int)vars["object"]);
	break;
    case "upload":
	object                    factory; 
	array(object)               group;
	string                drive, path;
	string                        ext;
	string                   mimetype;
	string url = vars["URL.filename"];
	content = vars["URL"];
	
	if ( sscanf(url, "%*s.%s", ext) > 0 )
	    mimetype = _TYPES->query_mime_type(lower_case(ext));
	else
	    mimetype = "text/plain";
	
	object tutor = find_object((int)vars["tutorials_selecttutor"]);
	if ( !objectp(tutor) )
	    return result_page(
		"Übungsgruppenleiter für die Abgabe nicht gefunden.",
		"JavaScript:history.back();");
		
	group = ({ });
	
	if ( stringp(vars["name"]) && strlen(vars["name"]) > 0 )
	    url = vars["name"];
	else
	    url = (url/"\\")[-1];
	string mtnr1= vars["tutorial_mno1"];
	string mtnr2= vars["tutorial_mno2"];
	string mtnr3= vars["tutorial_mno3"];
	string mtnr4= vars["tutorial_mno4"];
	werror("vars="+sprintf("%O\n",vars));
	if ( (int)mtnr1 == 0 ) //|| (int)mtnr2 == 0 ||(int)mtnr3 == 0 )
	    return result_page(
		"Das Übungsblatt muss mit mindestens 1 Person bearbeitet "
		"werden !", "JavaScript:history.back();");
	
	array(string) numbers = ({ mtnr1 });
	if ( (int) mtnr2 != 0 ) numbers += ({ mtnr2 });
	if ( (int) mtnr3 != 0 ) numbers += ({ mtnr3 });
	if ( (int) mtnr4 != 0 ) numbers += ({ mtnr4 });
	
	users = _STEAMUSER->get_members();
	foreach(users, u) {
	    if ( search(numbers, u->query_attribute("MatrikelNr")) >= 0 )
	    {
		if ( search(group, u) >= 0 ) 
		    return result_page(
			"Der Benutzer '"+u->get_identifier()+
			"' wurde mehrfach gefunden!",
			"JavaScript:history.back();");
		group += ({ u });
		numbers -= ({ u->query_attribute("MatrikelNr") });
	    }
	}
	if ( sizeof(numbers) != 0 )
	    return result_page("Die Matrikel Nummer(n) "+(numbers*",") +
			       " wurden nicht gefunden !",
			       "JavaScript:history.back();");

	LOG("URL="+url);
	LOG("Creating new object !");
	factory = _Server->get_factory(CLASS_DOCUMENT);
	obj = factory->execute((["name":url,"mimetype":mimetype,]));
	LOG("environment="+vars["id"]);
	LOG("moving...?");
	object e = find_object((int)vars["id"]);
	if ( objectp(e) ) obj->move(e);
	foreach ( group, object usr)
	    obj->sanction_object(usr, SANCTION_READ);
	
	LOG("Upload of " + strlen(content) + " bytes !");
	function f = obj->receive_content(strlen(content));
	f(content);
	f(0);
	obj->set_attribute(OBJ_DESC, vars["objdesc"]);
	obj->set_attribute("lecture:group", group);
	obj->set_attribute("lecture:tutor", tutor);
	return "<html><head><meta http-equiv=\"refresh\" content=\"0;URL="+
	    "/scripts/navigate.pike?object="+vars["id"]+"\" /></head></html>";
	break;
    }
    env = obj->get_environment();
    html = "<form action=\""+_FILEPATH->object_to_filename(this_object())+"\">"+
	"<input type=\"hidden\" name=\"_action\" value=\"rated\"/>"+
	"<input type=\"hidden\" name=\"object\" value=\""+
	vars["object"]+"\"/>"+
	"<h3>"+obj->get_identifier() + ":" + 
	obj->query_attribute(OBJ_DESC)+"</h3><BR/>"+
	"&nbsp;&gt;&gt;"+msg+"<BR/><BR/>"+
	"Abgegeben von: <BR/>";
    users = obj->query_attribute("lecture:group");

    html += "<table><tr><td>Login</td><td>Name</td><td>MNr.</td>"+
	"<td>Blatt 1</td><td>Blatt 2</td><td>Blatt 3</td><td>Blatt 4</td>"+
	"<td>Blatt 5</td><td>Blatt 6</td><td>Blatt 7</td><td>Blatt 8</td><td>Blatt 9</td></tr>";

    if ( arrayp(users) )
	foreach(users, object u)
	    if ( objectp(u) ) {
		mapping punkte = get_punkte(u); 
 		html += "<tr><td>"+u->get_identifier()+"</td><td>"+
		    u->query_attribute(USER_FULLNAME)+"</td>"+
		    "<td>"+u->query_attribute("MatrikelNr")+"</td>";
		for ( int aufgabe=1; aufgabe<10; aufgabe++ ) {
		    if ( !punkte[aufgabe] )
			punkte[aufgabe] = 0;
		  html += "<td><input type=\"text\" size=\"3\" name=\"punkte_"+aufgabe+"_"+u->get_object_id()+"\" value=\""+sprintf("%.1f",(float)punkte[aufgabe]) + "\"/></td>";
		}
		html += "</tr>";
	    }
    html += "</table>";
    bewertung = obj->query_attribute("lecture:assessment");
    if ( objectp(bewertung) )
	content = bewertung->get_content();
    else
	content = "";
    html += "<textarea name=\"content\" rows=\"20\" cols=\"80\">";
    html  += no_uml(content)+
	"</textarea>\n<BR/><BR/>\n"+
	"&nbsp; <INPUT type=\"submit\" value=\"&gt;&gt; Bewertung abgeben\" CLASS=\"formbutton4\"/><BR/></form>\n";
    return result_page(html,"/scripts/navigate.pike?object="+env->get_object_id());
}
