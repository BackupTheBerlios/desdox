inherit "/net/coal/login";
inherit "/kernel/socket";

#include <macros.h>
#include <database.h>
#include <attributes.h>
#include <events.h>
#include <client.h>

static array(string) queue = ({ });
static mapping command = ([ ]);
static mapping mRegisterKeys = ([ ]);
#if constant(Parser.get_xml_parser)
static Parser.HTML xmlParser = Parser.get_xml_parser();
#else
static object xmlParser = 0;
#endif

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void open_stream()
{
    send_message("<stream:stream from=\""+_Server->query_config("server")+
		 "."+_Server->query_config(CFG_DOMAIN)+"\" "+
		 "xmlns=\"jabber:client\" "+
		 "xmlns=\"http://etherx.jabber.org/streams\">");
}

void close_stream()
{
    send_message("</stream:stream>\n");
    if ( objectp(oUser) )
	oUser->disconnect();
    close_connection();
}

void disconnect()
{
    werror("DISCONNECT !\n");
    oUser->disconnect();
    ::disconnect();
}

void send_iq_result(int code, string|void desc)
{
    if ( !stringp(desc) ) desc = "";

    if ( !stringp(command->iq->id) )
	return;

    if ( code == 0 ) 
	send_message("<iq type=\"result\" id=\""+command["iq"]["id"]+"\">\n"+
		     desc+"</iq>\n");
    else
	send_message("<iq type=\"result\" id=\""+command["iq"]["id"]+"\">\n"+
		     "<error code=\""+code+"\">"+desc+"</error>\n</iq>\n");
}

string name_on_server(string|object user)
{
    string n;

    if ( stringp(user) ) 
	n = user;
    else 
	n = user->get_identifier();
    
    return n + "@"+_Server->query_config("server")+"."
	+_Server->query_config(CFG_DOMAIN);
}

string get_nick(string name)
{
    sscanf(name, "%s@%*s", name);
    return name;
}

void notify(int event, mixed ... args)
{
    werror("notify("+event+"): " + sprintf("%O\n", args));
    switch( event ) {
    case EVENT_LOGIN:
	send_message("<presence from=\""+name_on_server(this_user()) +"\"/>");
	break;
    case EVENT_LOGOUT:
	send_message("<presence type=\"unavailable\" from=\""+
		     name_on_server(args[0]) +"\"/>");
	break;
    case EVENT_TELL:
	send_message("<message type='chat' to=\""+name_on_server(oUser)+
		     "\" from=\""+
		     name_on_server(this_user())+
		     "\"><body>"+args[2]+"</body></message>\n");
	break;
    }
}


mapping get_roster()
{
    mapping roster;
    
    roster = this_user()->query_attribute("JABBER:roster");
    if ( !mappingp(roster) ) {
	roster =  ([ ]);
	array(object) groups = this_user()->get_groups() - ({ _STEAMUSER });
	foreach(groups, object grp) {
	    foreach(grp->get_members(), object u ) 
		roster[u] = "Friends";
	}
	m_delete(roster, this_user());
	this_user()->set_attribute("JABBER:roster", roster);
    }
    return roster;
}

void handle_auth(string user, string pass, string|void digest)
{
    object u = MODULE_USERS->lookup(user);
    if ( stringp(digest) )
	werror("DIGEST="+digest+", MD5="+u->get_password()+"\n");
    if ( u->check_user_password(pass) ) {
	login_user(u);
	mixed res = oUser->listen_to_event(EVENT_TELL, u);
	werror("Result of listening="+sprintf("%O\n",res));
	send_iq_result(0);
	foreach(indices(get_roster()), object user) {
	    oUser->listen_to_event(EVENT_LOGIN, user);
	    oUser->listen_to_event(EVENT_LOGOUT, user);
	}
    }
    else {
	send_iq_result(401, "Unauthorized");
    }
}

void handle_roster()
{
    object u;
    mapping roster = get_roster();
    string result = "<query xmlns=\"jabber:iq:roster\">\n";

    if ( command->iq->type == "get" ) {
	foreach(indices(roster), u) {
	    result += "<item jid=\""+name_on_server(u)+"\""+
		" name=\""+u->get_identifier()+
		"\" subscription=\"both\">"+
		" <group>"+roster[u]+"</group></item>";
	}
	result += "</query>";
	send_iq_result(0, result);
    }
    else if ( command->iq->type == "set" ) {
	string nick = get_nick(command->item->jid);
	string gname = command->item->group;
	if ( !stringp(gname) ) gname = "Friends";
	
	u = MODULE_USERS->lookup(nick);
	if ( command->item->subscription == "remove" ) {
	    result += "<item jid=\""+name_on_server(u)+"\""+
		" name=\""+u->get_identifier()+
		"\" subscription=\"remove\">"+
		" <group>"+roster[u]+"</group></item>";
	    m_delete(roster, u);
	    this_user()->set_attribute("JABBER:roster", roster);
	}
	else {
	    if ( !stringp(roster[u]) ) {
		// see if user is online
		oUser->listen_to_event(EVENT_LOGIN, u);
		oUser->listen_to_event(EVENT_LOGOUT, u);
	    }
	    roster[u] = gname;
	    this_user()->set_attribute("JABBER:roster", roster);
	    result += "<item jid=\""+name_on_server(u)+"\""+
		" name=\""+u->get_identifier()+"\" subscription='to'>" +
		" <group>"+gname+"</group> </item>";
	}
	result += "</query>";
	send_iq_result(0, result);
	send_message(
	    "<iq type=\"set\" to=\""+name_on_server(this_user())+"\">"+
	    result+"</iq>\n");
	if ( u->get_status() & CLIENT_FEATURES_CHAT )
	    send_message("<presence from='"+name_on_server(u)+"' />\n");
    }
}

void handle_vcard()
{
    mixed err;
    // whom ???
    string nick = get_nick(command->iq->to);

    object u = MODULE_USERS->lookup(nick);
    if ( objectp(u) ) {
	string uname = u->query_attribute(USER_FULLNAME);
	string gname,sname, email;
	sscanf(uname, "%s %s", gname, sname);
	err = catch {
	    email = u->query_attribute(USER_EMAIL);
	};
	send_message("<iq type=\"result\" from=\""+command->iq->to+"\" id=\""+
		     command->iq->id+"\">"+
		     "<vCard xmlns=\"vcard-temp\">\n"+
		     "<N><FAMILY>"+ sname + "</FAMILY>"+
		     "<GIVEN>"+gname+"</GIVEN>"+
		     "<MIDDLE/></N>\n"+
		     "<NICKNAME>"+u->get_identifier()+"</NICKNAME>"+
		     "<TITLE/>"+
		     "<ROLE/>"+
		     "<TEL/>"+
		     "<ADR/>"+
		     "<EMAIL>"+email+"</EMAIL>"+
		     "</vCard>"+
		     "</iq>\n");
	    
    }
    else {
	send_iq_result(400, "No Such User");
    }
}

void handle_register()
{
    if ( command->iq->type == "get" ) {
	string uname = get_nick(command->iq->to);
	object u = MODULE_USERS->lookup(uname);
	if ( objectp(u) ) {
	    send_message("<iq type=\"result\" from=\""+command->iq->to+
			 "\" to=\""+name_on_server(this_user()) + "\" id=\""+
			 command->id->id+"\">\n"+
			 "<query xmlns=\"jabber:iq:register\">\n"+
			 "<registered />"+
			 "</query>\n"+
			 "</iq>\n");
	}
	else {
	    send_message("<iq type=\"result\" from=\""+command->iq->to+
			 "\" to=\""+name_on_server(this_user()) + "\" id=\""+
			 command->id->id+"\">\n"+
			 "<query xmlns=\"jabber:iq:register\">\n"+
			 "<username />"+
			 "<password />"+
			 "</query>\n"+	
		 "</iq>\n");
	}
    }
}

void handle_private()
{
}

void handle_iq()
{
    if ( command->vCard ) {
	handle_vcard();
    }
    if ( command->query ) {
	switch(command["query"]["xmlns"]) {
	case "jabber:iq:auth":
	    if ( mappingp(command->password) )
		handle_auth(command["username"]->data, 
			    command["password"]->data);
	    else
		handle_auth(command->username->data, 0,
			    command->digest->data);
	    break;
	case "jabber:iq:roster":
	    handle_roster();
	    break;
	case "jabber:iq:register":
	    handle_register();
	    break;
	case "jabber:iq:agents":
	    // deprecated anyway
	    send_message("<iq id='"+command->iq->id+"' type='result'>"+
			 "<query xmlns='jabber:iq:agents' /> </iq>\n");
	    break;
	case "jabber:iq:private":
	    handle_private();
	    break;
	}
    }
}

void handle_message()
{
    string nick = command->message->to;
    sscanf(nick, "%s@%*s", nick);
   
    object u = MODULE_USERS->lookup(nick);
    if ( objectp(u) ) {
	u->message(command->body->data);
    }
       
}

void handle_presence()
{
    if ( stringp(command->presence->to) ) {
	string uname = get_nick(command->presence->to);
	// TODO: handle subscription
#if 1
	if ( command->presence->type == "subscribe" )
	    send_message("<presence from=\""+command->presence->to+"\" "+
			 "to=\""+name_on_server(this_user())+"\" "+
			 "type=\"subscribed\" />\n");
#endif
    }
    else {
	send_message("<presence from=\""+name_on_server(this_user())+"\"/>\n");
	foreach(indices(get_roster()), object u) {
	    if ( u != oUser && u->get_status() & CLIENT_FEATURES_CHAT ) {
		send_message("<presence from=\""+
			     name_on_server(u)+"\"/>");
	    }
	}
    }
}

void handle_command(string cmd)
{
    master()->set_this_user(this_object());
    werror("HANDLE_COMMAND: "+cmd+"\n"+sprintf("%O\n",command));
    switch(cmd) {
    case "presence":
	handle_presence();
	break;
    case "iq":
	handle_iq();
	break;
    case "message":
	handle_message();
	break;
    }
    command = ([ ]);
}

private static int data_callback(Parser.HTML p, string data)
{
    if ( sizeof(queue) == 0 )
	return 0;
    string name = queue[-1];
    command[name]["data"] = data;
    return 0;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
private static int tag_callback(Parser.HTML p, string tag)
{
    string name;
    mapping attr = ([ ]);
    if ( tag[-2] == '/' ) {
	attr["/"] = "/";
	tag[-2] = ' ';
    }
    attr += p->parse_tag_args(tag);
    
    foreach(indices(attr), string a ) {
	if ( a != "/" && attr[a] == a ) {
	    name = a;
	    m_delete(attr, name);
	    break;
	}
    }

    werror("TAG:"+name+"\n");
    if ( name == "stream:stream" ) {
	open_stream();
    }
    else if ( name == "/stream:stream" ) {
	werror("Closing jabba stream !!!\n");
	close_stream();
    }
    else if ( name[0] == '/' ) {
	if ( name[1..] == queue[-1] ) {
	    if ( sizeof(queue) == 1 ) {
		queue = ({ });
		handle_command(name[1..]);
	    }
	    else {
		queue = queue[..sizeof(queue)-2];
	    }
	}
	else {
	    werror("Mismatched tag: " + name);
	}
    }
    else if ( attr["/"] == "/" ) {
	m_delete(attr, "/");
	command[name] = attr;
	if ( sizeof(queue) == 0 ) {
	    handle_command(name);
	}
    }
    else {
	queue += ({ name });
	command[name] = attr;
    }
    return 0;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
static void read_callback(mixed id, string data)
{
    werror("READ:\n"+data+"\n");
    xmlParser->feed(data);
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
static void send_message(string msg)
{
    LOG("MESSAGE: " + msg);
    ::send_message(msg);
}

static void create(object f)
{
    ::create(f);
    xmlParser->_set_tag_callback(tag_callback);
    xmlParser->_set_data_callback(data_callback);
}

int get_client_features() { return CLIENT_FEATURES_ALL; }
