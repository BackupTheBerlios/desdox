/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

//! this is the user object. It keeps track of connections and membership
//! in groups.

inherit "/classes/Container" : __cont;
inherit "/base/member" :     __member;

#include <attributes.h>
#include <assert.h>
#include <macros.h>
#include <events.h>
#include <coal.h>
#include <classes.h>
#include <database.h>
#include <access.h>
#include <types.h>
#include <client.h>
#include <config.h>

//#define EVENT_USER_DEBUG

#ifdef EVENT_USER_DEBUG
#define DEBUG_EVENT(s, args...) werror(s+"\n", args)
#else
#define DEBUG_EVENT(s, args...)
#endif

/* Security relevant functions */
private static string  sUserPass; // the password for the user
private static string sPlainPass;
private static string  sUserName; // the name of the user
private static object oActiveGrp; // the active group
private static int  iCommandTime; // when the last command was send

private static string         sTicket;
private static array(string) aTickets;
private static int        iActiveCode;

        static array(object)    aoSocket; // array of socket connected
        static mapping       mMoveEvents;
private static mapping     mSocketEvents;


object this() { return __cont::this(); }
bool   check_swap() { return false; }
bool   check_upgrade() { return false; }

static void 
init()
{
    ::init();
    ::init_member();
    aoSocket      = ({ });
    mSocketEvents = ([ ]);
    sTicket       = 0;
    
    /* the user name is a locked attribute */
    add_data_storage(store_user_data, restore_user_data);
}

/**
 * Constructor of the user object.
 *
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static void
create_object()
{
    ::create_object();

    sUserName  = "noone";
    sUserPass  = "steam";
    sPlainPass = 0;

    sTicket     = 0;
    aTickets    = ({ });
    iActiveCode = 0;
}

/**
 * Creating a duplicate of the user wont work.
 *  
 * @return throws an error.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
object duplicate()
{
    THROW("User cannot be duplicated !\n", E_ERROR);
}

/**
 * register the object in the database.
 *  
 * @param name - the name of the object
 * @author Thomas Bopp (astra@upb.de) 
 */
static void database_registration(string name)
{
    MODULE_USERS->register(name, this());
}

/**
 * Destructor of the user.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see create
 */
static void
delete_object()
{
    mixed err;

    if ( this() == MODULE_USERS->lookup("root") )
	THROW("Cannot delete the root user !", E_ACCESS);

    MODULE_USERS->unregister(sUserName);
    object mailbox = do_query_attribute(USER_MAILBOX);
    // delete the mailbox recursively
    if ( objectp(mailbox) ) {
	foreach(mailbox->get_inventory(), object inv) {
	    err = catch {
		inv->delete();
	    };
	}
	err = catch {
	    mailbox->delete();
	};
    }
    err = catch {
	object workroom = do_query_attribute(USER_WORKROOM);
	workroom->delete();
    };
    
    __member::delete_object();
    __cont::delete_object();
}

/**
 * Dont update a users name.
 */
void update_identifier()
{
}

/**
 * Create all the exits to the groups the user is member of.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void create_group_exits()
{
    object workroom = do_query_attribute(USER_WORKROOM);
    if ( objectp(workroom) ) {
	array(object) inv = workroom->get_inventory();
	array(object) groups = get_groups();
	mapping mExits = ([ ]);
	
	foreach ( groups, object grp ) {
	    if ( !objectp(grp) ) continue;
	    mapping exits = grp->query_attribute(GROUP_EXITS);
	    if ( !mappingp(exits) ) {
		object workroom = grp->query_attribute(GROUP_WORKROOM);
		exits = ([ workroom: workroom->get_identifier(), ]);
	    }
	    mExits += exits;
	}
	foreach ( indices(mExits), object exit ) {
	    bool       found_exit;

	    if ( !objectp(exit) ) 
		continue;
	    found_exit = false;
	    foreach ( inv, object o ) {
		if ( o->get_object_class() & CLASS_EXIT ) {
		    object exit_to = o->get_link_object();
		    if ( !objectp(exit_to) )
                       continue;
		    if ( exit_to->get_object_id() == exit->get_object_id() )
			found_exit = true;
		}
	    }
	    if ( !found_exit ) {
		object factory = _Server->get_factory(CLASS_EXIT);
		object exit = factory->execute(
		    ([ "name": mExits[exit], "exit_to": exit, ]) );
		exit->sanction_object(this(), SANCTION_ALL);
		exit->move(workroom);
	    }
	}
    }
}

/**
 * Connect the user object to a steamsocket.
 *  
 * @param obj - the steamsocket to connect to
 * @return the time of the last login
 * @author Thomas Bopp 
 * @see disconnect
 * @see which_socket
 */
int
connect(object obj)
{
    int last_login, i;
    
    LOG("New connection attempt: allready " + sizeof(aoSocket) + 
	" sockets connected to user !\n");
    LOG("Connecting "+ get_identifier()+" with "+ obj->describe()+"\n");

    if ( !IS_SOCKET(CALLER) )
	THROW("Trying to connect user to non-steamsocket !", E_ACCESS);
    
    for ( i = sizeof(aoSocket) - 1; i >= 0; i-- ) {
	if ( aoSocket[i] == obj )
	    return 0;
    }
    int features = CALLER->get_client_features();
    int prev_features = get_status();
    try_event(EVENT_LOGIN, this(), features, prev_features);

    aoSocket += ({ obj });
    aoSocket -= ({ 0 });

    last_login = do_query_attribute(USER_LAST_LOGIN);
    set_attribute(USER_LAST_LOGIN, time());
    
    if ( (prev_features & features) != features ) 
	run_event(EVENT_STATUS_CHANGED, this(), features, prev_features);

    run_event(EVENT_LOGIN, this(), features, prev_features);

    if ( objectp(oEnvironment) ) 
	oEnvironment->enter_system(this());

    return last_login;
}

/**
 * Close the connection to socket and logout.
 *  
 * @param obj - the object to remove from active socket list
 * @author Thomas Bopp (astra@upb.de) 
 * @see disconnect
 */
static void
close_connection(object obj)
{
    if ( which_socket(obj) < 0 ) return;
    
    try_event(EVENT_LOGOUT, CALLER, obj);

    if ( sizeof(aoSocket) == 0 ) {
	MESSAGE(sUserName+": No open connection - removing all events !");
	remove_all_events(); // clear event list !
    }
    aoSocket -= ({ obj });

    int cfeatures = obj->get_client_features();
    int features = get_status();

    if ( (cfeatures & features) != cfeatures ) 
	run_event(EVENT_STATUS_CHANGED, this(), cfeatures, features);

    ASSERTINFO(which_socket(obj) < 0, "Still connected to socket !");
    MESSAGE(sUserName+": logout event....");
    run_event(EVENT_LOGOUT, CALLER, obj);
}

/**
 * Disconnect the CALLER socket from this user object.
 *  
 * @author Thomas Bopp (astra@upb.de) 
 * @see connect
 */
void disconnect()
{
    object socket = CALLER;
    int             status;

    if ( which_socket(socket) == -1 )
      return; 
    
    if ( arrayp(mSocketEvents[socket]) ) {
	foreach ( mSocketEvents[socket], mixed event_data )
	    if ( arrayp(event_data) )
		remove_event(@event_data);
    }
    // get the remaining status of the user
    status = 0;
    foreach ( aoSocket, object sock ) {
	if ( objectp(sock) && sock != socket ) {
	    status |= sock->get_client_features();
	}
    }
    // if the user has no more chat and awareness clients notify
    // the environment about logged out
    if ( objectp(oEnvironment) && 
	 !(status & CLIENT_FEATURES_CHAT) &&
	 !(status & CLIENT_FEATURES_AWARENESS) )
	oEnvironment->leave_system(this());
    

#ifdef MOVE_WORKROOM
    // if this is a client which allows movement of the user
    // then move the user back to its workroom
    if ( !(status & CLIENT_FEATURES_MOVE) ) 
    {
	object workroom = do_query_attribute(USER_WORKROOM);
	if ( oEnvironment != workroom ) {
	    LOG("Closing down connection to user - moving to workroom !");
	    set_attribute(USER_LOGOUT_PLACE, oEnvironment);
	    if ( objectp(workroom) )
		move(workroom);
	}
    }
#endif
    close_connection(socket);
}

/**
 * find out if the object is one of the connected sockets
 *  
 * @param obj - the object to find out about
 * @return the position of the socket in the socket array
 * @author Thomas Bopp (astra@upb.de) 
 * @see connect
 * @see disconnect
 */
static int 
which_socket(object obj)
{
    int i;
    for ( i = sizeof(aoSocket) - 1; i >= 0; i-- )
	if ( aoSocket[i] == obj )
	    return i;
    return -1;
}

/**
 * Activate the login. Successfull activation code is required to do so!
 *  
 * @param int activation - the activation code
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool activate_user(int|void activation)
{
    if ( activation == iActiveCode || _ADMIN->is_member(this_user()) ) {
	iActiveCode = 0;
	return true;
    }
    return false;
}

/**
 * Set the activation code for an user - this is done by the factory.
 *  
 * @param int activation - the activation code.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see activate_user
 */
void set_activation(int activation)
{
    if ( CALLER != _Server->get_factory(CLASS_USER) && 
	 !_ADMIN->is_member(this_user()) )
	THROW("Invalid call to set_activation !", E_ACCESS);
    iActiveCode = activation;
}

/**
 * Find out if the user is inactivated.
 *  
 * @return activation code set or not.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
bool get_activation()
{
    return iActiveCode != 0;
}

/**
 * Check if a given password is correct. Users can authenticate with their
 * password or with temporary tickets. There are one time tickets and
 * tickets which last for acertain time encoded in the ticket itself.
 * Authentication will always fail if the user is not activated.
 *  
 * @param pw - the password to check
 * @param uid - the user object
 * @return if the password matches or not
 * @author Thomas Bopp (astra@upb.de) 
 */
bool check_user_password(string pw)
{
    if ( !stringp(pw) || !stringp(sUserPass) )
	return false;

    if ( iActiveCode ) {
	LOG("Trying to authenticate with inactivated user !");
	return false; // as long as the login is not activated
    }
    
    if ( stringp(sTicket) ) 
    {
	if ( pw == sTicket ) {
	    sTicket = 0; // ticket used
	    return true;
	}
    }
    if ( arrayp(aTickets) && sizeof(aTickets) > 0 ) {
	array tickets = copy_value(aTickets);
	foreach(tickets, string ticket) {
	    int t;
	    sscanf(ticket, "%*s_%d", t);
	    if ( t < time() ) {
		aTickets -= ({ ticket });
		require_save();
	    }
	    else if ( pw == ticket )
		return true;
	}
    }
    if ( strlen(sUserPass) < 3 || sUserPass[0..2] != "$1$" ) 
	return crypt(pw, sUserPass); // normal crypt check
    return sUserPass == Crypto.crypt_md5(pw, sUserPass);
}

bool check_user_password_plain(string pw)
{
    return (sPlainPass == Crypto.crypt_md5(pw, sPlainPass) ||
	    sUserPass == Crypto.crypt_md5(pw, sUserPass) );
}

/**
 * Transform a string in some other characters.
 *  
 * @param string what the string to convert.
 * @return converted string.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
private static string tohex(string what)
{
    int i = 0;
    for ( int q = 0; q < strlen(what); q++ ) {
	i <<= 8;
	i |= what[strlen(what)-1-q];
    }
    return sprintf("%x", i);
}

/**
 * Get a ticket from the server - authenticate to the server with
 * this ticket once.
 *  
 * @return the ticket
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see check_user_password
 */
final string get_ticket(void|int t)
{
    if ( !IS_SOCKET(CALLER) && !_SECURITY->access_write(this(), CALLER) )
	THROW("Invalid call to get_ticket() !", E_ACCESS);

    string ticket = "        ";
    for ( int i = 0; i < 8; i++ )
	ticket[i] = random(26) + 'a';
    ticket = tohex(ticket + time());

    if ( !zero_type(t) ) {
	ticket += "_" + t;
	aTickets += ({ ticket });
	require_save();
	return ticket;
    }
	
    sTicket = ticket;
    return sTicket;
}


/**
 * Set the user password and save an md5 hash of it.
 *  
 * @param pw - the new password for the user
 * @return if successfull
 * @author Thomas Bopp (astra@upb.de) 
 * @see check_user_pasword
 */
bool
set_user_password(string pw, int|void crypted)
{
    try_event(EVENT_USER_CHANGE_PW, CALLER);
    if(crypted)
      sUserPass = pw; 
    else
      sUserPass = Crypto.crypt_md5(pw);
    require_save();
    run_event(EVENT_USER_CHANGE_PW, CALLER);
    return true;
}

bool
set_user_password_plain(string pw, int|void crypted)
{
    try_event(EVENT_USER_CHANGE_PW, CALLER);
    if(crypted)
      sPlainPass = pw; 
    else
      sPlainPass = Crypto.crypt_md5(pw);
    require_save();
    run_event(EVENT_USER_CHANGE_PW, CALLER);
    return true;
}


/**
 * Get the password of the user which should be fine since
 * we have an md5 hash. This is used to import/export users.
 *  
 * @return the users password.
 */
string
get_user_password(string pw)
{
    return copy_value(sUserPass);
}

/**
 * Get the user object of the user which is this object.
 *  
 */
object get_user_object()
{
  return this();
}

/**
 * Get the sTeam e-mail adress of this user. Usually its the users name
 * on _Server->get_server_name() ( if sTeam runs smtp on port 25 )
 *  
 * @return the e-mail adress of this user
 */
string get_steam_email()
{
    return sUserName  + "@" + _Server->get_server_name();
}

/**
 * set the user name, which is only allowed for the factory.
 *  
 * @param string name - the new name of the user.
 */
void 
set_user_name(string name)
{
    if ( !_Server->is_factory(CALLER) && stringp(sUserName) )
	THROW("Calling object not trusted !", E_ACCESS);
    sUserName = name;
    do_set_attribute(OBJ_NAME, name);
    require_save();
}

string
get_user_name()
{
  return copy_value(sUserName);
}

/**
 * Get the complete name of the user, that is first and lastname.
 * Last name attribute is called FULLNAME because of backwards compatibility.
 *  
 * @return the first and last name
 */
string get_name()
{
    return do_query_attribute(USER_FIRSTNAME) + " " + 
	do_query_attribute(USER_FULLNAME);
}


/**
 * restore the use specific data
 *  
 * @param data - the unserialized data of the user
 * @author Thomas Bopp (astra@upb.de) 
 * @see store_user_data
 */
void 
restore_user_data(mixed data)
{
    if ( CALLER != _Database ) 
	return;

    sUserName    = data["UserName"];
    sUserPass    = data["UserPassword"];
    sPlainPass   = data["PlainPass"];
    if ( !stringp(sPlainPass) )
	sPlainPass = "";
    aoGroups     = data["Groups"];
    iActiveCode  = data["Activation"];
    aTickets     = data["Tickets"];
    oActiveGrp = data["ActiveGroup"];
    if ( !arrayp(aTickets) )
	aTickets = ({ });

    LOG("Restored User ["+sUserName+"]");
    ASSERTINFO(arrayp(aoGroups),"Group is not an array !");
    LOG("Restoring Userdata of "+sUserName+" Groups="+sizeof(aoGroups));
}

/**
 * returns the userdata that will be stored in the Database
 *  
 * @return array containing user data
 * @author Thomas Bopp (astra@upb.de) 
 * @see restore_user_data
 */
mapping
store_user_data()
{
    if ( CALLER != _Database ) return 0;

    return ([ 
	"UserName":sUserName,
	"UserPassword":sUserPass, 
	"PlainPass":sPlainPass,
	"Groups": aoGroups,
	"Activation": iActiveCode,
	"Tickets": aTickets,
	"ActiveGroup": oActiveGrp,
	]);
}


/**
 * the event listener function. The event is automatically send
 * to the client.
 *  
 * @param event - the type of event
 * @param args - the different args for each event
 * @return ok
 * @author Thomas Bopp (astra@upb.de) 
 * @see listen_event
 */
final int notify_event(int event, mixed ... args)
{
    int                 i;
    array(object) sockets;

    DEBUG_EVENT(sUserName+":notify_event("+event+",....)");
    sockets = copy_value(aoSocket);
    
    if ( !arrayp(sockets) || sizeof(sockets) == 0 )
	return EVENT_OK;
	
    for ( i = sizeof(sockets) - 1; i >= 0; i-- ) {
	if ( objectp(sockets[i]) ) {
	    if ( !objectp(sockets[i]->_fd) ) {
		LOG("Closing connection...\n");
		close_connection(sockets[i]);
		continue;
	    }
	    if ( sockets[i]->get_client_features() & CLIENT_FEATURES_EVENTS ){
                LOG("Notifying socket " + i + " about event: " + event);
		sockets[i]->notify(event, @args);
	    }
	}
    }
    return EVENT_OK;
}

/**
 * Check if an object is observed by this user.
 *  
 * @param obj - the object to observe
 * @return true or false
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static bool observe_events(object obj)
{
    if ( !(obj->get_object_class() & CLASS_CONTAINER) )
	return false;

    mapping myEvents = get_my_events();
    if ( (!mappingp(myEvents[EVENT_SAY][obj]) || 
	  sizeof(myEvents[EVENT_SAY][obj]) == 0 ) &&
	 (!mappingp(myEvents[EVENT_ENTER_INVENTORY][obj]) || 
	  sizeof(myEvents[EVENT_ENTER_INVENTORY][obj]) == 0 ) &&
	 (!mappingp(myEvents[EVENT_LEAVE_INVENTORY][obj]) || 
	  sizeof(myEvents[EVENT_LEAVE_INVENTORY][obj]) == 0 ) )
	return false;
    return true;
}

/**
 * Private command called by the client to listen to different events
 * in the system. The id of an event is send back to the client, which
 * must call remove_event in order to remove the event again.
 *  
 * @param event - the event type
 * @param obj - the object to listen to
 * @return the ids of the events
 * @author Thomas Bopp (astra@upb.de) 
 * @see notify_event
 * @see dispose_event
 */
final array(int)
listen_to_event(int|array(int) events, object obj)
{
    int        i, id, mask, event_id;
    array(int)                   res;
    mixed                        err;

    res = ({ });

    DEBUG_EVENT("listen_to_event(%s,%O,%s(%d))", sUserName,
		events, obj->get_identifier(), obj->get_object_id());

    ASSERTINFO(which_socket(CALLER) >= 0, "Caller is not the socket !");

    if ( !arrayp(mSocketEvents[CALLER]) )
	mSocketEvents[CALLER] = ({ });
    
    if ( !arrayp(events) ) {
	mask = events & 0xf0000000;
	for ( i = 0; i < 28; i++ ) {
	    if (  (id = events & (1<<i)) > 0 ) {
	      err = catch (event_id = 
			   add_event(obj, mask|id,PHASE_NOTIFY,notify_event));
	      if ( err != 0 ) {
		event_id = -1;
		throw(err);
	      }
	      
	      res += ({ event_id });
	      mSocketEvents[CALLER] += ({ ({ obj, events, notify_event }) });
	    }
	}
    }
    else {
	for ( i = 0; i < sizeof(events); i++ ) {
	  err = catch (event_id = 
		       add_event(obj, events[i], PHASE_NOTIFY, notify_event));
	  if ( err != 0 ) {
	    FATAL("While listening to event: %s\n%O", err[0], err[1]);
	    event_id = -1;
	    throw(err);
	  }
	  mSocketEvents[CALLER] += ({ event_id });
	  mSocketEvents[CALLER] += ({ ({obj, events[i], notify_event}) });
	}
    }
    
    return res;
}

/**
 * removes an event from the list of events. The event-id and type
 * must be remembered by the client (at listen_event) and used for
 * the function call.
 *  
 * @param event - the event type
 * @param event_id - the id for the event
 * @param obj - the relevant object
 * @author Thomas Bopp (astra@upb.de) 
 * @see listen_event
 */
final int
dispose_event(int|array(int) events, object obj)
{
    int i, res;

    //ASSERTINFO(which_socket(CALLER) >= 0, "Caller is not the socket !");

    LOG("dispose_event("+sprintf("%O",events)+","+obj->get_identifier()+")");
    if ( !arrayp(events) )
	events = ({ events });
    
    for ( i = 0, res = 0; i < sizeof(events); i++ ) 
	res += (remove_event(obj, events[i], notify_event) == true);
    
  
    return res;
}

/**
 * Get the annotations, eg e-mails of the user.
 *  
 * @return list of annotations
 */
array(object) get_annotations()
{
    object mb = do_query_attribute(USER_MAILBOX);
    if ( objectp(mb) ) {
	// import messages from mailbox
	foreach ( mb->get_inventory(), object importobj) {
	    catch(add_annotation(importobj));
            importobj->set_acquire(0);
	    importobj->sanction_object(this(), SANCTION_ALL);
	}
	do_set_attribute(USER_MAILBOX, 0);
    }
    return ::get_annotations();
}

/**
 * Get the mails of a user.
 *  
 * @return array of objects of mail documents
 */
array(object) get_mails(void|int from_obj, void|int to_obj)
{
  array(object) mails = get_annotations();
  if ( sizeof(mails) == 0 )
    return mails;
  
  if ( !intp(to_obj) )
    to_obj = sizeof(mails);
  if ( !intp(from_obj) )
    from_obj = 1;
  return mails[from_obj-1..to_obj-1];
}

object get_mailbox()
{
    return this(); // the user functions as mailbox
}


/**
 * Mail the user some message by using steams internal mail system.
 *  
 * @param string msg - the message body.
 * @param string|void subject - an optional subject.
 * @return the created mail object or 0.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
final object 
mail(string|object|mapping msg, string|mapping|void subject,void|string sender)
{
    object factory = _Server->get_factory(CLASS_DOCUMENT);
    object user = this_user();
    object message;

    werror("mail("+sprintf("msg=%O\nsubject=%O", msg, subject)+")\n");
    if ( !objectp(user) ) user = _ROOT;
    if ( mappingp(subject) )
	subject = subject[user->query_attribute("language")||"german"];
    if ( !stringp(subject) ) 
	subject = "Message from " + user->get_identifier();

    if ( objectp(msg) ) {
      message = msg;
    }
    else {
      message = factory->execute( 
				 ([ "name": subject,
				    "mimetype": "text/html", ]) );
      if ( mappingp(msg) ) 
	msg = msg[user->query_attribute("language")||"german"];
      message->set_attribute(OBJ_DESC, subject);
      message->set_content(msg);
    }
    do_add_annotation(message);
    // give message to the user it was send to
    message->sanction_object(this(), SANCTION_ALL);
    if ( objectp(this_user()) )
      message->sanction_object(this_user(), 0); // remove permissions of user
    message->set_acquire(0); // make sure only the user can read it

    if ( do_query_attribute(USER_FORWARD_MSG) == 1 ) { 
	string email = do_query_attribute(USER_EMAIL);
	if ( stringp(email) && strlen(email) > 0 && search(email, "@") > 0)
	{
	  if ( message->query_attribute(MAIL_MIMEHEADERS) )
	    get_module("smtp")->send_mail_mime(do_query_attribute(USER_EMAIL), message);
	  else {
	    string from = user->get_steam_email();
	    
	    if ( (!stringp(from) || search(from, "@") == -1) )
	      from = sender;
	    
	    get_module("smtp")->send_mail(do_query_attribute(USER_EMAIL),
					  "[sTeam] "+
					  message->query_attribute(OBJ_NAME),
					  message->get_content(),
					  from, sender);
	  }
	}
    }
    return message;
}

/**
 * public tell (and private tell) will send a mail to the user
 * if there is no chat-socket connected.
 *  
 * @param msg - the msg to tell
 * @author Thomas Bopp (astra@upb.de) 
 * @see private_tell
 */
final bool 
message(string msg)
{
    try_event(EVENT_TELL, this_user(), msg);

    // no steam client connected - so user would not see message

    run_event(EVENT_TELL, this_user(), msg);
    return true;
}


/**
 * Get the current status of the user object. This goes through all
 * connected sockets and checks their features. The result of the function
 * are all features of the connected sockets.
 *  
 * @return features of the connected sockets.
 * @author Thomas Bopp (astra@upb.de) 
 */
int get_status(void|int stats)
{
    array(object) nSockets = ({ });
    int status                 = 0;

    foreach ( aoSocket, object socket ) {
	if ( objectp(socket) ) {
	    status |= CLIENT_STATUS_CONNECTED;
	    status |= socket->get_client_features();
	    nSockets += ({ socket });
	}
    }
    aoSocket = nSockets;
    if ( zero_type(stats) )
	return status;
    return status & stats;
}

/**
 * check if a socket with some connection class exists
 *  
 * @param clientClass - the client class to check
 * @return if a socket with the client class is present
 * @author Thomas Bopp (astra@upb.de) 
 */
bool connected(string clientClass) 
{
    foreach ( aoSocket, object socket ) {
	if ( objectp(socket) ) {
	    if ( socket->get_client_class() == clientClass )
		return true;
	}
    }
    return false;
}

/**
 * Set the active group - can only be called by a socket of the user
 *  
 * @param object grp - the group to be activated.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_active_group
 */
void set_active_group(object grp) 
{
    if ( search(aoGroups, grp) == -1 ) 
	THROW("Trying to activate a group the user is not member of !",
	      E_ACCESS);

    oActiveGrp = grp;
    require_save();
}

/**
 * Returns the currently active group of the user
 *  
 * @return The active group or the steam-user group.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see set_active_group
 */
object get_active_group()
{
    if ( !objectp(oActiveGrp) )
	return _STEAMUSER;
    return oActiveGrp;
}

/**
 * Called when a command is done. Only sockets can call this function.
 *  
 * @param t - time of the command
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see get_idle
 */
void command_done(int t)
{
    if ( !IS_SOCKET(CALLER) )
	THROW("Invalid call to command_done() !", E_ACCESS);
    iCommandTime = t;
}

/**
 * Get the idle time of the user.
 *  
 * @return the time the user has not send a command
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see command_done
 */
int get_idle()
{
    return time() - iCommandTime;
}

/**
 * Check if it is possible to insert a given object in the user container.
 *  
 * @param object obj - the object to insert.
 * @return true
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
static bool check_insert(object obj)
{
    return true;
}


void add_trail(object visit, int max_size)
{
    array aTrail = do_query_attribute("trail");
    if ( !arrayp(aTrail) ) 
	aTrail = ({ visit });
    else {
	if ( visit == aTrail[-1] )
	    return;
	aTrail += ({ visit });
	if ( sizeof(aTrail) > max_size )
	    aTrail = aTrail[sizeof(aTrail)-max_size..];
    }
    set_attribute("trail", aTrail);
}

array(object) get_trail()
{
    return do_query_attribute("trail");
}

object get_last_trail()
{
    array rooms =  do_query_attribute("trail");
    if ( arrayp(rooms) )
	return rooms[-1];
    return 0;
}

mixed move(object to)
{
    add_trail(to, 20);
    return ::move(to);
}

int __get_command_time() { return iCommandTime; }
int get_object_class() { return ::get_object_class() | CLASS_USER; }
final bool is_user() { return true; }

/**
 * Get a list of sockets of this user.
 *  
 * @return the list of sockets of the user
 * @author Thomas Bopp (astra@upb.de) 
 */
array(object) get_sockets()
{
    return copy_value(aoSocket);
}

string get_ip(string|int sname) 
{
    foreach(aoSocket, object sock) {
	
	if ( stringp(sname) && sock->get_socket_name() == sname )
	    return sock->get_ip();
	else if (sock->get_client_features() & sname )
	    return sock->get_ip();
    }
    return "0.0.0.0";
}
	
string describe() 
{
    return "~"+sUserName+"(#"+get_object_id()+","+get_status()+","+get_ip(1)+
	")";
}



