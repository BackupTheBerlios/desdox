/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens, Martin Baehr
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

inherit "/classes/Object";

#include <macros.h>
#include <classes.h>
#include <assert.h>
#include <database.h>
#include <exception.h>
#include <attributes.h>
#include <types.h>


#define INPUT_TYPE_CUSTOM      "custom"
#define INPUT_TYPE_STRING      "string"
#define INPUT_TYPE_PASSWORD    "password"
#define INPUT_TYPE_TEXTAREA    "textarea"
#define INPUT_TYPE_SELECT      "select"
#define INPUT_TYPE_MULTISELECT "multiselect"

mapping attributes = ([]);
                             
int get_object_class()
{
    return ::get_object_class() | CLASS_BUG;
}


string describe_attribute_input(string name, string|void form_name, int|void verbose)
{
  if(!form_name)
    form_name=name;

  switch(attributes[name]->input_type)
  {
    case INPUT_TYPE_CUSTOM:
      return attributes[name]->input_function(attributes[name], form_name, verbose);
    case INPUT_TYPE_STRING:
      return sprintf("<input name=\"%s\" size=\"30\">", form_name);
    case INPUT_TYPE_PASSWORD:
      return sprintf("<input name=\"%s\" type=\"password\" size=\"30\">", form_name);
    case INPUT_TYPE_TEXTAREA:
      return sprintf("<textarea name=\"%s\" cols=\"60\" rows=\"10\" "
                     "wrap=\"off\">%s</textarea>", 
                     form_name, _Roxen.html_encode_string(attributes[name]->value||""));
    case INPUT_TYPE_SELECT:
    case INPUT_TYPE_MULTISELECT:
      string tmp;
      int i;

      tmp=sprintf("<select name=\"%s\"%s>\n", form_name,
              (attributes[name]->input_type==INPUT_TYPE_MULTISELECT?" multi=\"true\"":""));

      for(i=0; i<sizeof(attributes[name]->input_values); i++)
      { 
        if(attributes[name]->input_values[i]==attributes[name]->value || 
           (arrayp(attributes[name]->value) && ((multiset)attributes[name]->value)[attributes[name]->input_values[i]]))
          tmp+="<option selected=\"true\">" + attributes[name]->input_values[i];
        else
          tmp+="<option>" + attributes[name]->input_values[i];
        tmp+="\n";
      }
      tmp += "<option>foo\n";
      return tmp+"</select>\n";
    default:
  }
}

string describe_attribute_as_text(string name, int|void verbose)
{
  switch(attributes[name]->type)
  {
    case CMD_TYPE_STRING:
      return attributes[name]->value;
    case CMD_TYPE_INT:
      return (string)attributes[name]->value;
    case CMD_TYPE_FLOAT:
      return sprintf("%.4f", attributes[name]->value);
    case CMD_TYPE_ARRAY:
      return attributes[name]->value*", ";
    case CMD_TYPE_MAPPING:
    case CMD_TYPE_TIME:
    case CMD_TYPE_OBJECT:
    case CMD_TYPE_MAP_ENTRY:
    case CMD_TYPE_PROGRAM:
    case CMD_TYPE_FUNCTION:
    case CMD_TYPE_UNKNOWN:
    default: 
      return "Unknown";
  }
}

bool check_set_attribute(mixed key, mixed data)
{
  if(attributes[key] && attributes[key]->input_values && 
     !((multiset)attributes[key]->input_values)[data])
  {
    // invalid value
    THROW("Trying to set an invalid value !", E_ERROR);
  }
  else
  {
    return ::check_set_attribute(key, data);
  }

}

string execute(mapping variables)
{
    string output="";

    if(variables->submit)
    {
      output += "updating ...";
      foreach(indices(attributes), string name)
      {
        if(variables[name])
          set_attribute(name, variables[name]);
      }
    }

    attributes->status = ([ "name":"status", 
			  "value":do_query_attribute("status"),
			  "default":"new",
			  "type":CMD_TYPE_STRING,
			  "input_values":
			  ({ "new", "open", "verified", "closed" }),
			  "input_type":INPUT_TYPE_SELECT,
			  "input_function":0, 
			  "description":"Bug Status", 
			  "help":"Change the Status"
	]);

    if(variables->edit)
    {
	output += "<form>";
	foreach(indices(attributes), string name) {
        output += attributes[name]->description+": ";
        output += describe_attribute_input(name);
        output += "<br>\n";
      }
      output += "<input type=\"submit\" name=\"submit\" value=\"Update\"></form>\n";
    }
    else
    {
      foreach(indices(attributes), string name)
      {
        output += attributes[name]->description+": ";
        output += describe_attribute_as_text(name);
        output += "<br>\n";
      }
      output += sprintf("<hr><a href=\"%s?edit=yes\">edit</a><hr>\n", get_identifier());
    }

    return output+sprintf("<hr><pre>%O<hr>%O<hr>%O<hr>%O</pre>\n", get_attributes(), attributes, variables, query_attributes());
}

