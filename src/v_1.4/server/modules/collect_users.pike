inherit "/kernel/module";

#include <macros.h>
#include <events.h>
#include <attributes.h>
#include <coal.h>


static Thread.Queue userQueue = Thread.Queue();

void load_module()
{
    start_thread(collect);
}

void user_login(object obj, object user, int feature, int prev_features)
{
    userQueue->write(user);
}

/**
 * Check if a user needs cleanup and should be moved into her
 * workroom.
 *  
 * @param object user - the user to check.
 */
void check_user_cleanup(object user)
{
    userQueue->write(user);
}

void check_users_cleanup(array users)
{
    foreach(users, object u)
	if ( objectp(u) )
	    userQueue->write(u);
}

static int check_user(object user)
{
    if ( user->get_status() == 0 ) {
	if ( user->get_environment() != user->query_attribute(USER_WORKROOM) ){
	    MESSAGE("Collect: Moving user %s", user->get_identifier());
	    user->move(user->query_attribute(USER_WORKROOM));
	}
	return 0;
    }
    return 1;
}

//! check active users and possible move them home
static void collect()
{
    while ( 1 ) {
	mixed err = catch {
	    object user;
	    array(object) check_users;
	    check_users = ({ });
	    while ( userQueue->size() > 0 ) {
		user = userQueue->read();
		if ( search(check_users, user) == -1 && check_user(user) )
		    check_users += ({ user });
	    }
	    foreach ( check_users, user)
	        userQueue->write(user);
	    // also check idle connections!
	    foreach ( master()->get_users(), object socket ) {
		if ( !objectp(socket) ) continue;
		if ( functionp(socket->get_last_response) ) 
		{
		    int t = time() - socket->get_last_response();
		    if ( t > COAL_TIMEOUT ) {
			MESSAGE("COAL: timeout on socket: "+socket->get_ip());
			socket->close_connection();
		    }
		}
	    }
	};
	if ( err != 0 )
	    FATAL("Error on collect_users():\n %O", err);
	sleep(200);
    }
}

string get_identifier() { return "collect_users"; }
