inherit "/kernel/module";

#include <macros.h>
#include <config.h>

//! This module is a ldap client inside sTeam. It reads configuration
//! parameters of sTeam to contact a ldap server.
//! All the user management can be done with ldap this way. Some
//! special scenario might require to modify the modules code to 
//! make it work.
//!
//! The configuration variables used are:
//! ldap:server - the server name to connect to
//! ldap:user   - ldap user for logging in
//! ldap:password - the password for the user
//! ldap:base_dc - ldap base dc, consult ldap documentation
//! ldap:objectName - the ldap object nameto be used for the search
//! ldap:userAttr - the attribute containing the user login name
//! ldap:passwordAttr - the attribute containing the password

static object oLDAP;
static string sServerURL;

static void init_module()
{
    mixed err = catch {
    oLDAP = Protocols.LDAP.client(_Server->query_config("ldap:server"));
    oLDAP->bind("cn="+_Server->query_config("ldap:user")+","+
		_Server->query_config("ldap:base_dc"), 
		_Server->query_config("ldap:password"));
    oLDAP->set_scope(2);
    oLDAP->set_basedn(_Server->query_config("ldap:base_dc"));
    };

}

bool authorize_ldap(string user, string pass) 
{
    object results = oLDAP->search(
	"(objectclass="+_Server->query_config("ldap:objectName")+")");
    for ( int i = 1; i <= results->num_entries(); i++ ) {
	mapping res = results->fetch(i);

	if ( res[_Server->query_config("ldap:userAttr")][0] == user ) 
	{
	    if ( Crypto.crypt_md5(
		pass, res[_Server->query_config("ldap:passwordAttr")][0]) == 
		 res[_Server->query_config("ldap:passwordAttr")][0] ) 
		return true;
	}
    }
    return false;
}

bool is_user(string user)
{
    object results = oLDAP->search("("+_Server->query_config("ldap:userAttr")+
				   "="+user+")");
    return (results->num_entries() > 0);
}

bool add_user(string name, string password, string fullname)
{
    mapping attributes = ([
	_Server->query_config("ldap:userAttr"): ({ name }),
	_Server->query_config("ldap:fullnameAttr"): ({ fullname }),
	"objectClass": ({ _Server->query_config("ldap:objectName") }),
	_Server->query_config("ldap:passwordAttr"): 
	({ Crypto.crypt_md5(password) }),
	]);
    array(string) requiredAttributes = 
	_Server->query_config("ldap:requiredAttr") / ",";
    if ( arrayp(requiredAttributes) && sizeof(requiredAttributes) > 0 ) 
    {
	foreach(requiredAttributes, string attr) {
	    if ( zero_type(attributes[attr]) )
		attributes[attr] = "-";
	}
    }

    oLDAP->add(_Server->query_config("ldap:userAttr")+"="+name+
	       ","+_Server->query_config("ldap:base_dc"), attributes);
    return oLDAP->error_number() == 0;
}

string get_identifier() { return "ldap"; }

