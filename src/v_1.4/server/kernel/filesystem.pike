inherit Filesystem.Base;
inherit "/modules/filepath";

#include <database.h>

// filesystem stuff
static object cwdCont = _ROOTROOM;

object cd(string|object cont)
{
    if ( stringp(cont) )
	cont = path_to_object(cont);
    if ( !objectp(cont) )
	return 0;
    cwdCont = cont;
    return this();
}

string cwd()
{
    return object_to_filename(cwdCont);
}

array(string) get_dir(void|string directory, void|string|array glob)
{
    object cont;
    if ( stringp(directory) )
	cont = path_to_object(directory);
    else
	cont = cwdCont;
    array files = ({ });
    foreach ( cont->get_inventory(), object obj )
	files += ({ obj->get_identifier() });
    return files;
}

Stdio.File open(string file)
{
    object cont;
    if ( file[0] != '/' )
	cont = cwdCont;
    else
	cont = _ROOTROOM;

    object doc = resolve_path(cont, file);
    if ( !objectp(doc) )
	error("Unable to resolve " + file + "\nCWD="+cwd()+"\n");
    Stdio.FakeFile f = Stdio.FakeFile(doc->get_content());
    return f;
}



