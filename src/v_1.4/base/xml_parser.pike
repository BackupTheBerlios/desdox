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

string node_to_str(object n);


//! this is a structure to make accessing Parser.XML.Node(s) easier.

class NodeXML {
    string            name;
    string            data;
    mapping     attributes;
    NodeXML         father;
    object         xmlNode;
    array(NodeXML) sibling;

    string get_data() {
	return data; // this might be incorrect, does not contain tags anyway
    }

    object get_parent() {
	return father;
    }

    static void set_node(object node) {
      data  = "";
      name  =  node->get_tag_name();
      attributes = node->get_attributes();
      sibling = ({ });
      array childs = node->get_children();
      for ( int i = 0; i < sizeof(childs); i++ ) {
	  int t = childs[i]->get_node_type();
	  if ( t == Parser.XML.Tree.XML_ELEMENT )
	      sibling += ({ NodeXML(childs[i], this_object()) });
	  else if ( t == Parser.XML.Tree.XML_TEXT )
	      data += childs[i]->get_text();
      }
      xmlNode = node;
    }
    

    void create(object node, void|object parent) {
      if ( objectp(parent) )
	father = parent;
      else if ( objectp(node->get_parent()) )
	father = NodeXML(node->get_parent());
      else
	father = 0;
      set_node(node);
    }
    array(NodeXML) get_nodes(string element) {
	array(NodeXML) res = ({ });
	foreach( sibling, object s ) {
	    if ( s->name == element ) {
		res += ({ s });
	    }
	}
	return res;
    }
    NodeXML get_node(string xpath) {
	array(string) path = xpath / "/";
	NodeXML node = this_object();

	if ( sizeof(path) == 0 )
	    path = ({ xpath });

	if ( path[0] == "" ) {
	    if ( name != path[1] )
		return 0;
	    path = path[2..];
	}
	
	foreach ( path, string p ) {
	    string element;
	    int        num;
	    if ( p == "" ) continue;
	    if ( sscanf(p, "%s[%d]", element, num) != 2 ) {
		element = p;
		num = 1;
	    }
	    foreach( node->sibling, object s ) {
		if ( s->name == element || element == "*" ) {
		    num--;
		    if ( num == 0 ) { 
			node = s;
			break;
		    }
		}
	    }
	    if ( num != 0 ) {
		return 0;
	    }
	}
	return node;
    }

    // replace the node with a text node
    int replace_node_text(string data) {
	object n = 
	    Parser.XML.Tree.Node(Parser.XML.Tree.XML_TEXT,"",([]),data);
	xmlNode->replace_node(n);
	set_node(n);
    }

    array(object) replace_node(string data) {
	if ( !objectp(father) )
	    error("No father node to replace complex structure!");
	// here we get possible xml data
	string xml = "<xml>"+data+"</xml>";

	object n;
	if ( catch(n = Parser.XML.Tree->parse_input(xml)) ) {
	    //! fixme: this is also a workaround - currently throw the error
	    n = Parser.XML.Tree.Node(Parser.XML.Tree.XML_TEXT,"",([]),data);
	    xmlNode->replace_node(n);
	    set_node(n);
	    return ({ n });
	}
	    
	n = n->get_last_child();
	// replace this node with the nodes we got as part of the parser
	object xmlFather = father->xmlNode;
	array childs = xmlFather->get_children();
	array new_childs = ({ });
	array replace_childs = n->get_children();
	
	foreach ( childs, object c ) {
	    if ( c == xmlNode )
		new_childs += replace_childs;
	    else
		new_childs += ({ c });
	}
	father->replace_children(new_childs);
	
	return replace_childs;
    }

    void replace_children(array xmlnodes) {
	xmlNode->replace_children(xmlnodes);
	set_node(xmlNode);
    }


    void remove_sibling(object n) {
	sibling -= ({ n });
    }
	   
    void remove_node() {
	xmlNode->remove_node();
	if ( objectp(father) )
	    father->remove_sibling(this_object());
    }
    // call render_xml() in the node - this includes the current node
    string get_xml() {
	return xmlNode->render_xml();
    }
    // call render_xml() in all child nodes
    string get_sub_xml() {
	string xml = "";
	foreach(xmlNode->get_children(), object child) {
	    xml += child->render_xml();
	}
	return xml;
    }
	
    string get_node_xml() {
	return node_to_str(this_object());
    }
    object get_last_child() {
	return sibling[-1];
    }

    array(object) get_leafs() {
	if ( sizeof(sibling) == 0 )
	    return ({ this_object() });

	array result = ({ });
	foreach ( sibling, object s )
	    result += s->get_leafs();
	return result;
    }
};



/**
 * Parse given data using the Parser.XML.Tree module.
 *  
 * @param string data - the xml data to parse.
 * @return NodeXML structure described by its root-node.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
NodeXML parse_data(string data)
{
    object node;
    mixed err = catch( node = Parser.XML.Tree->parse_input(data));
    
    if ( stringp(err) ) {
	werror("String error...\n"+err);
	int offset;
	if ( sscanf(err, "%*s[Offset: %d]", offset) ) {
	    err += "\nContext\n";
	    if ( offset > 200 )
		err += data[offset-200..offset-1];
	    else if ( offset > 80 )
		err += data[offset-80..offset-1];
	    else if ( offset > 20 )
		err += data[offset-20..offset-1];
	    else
		err += data[..offset-1];

	    err += "___" + data[offset.. offset+20];
	}
	err = ({ err, backtrace() });
    }
    if ( err ) {
	werror("Error parsing:\n"+sprintf("%O\n", err));
	throw(err);
    }

    if ( !objectp(node) ) return 0;

    object xmlroot = NodeXML(node);
    if ( sizeof(xmlroot->sibling) == 1 )
      return xmlroot->sibling[0];
    return xmlroot;
}

/**
 * Converts a node of an XML Tree to a string.
 *  
 * @param NodeXML ann - the node to convert.
 * @return string representation of the Node and it children recursively.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see
 */
string node_to_str(NodeXML ann)
{
    string res = "";
    string     attr;

    res = "<"+ann->name;
    foreach(indices(ann->attributes), attr) {
	if ( attr != ann->name )
	    res += " " + attr + "=\""+ann->attributes[attr]+"\"";
    }
    res += ">"+ann->data;
    foreach(ann->sibling, NodeXML child) {
	res += "<"+child->name;
	foreach(indices(child->attributes), attr) {
	    if ( attr != child->name )
		res += " " + attr + "=\""+child->attributes[attr]+"\"";
	}
	res += ">" + child->data + sibling_to_str(child->sibling)+
	    "</"+child->name+">\n";
    }
    res += "</"+ann->name+">\n";
    return res;
}

/**
 * Some conversion function I forgot where it is used at all.
 *
 * @param array annotations - an array of annotations to convert
 * @return a string representation of the annotations.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string sibling_to_str(array annotations)
{
    string res = "";
    if ( !arrayp(annotations) )
	return res;
    
    foreach(annotations, NodeXML ann) {
	res += node_to_str(ann);
    }
    return res;
}

/**
 * Convert some annotations to a string representation by using the
 * sibling_to_str function. Remember annotations can be annotated again!
 *  
 * @param array annotations - the annotations to convert.
 * @return string representation of the annotations.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see sibling_to_str
 */
string convert_annotations(array annotations)
{
    string res = "";
    foreach(annotations, NodeXML ann) {
	res += sibling_to_str(ann->sibling);
    }
    return res;
}

/**
 * Display the structure of a XML Tree given by NodeXML node.
 *  
 * @param NodeXML node - the node, for example the root-node of the tree.
 * @return just writes the structure to stderr.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>)
 */
void display_structure(NodeXML node, void|int depth)
{
    for ( int i = 0 ; i < depth; i++ )
	werror("\t");
    werror(node->name+":"+node->data+"\n");
    foreach(node->sibling, NodeXML n) {
	display_structure(n, depth+1);
    }
}

/**
 * Create a mapping from an XML Tree.
 *  
 * @param NodeXML n - the root-node to transform to a mapping.
 * @return converted mapping.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mapping xmlMap(NodeXML n)
{
  mapping res = ([ ]);
  foreach ( n->sibling, NodeXML sibling) {
    if ( sibling->name == "member" ) {
      mixed key,value;
      foreach(sibling->sibling, object o) {

	if ( o->name == "key" )
	  key = unserialize(o->sibling[0]);
	else if ( o->name == "value" )
	  value = unserialize(o->sibling[0]);
      }
      res[key] = value;
    }
  }
  return res;
}

/**
 * Create an array with the siblings of the given Node.
 *  
 * @param NodeXML n - the current node to unserialize.
 * @return Array with unserialized siblings.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
array xmlArray(NodeXML n)
{
    array res = ({ });
    foreach ( n->sibling, NodeXML sibling) {
	res += ({ unserialize(sibling) });
    }
    return res;
}

/**
 * Create some data structure from an XML Tree.
 *  
 * @param NodeXML n - the root-node of the XML Tree to unserialize.
 * @return some data structure describing the tree.
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mixed unserialize(NodeXML n) 
{
    switch ( n->name ) {
    case "struct":
	return xmlMap(n);
	break;
    case "array":
	return xmlArray(n);
	break;
    case "int":
	return (int)n->data;
	break;
    case "float":
	return (float)n->data;
	break;
    case "string":
	return n->data;
	break;
    }
    return -1;
}


mixed test()
{
    string xml = "<?xml version='1.0'?><a>1<b>2</b>3<c a='1'>4</c></a>";
    object node = parse_data(xml);
    object n = node->get_node("/a/b");
    if ( !objectp(n) || n->data != "2" )
	error("Failed to resolve xpath expression.");
    n->replace_node("<huh/>");
    if ( node->get_xml()!= "<a>1<huh/>3<c a='1'>4</c></a>" )
	error("replacing of <b/> didnt work !\nResult is:"+node->get_xml());
    
    // error testing
    xml = "<a><b/>";
    
    mixed err = catch(parse_data(xml));
    if ( err == 0 )
	error("Wrong xml code does not throw error.\n");
    if ( !stringp(err) )
	error("Non string error, expected just one string.\n");
    
    xml = "<a><b test=1/></a>";
    err = catch(parse_data(xml));
    if ( err == 0 )
	error("Wrong xml code does not throw error.\n");
    if ( !stringp(err) )
	error("Non string error, expected just one string.\n");
    
    if ( search(err, "<b test=___1") == -1 )
	error("Context lost in error: " + err);

    

    return n;
}

