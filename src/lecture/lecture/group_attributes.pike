//! dieses script befindet sich an einem Objekt und regelt das einstellen von
//! speziellen attributen - in diesem fall: gruppen tutoren, zeiten, raeume

inherit "/classes/Script";

#include <macros.h>
#include <database.h>

mixed execute(mapping vars)
{
  string html;
  object obj = find_object((int)vars->object);
  html = "<form action='"+_FILEPATH->object_to_filename(this_object())+"'>\n";
  html += "<table>";
  html += "<tr><td>Tutor</td><td>"+make_selection("tutor", obj)+"</td></tr>";
  html += "<tr><td>Raum</td><td><input type='text' name='raum'/></td></tr>";
  html += "</table></form>";
  return html;
}
