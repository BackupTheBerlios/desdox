inherit "/kernel/package" : __package;
inherit "/kernel/db_mapping";

#include <classes.h>
#include <types.h>
#include <events.h>
#include <attributes.h>
#include <macros.h>
#include <database.h>


mixed query_attribute(string|int key)
{
werror("%s", this_user()->describe());
//   Matrikel Nummer absichern:
//   if ( this_user() != CALLER ) {
//   todo: add protection
//        steam_error ("No access to read MatrikelNr attribute"); 
//        return "No Access";
//    }
    if ( key == "MatrikelNr" ) {
	int id = CALLER->get_object_id();
	return get_value(id);
    }
    return __package::do_query_attribute(key);
}

void load_module()
{
    load_db_mapping();
}


object get_mnr(string mnr)
{
    mixed u = get_value(mnr);
    object user = find_object((int)u);
    return user;
}

mixed set_attribute(string|int key, mixed val)
{
    if ( key == "MatrikelNr" ) {
        int id = CALLER->get_object_id();
	mixed other = get_value(val);
	werror("other="+sprintf("%O\n",other));
	if ( other && val != "0000000" && other != id )
	    error("Es gibt bereits einen Benutzer mit der Matrikel Nummer: "+val+
		" ("+id+")");
	
	set_value(val,(string)id);
	return set_value(id, val);
    }
    return __package::do_set_attribute(key, val);
}

bool check_set_attribute(mixed key, mixed val)
{
  return true;
}

void create_setup()
{
    object setup = OBJ("/lecture/setup");
    if ( !objectp(setup) ) {
	setup = OBJ("/lecture/setup.pike")->execute( (["name":"setup", ]) );
	setup->move(OBJ("/lecture"));
    }
}

array spm_install_package()
{
  create_setup();
  provide_attribute(CLASS_USER, "MatrikelNr", 
		    CMD_TYPE_STRING, 
		    "Matrikel Nr.",
		    0, EVENT_ATTRIBUTES_CHANGE, this(),
		    CONTROL_ATTR_USER, "0000000", this());
  return ({ });
}

array spm_upgrade_package()
{
  create_setup();
  provide_attribute(CLASS_USER, "MatrikelNr", 
		    CMD_TYPE_STRING, 
		    "Matrikel Nr.",
		    0, EVENT_ATTRIBUTES_CHANGE, this(),
		    CONTROL_ATTR_USER, "0000000", this());
  return ({ });
}

bool check_package_integrity()
{
  return true;
}

string get_version() { return "1.0"; }
string get_identifier() { return "package:lecture"; }
string get_table_name() { return "mnr"; }

