inherit "/classes/Script";

#include <macros.h>
#include <database.h>
#include <access.h>
#include <attributes.h>
#include <classes.h>
#include <config.h>
#include <events.h>
#include <types.h>
#include <roles.h>


string create_user(mapping vars)
{
   object      factory, created;
    string name, password, email;
    object                   msg;
    object                  user;
    object              workroom;
    
    LOG("Creating User:\n"+sprintf("%O", vars));

    name     = vars["nickname"];
    email    = vars["email"];
    user = MODULE_USERS->lookup(name);

    int grp = (int)vars["gruppe"];
    object group = find_object(grp);
    if ( !objectp(group) )
      return result_page("Bitte eine Gruppe auswaehlen !", "anmeldung");
    if ( group->query_attribute(GROUP_MAXSIZE) && 
	 sizeof(group->get_members()) > group->query_attribute(GROUP_MAXSIZE) )
    {
	return error_page("Bitte eine andere Gruppe waehlen - die Gruppe " +
			  group->get_identifier() + " ist bereits voll.",
			  "JavaScript:history.back();");
    }
    if ( vars->pw != vars->pw_repeat ) 
	return error_page("Die Passwoerter stimmen nicht ueberein !",
			  "anmeldung");

    if ( objectp(user) ) {
	if ( !user->check_user_password(vars->pw) )
	    return error_page("Das login '"+name+"' existiert bereits !", 
			      "anmeldung");
    }
    if ( !stringp(email) || sscanf(email, "%*s@%*s.%*s") != 3 ) {
	return error_page("Die E-Mail Adresse ist nicht im korrekten Format!",
			  "anmeldung");
    }
    

    if ( sscanf(vars["pw"], "%s\0", password) != 1 )
	password = vars["pw"];

    vars["attributes"] = ([ 
	"studiengang": vars["studiengang"],
	"MatrikelNr": vars["mnr"],
	]);
    
    if ( !objectp(user) ) {
	mixed err = catch {
	    factory  = _Server->get_factory(CLASS_USER);
	    created = factory->execute(vars);
	    created->activate_user(factory->get_activation());
	};
	if ( arrayp(err) ) {
	    return "<html><body><h2>Error creating user !</h2>\n<h3>"+err[0]+
		"</h3>"+sprintf("%O\n", err[1])+"</body></html>";
	}
    }
    else
	created = user;
    
    group->add_member(created);
    get_module("tasks")->add_task(created, get_module("tasks"),
				  "create_group_exit", ({
				      group, created }),
				  ([ "english": "Create exit to group " + 
				   group->get_identifier(),
				   "german": "Ausgang zur Gruppe " + 
				   group->get_identifier() + " erzeugen", ]));
    if ( objectp(user) )
	return result_page("Der Benutzer wurde in die Gruppe " +
			   group->get_identifier() + " aufgenommen !",
                           "http://"+_Server->query_config(CFG_WEBSERVER)+":"+
                           _Server->query_config(CFG_WEBPORT_URL)+
                           _Server->query_config(CFG_WEBMOUNT)+
                           (group->query_attribute(GROUP_WORKROOM)->query_attribute("url") [1..] )
                          );

    object obj = _FILEPATH->path_to_object("/register/new_user.html");
    return result_page("Das Login ist erfolgreich angelegt worden.",
		       "http://"+_Server->query_config(CFG_WEBSERVER)+":"+
		       _Server->query_config(CFG_WEBPORT_URL)+
		       _Server->query_config(CFG_WEBMOUNT)+
                        ( group->query_attribute(GROUP_WORKROOM)->query_attribute("url") [1..])
                      );
}

/**
 * execute - execute the script
 *  
 * @param vars - variables
 * @return the html representation for an object
 * @author Thomas Bopp (astra@upb.de) 
 */
string|int
execute(mapping vars)
{
    string doc = "";
    object   o;

    if ( vars["_action"] == "register" ) {
	return create_user(vars);
    }
    array(object) groups = do_query_attribute("lecture:groups");
    if ( !arrayp(groups) || sizeof(groups) == 0 ) {
	return result_page("Das Skript ist falsch konfiguriert - es "+
			   "wurden dem Parameter lecture:groups keine "+
			   "Gruppen zugeordnet !", "");
    }
	
    int i = 0;
    if ( sizeof(groups) == 1 ) {
	doc += "<input type=\"hidden\" name=\"gruppe\" value=\""+
	    groups[0]->get_object_id()+"\"/>";
    }
    else {
	int checked = 0;
	doc+="<TR><TD><B>&Uuml;bungsgruppe(n)</B></TD><TD><TABLE>";
	foreach(groups, object grp) {
	    object tutor = grp->query_attribute("tutor");
	    if ( !objectp(tutor) ) 
		return result_page("Das Attribut 'tutor' ist fuer die Gruppe "
				   + grp->get_identifier()+
				   " falsch oder nicht gesetzt.","");
	    if ( !grp->query_attribute("zeit")||!grp->query_attribute("raum") )
		return result_page(
		    "Das Attribut 'zeit' bzw. 'raum' ist fuer die Gruppe "+
		    grp->get_identifier() + " nicht gesetzt.","");


	    doc += "<tr><td><input type=\"radio\" name=\"gruppe\" value=\""+
		grp->get_object_id()+ "\""+ 
		(checked == 0 ? " checked='true'":"")+"/> Raum: "+
		grp->query_attribute("raum")+", Leiter: "+
		(objectp(tutor) ? tutor->query_attribute(USER_FIRSTNAME) +" "+
		 tutor->query_attribute(USER_FULLNAME):"---")+
		", Zeit: "+grp->query_attribute("zeit") +  ", "+		 
		sizeof(grp->get_members()) + " Studenten "+
		(grp->query_attribute(GROUP_MAXSIZE) > 0 ? 
		 "(maximal " + grp->query_attribute(GROUP_MAXSIZE) + ")":"")+
		"<br/></td></tr>\n";
	    checked = 1;
	}
	doc += "</TABLE></TD></TR>\n";
    }
    object rtmp = find_document("/lecture/register.tmpl");
    if ( !objectp(rtmp) )
	return result_page("Die Registrierungs-Template-Datei '/lecture/register.tmpl'"+
			   " wurde nicht gefunden !",
			   "JavaScript:history.back();");

    return html_template(rtmp, ([ "SELECT_GROUP": doc, ]));
}



