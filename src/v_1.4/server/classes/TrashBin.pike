inherit "/classes/Container";

#include <classes.h>
#include <macros.h>
#include <exception.h>
#include <attributes.h>

static void 
delete_object()
{
    THROW("Cannot delete the trashbin!", E_ACCESS);
    ::delete_object();
}

void empty()
{
  mixed err;

  foreach(get_inventory(), object obj) {
    err = catch {
      obj->delete();
    };
  }
}

static bool check_insert(object obj)
{
    // everything goes in here !
    return true;
}

bool move(object dest)
{
    if ( objectp(oEnvironment) ) {
	// if the trashbin is inside the users inventory
	// move it to the workroom instead (old version in inventory)
	if ( oEnvironment->get_object_class() & CLASS_USER ) 
	    return ::move(oEnvironment->query_attribute(USER_WORKROOM));

	THROW("Cannot move trashbin out of users workroom !", E_ACCESS);
    }

    return ::move(dest);
}

int get_object_class() { return ::get_object_class() | CLASS_TRASHBIN; }
string get_identifier() { return "trashbin"; }    
