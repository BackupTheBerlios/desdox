inherit "/classes/Script";
inherit "/base/xml_parser";

#include <database.h>
#include <macros.h>
#include <attributes.h>
#include <classes.h>
#include <access.h>

object create_cont(string name, object group, object tutors)
{
    object factory = get_factory(CLASS_CONTAINER);
    object cont = factory->execute( ([ "name": name, ]) );
    cont->move(group->query_attribute(GROUP_WORKROOM));
    cont->sanction_object(group, SANCTION_READ);
    cont->sanction_object(tutors, SANCTION_ALL);
    cont->set_acquire(0);
    cont->set_attribute("lecture", name);
    return cont;
}

object check_cont(object room, string name, object group, object tutors)
{
    array inv = room->get_inventory();
    foreach ( inv, object obj ) {
	if ( obj->query_attribute("lecture") == name )
	    return obj;
    }
    return create_cont(name, group, tutors);
}

mixed execute(mapping vars)
{
    // lecture stylesheet lesen und besonders darstellen...

  object xmlfile = OBJ("lecture/lecture.xsl.xml");

  NodeXML root = parse_data(xmlfile->get_content());
  object node= root->get_node("language");

  string url;


  
  foreach(node->get_nodes("term"), object t) {
      if ( t->attributes->name == "veranstaltung_url" )
	  url = t->data;
  }

  object fp     = get_module("filepath:url");
  object room   = fp->path_to_object(url);
  object group  = room->get_creator();

  if ( !objectp(group) )
      return result_page("Die zugehoerige Gruppe wurde nicht gefunden !", "");
  if ( !(group->get_object_class() & CLASS_GROUP) )
      return result_page("Die zugehoerige Gruppe wurde nicht gefunden !!", "");
  object tutors = group->get_members(CLASS_GROUP)[0];
  if ( !objectp(tutors) )
      return result_page("Die Tutoren Gruppe wurde nicht gefunden !", "");
  
  if ( vars["_action"] == "edit" ) {
    foreach(node->get_nodes("term"), object t) {
      mapping attr = t->attributes;
      werror("Checking:"+attr->name+"\n");
      if ( search(attr->name, "text_") >=  0 ) {
	if ( vars[attr->name] ) {
	  t->replace_node("<term name=\""+attr->name+"\">"+vars[attr->name]+
			  "</term>");
	}
      }
      if ( search(attr->name, "opt_") >= 0 ) {
	  string bname;
	  int num;

	  sscanf(attr->name, "%*s_%*s_%s", bname);
	  werror("bname="+bname+"\n");
	  if ( sscanf(bname, "generic%d", num) )
	  {
	      string key = "opt_text_generic"+num;
	      werror("Key="+key+" : "+vars[key]+"\n");
	      if ( stringp(vars[key]) && strlen(vars[key]) > 0 ) {
		  string button =
		      "<table cellpadding='0' cellspacing='0' border='0'>"+
		      "<tr><td align='center' height='35' width='119' "+
		      "background='"+url+"/images/UniLeer.gif'>"+
		      "<a class='button' href='"+
		      vars[key]+"'>"+vars[key]+"</a></td></tr></table>\n";
		  if ( attr->name == "opt_text_generic"+num )
		      button = vars[key];
		  t->replace_node("<term name='"+attr->name+"'><![CDATA["+
				  button+"]]></term>");
		  object cont = check_cont(
		      room, "generic"+num, group, tutors);
		  cont->set_attribute(OBJ_NAME, vars[key]);
	      }
	      else
		  t->replace_node("<term name='"+attr->name+"'/>");
	  }
	  else if ( stringp(vars[attr->name]) ) {
	      t->replace_node(
		  "<term name='"+attr->name+"'><![CDATA[<img src='"+
		  url + "/images/"+
		  bname+".gif' border='0'/>]]></term>");
	      if ( bname != "Anmeldung" )
		  check_cont(room, bname, group, tutors);
	  }
	  else
	      t->replace_node("<term name='"+attr->name+"'/>");
      }
    }
    xmlfile->set_content(root->get_xml());
  }
  root = parse_data(xmlfile->get_content());
  node= root->get_node("language");
  string xml = "<?xml version='1.0' encoding='iso-8859-1'?><Object/>";
  object xsl = OBJ("lecture/lecture.xsl");
  xsl->load_xml_structure();
  if ( !objectp(xsl) )
      return error_page("Lecture stylesheet no found !", "JavaScript:history.back();");
  
  mapping elements = ([ ]);
  
  foreach(node->get_nodes("term"), object tag) {
      mapping attr = tag->attributes;
      if ( search(attr->name, "opt_") >= 0 ) {
	  if ( search(attr->name, "nav_") >= 0 ) {
	      string picture;
	      
	      if ( search(attr->name, "generic") == -1 ) 
	      {
		  sscanf(attr->name, "opt_nav_%s", picture);
		  int checked = strlen(tag->data) > 0;
		  elements[attr->name] = 
		      "</a><input type=\"checkbox\" name=\""+attr->name+"\""+
		      (checked?" checked=\"true\"":"")+"/><img src='"+url+"/images/"+
		      picture+".gif' border='0'/><a>";
	      }
	  }
	  else {
	      int        num;

	      if ( sscanf(attr->name, "opt_text_generic%d", num) ) {
		  elements["opt_nav_generic"+num] = 
		      "<input type=\"text\" name=\"opt_text_generic"+
		      num+"\" value=\""+tag->data+"\"/>";
	      }

	  }
	}
	else if ( search(attr->name, "text_") >= 0 ) {
	    elements[attr->name] = 
		attr->name[5..]+
		"<input type=\"text\" name=\""+attr->name+"\" value=\""+
		tag->data+"\"/>";
	}
	else 
	    elements[attr->name] = tag->data;
	    
    }

  object startfile = get_module("filepath:url")->path_to_object(url + "/start.html");

  if ( objectp(startfile) ) {
      if ( stringp(vars->start) )
	  startfile->set_content(vars->start); 
      elements["start_edit"] =
	  "<textarea name=\"start\" cols=\"80\" rows=\"10\" wrap=\"virtual\" >"+
	  startfile->get_content()+"</textarea><br/><br/>"+
	  "<a href=\""+url+"\">Startseite ansehen</a>";
      
  }
  else
      elements["start_edit"] =
	  "Dieser Bereich wird durch ein Dokument mit Namen start.html beschrieben<br/>"+
	  "Falls so ein Dokument nicht vorhanden ist, wird der Inhalt des <br/>"+
	  "entsprechenden Ordners dargestellt (als Liste von Dokumten). <br/>"+
	  "In diesem Fall wurde kein start.html Dokument gefunden unter " + url + "/start.html";
  
    vars["edit"] = "true";
    vars["language"] = "german";


    string data = html_template(xsl->get_content(), elements);
    werror("Got xml = "+data+"\n");
    m_delete(vars, "start");
    string html = get_module("libxslt")->run(xml, data, vars);
    html +="<!--- xmlfile is "+_FILEPATH->object_to_filename(xmlfile)+"--->\n";
    return html;
}
