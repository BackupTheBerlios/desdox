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

inherit "/classes/Document";

#include <macros.h>
#include <classes.h>
#include <assert.h>
#include <database.h>
#include <exception.h>
#include <attributes.h>

private static string  sContentCache = 0;

/**
 * this is the content callback function
 * in this case we have to read the whole content at once hmmm
 *  
 * @param int pos - the current position of sending.
 * @return chunk of content.
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
private static string
send_content_wiki(int pos)
{
    string result;

    LOG("Sending content:" + pos);
    if ( !stringp(sContentCache) )
	return 0; // finished
    
    if ( strlen(sContentCache) < DB_CHUNK_SIZE ) {
	result = copy_value(sContentCache);
	sContentCache = 0;
    }
    else {
	result = sContentCache[..DB_CHUNK_SIZE];
	sContentCache = sContentCache[DB_CHUNK_SIZE..];
    }
    return result;
}

/**
 * Get the whole content and for ftp connections re-exchange
 * all the links to retrieve the original content.
 *  
 * @return the content
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string get_content()
{
    object caller = CALLER;
    string content = ::get_content();
    
    if ( functionp(caller->get_client_class) &&
	 caller->get_client_class() != "ftp" ) 
    {
      // do wiki stuff
    }
    return content;
}

/**
 * Get the size of the content which is the size of the document
 * with exchanged links.
 *  
 * @return the content size.
 * @author Thomas Bopp (astra@upb.de) 
 */
int get_content_size()
{
    return (stringp(sContentCache) ? 
            strlen(sContentCache) : ::get_content_size());
}

/**
 * Get the callback function for content.
 *  
 * @param mapping vars - the variables from the web server.
 * @return content function.
 * @author Thomas Bopp (astra@upb.de) 
 */
function get_content_callback(mapping vars)
{
    object caller = CALLER;
    function cb;

    LOG("get_content_callback() by " + caller->get_client_class());
    cb = ::get_content_callback(vars);
    
    if ( search(caller->get_client_class(), "http") == -1 )
	return cb;
    
    sContentCache = "";
    string buf;
    int    pos = 0;
    while ( stringp(buf = cb(pos)) ) {
	sContentCache += buf;
	pos += strlen(buf);
    }
    sContentCache = parse_wiki(sContentCache);
    LOG("Result of parsing: " + sContentCache);    
    return send_content_wiki;
}

// wiki code starts here:

string parse_wiki_lines(string input)
{
  input -= "\r";
  replace(input, ([ "\\\n":"" ])); // join lines ending with \
  array content=input/"\n";
  string output="";

  mapping listtypes=([ "*":"ul", ":":"dl", "1":"ol type=\"1\"",
                       "a":"ol type=\"a\"", "A":"ol type=\"A\"",
                       "i":"ol type=\"i\"", "I":"ol type=\"I\"" ]);

  int i;
  array listlevels=({});
  for(i=0; i<sizeof(content); i++)
  {
    array line;
    if(content[i][0..2]!="   " && sizeof(listlevels))
    {
      int j;
      for(j=sizeof(listlevels); j>0; j--)
      {
        if(listlevels[j-1][0]!=":")
          output+="</li>";
        else
          output+="</dd>";
        output+="</"+listtypes[listlevels[j-1][0]]+">\r\n";
        listlevels=listlevels[..sizeof(listlevels)-2];
      }
    }
    if(content[i]=="")
      output+="<p />";
    else if(content[i][0]=='#')
    {
      line=array_sscanf(content[i], "#%[^ ]%[ ]%s");
      output+=sprintf("<a name=\"%s\">%s</a>\r\n", line[0], line[2]||"");
    }
    else
    {
      int j=3;

      switch(content[i][0..2])
      {
        case "---":
          line=array_sscanf(content[i], "---%*[-]%[+]%*1[ ]%s");
          if(sizeof(line[0]))
          {
            output+=sprintf("<h%d>%s</h%d>", sizeof(line[0]), line[1], sizeof(line[0]));
          }
          else
            output+=sprintf("<hr size=\"%d\" />%s", sizeof(line[0]), line[1]);
          break;
        case "   ":
          // FIXME: this should work with less then 3 spaces as well.
          array line=array_sscanf(content[i], "%[ ]%1[1aAiI]. %s");
          if(line[1]=="")
          {
            line=array_sscanf(content[i], "%[ ]%1[*] %s");
          }
          if(line[1]=="")
          {
            line=array_sscanf(content[i], "%[ ]%[^ :]:%s");
          }
          if(sizeof(line)==2)
          {
            line=array_sscanf(content[i], "%[ ]%s");
            output+=line[1];
          }
          else
          {
            //output+=sprintf("%s\r\n%O\r\n", content[i], line);
            string listtype="", beginterm, endterm;
            switch(line[1])
            {
              case "1": 
              case "a": 
              case "A": 
              case "i": 
              case "I": 
              case "*": 
                listtype=line[1];
                beginterm="<li>";
                endterm="</li>";
                break;
              default:
                listtype=":";
                beginterm="<dt>"+line[1]+"</dt><dd>";
                endterm="</dd>";
            }
            int k;
            while(sizeof(listlevels) && listlevels[-1][1]>sizeof(line[0]))
            {
              output+=endterm+"\r\n</"+listtypes[listlevels[-1][0]]+">";
              listlevels=listlevels[..sizeof(listlevels)-2];
            }

            if(!sizeof(listlevels) || listlevels[-1][1] < sizeof(line[0]))
            {
              listlevels+=({ ({ listtype, sizeof(line[0]) }) });
              output+="<"+listtypes[listtype]+">"+beginterm;
            }
            else if(sizeof(listlevels) && listlevels[-1][0]==listtype)
              output+=endterm+"\r\n"+beginterm;
            else if(sizeof(listlevels) && listlevels[-1][0]!=listtype)
            {
              if(listlevels[-1][0]!=":")
                output+="</li>";
              else
                output+="</dd>";
              output+="\r\n</"+listtypes[listlevels[-1][0]]+">";
              output+="\r\n<"+listtypes[listtype]+">";
              output+="\r\n"+beginterm;
              listlevels[-1][0]=listtype;
            }
            //output+=sprintf("%d, %d, %d: ", nestlevel, sizeof(listlevels), sizeof(line));
            output+=line[2];
          }
          break;
        default:
          output+=content[i];
      }
    }
    output+="\r\n";
  }

  return output;
}

string itag_wikilink(string name,
                     mapping arguments)
{
  return(sprintf("<a href=\"%s\">%s</a>", arguments->href, (arguments->title?arguments->title:arguments->href)));
}

string icontainer_verbatim(string name,
                     mapping arguments,
                     string contents,
                     mapping tmpstrings)
{
  if(name=="verbatim")
    contents=_Roxen.html_encode_string(contents);
  string tmphash=(string)hash(contents);
  tmpstrings[tmphash]="<pre>\r\n"+contents+"\r\n</pre>";
  return(tmphash);
}

string parse_fixed_bold_italic(string input)
{
  mapping begin = ([ "bi":"<b><i>", "bf":"<b><tt>", "b":"<b>", "i":"<i>", "f":"<tt>" ]);
  mapping end = ([ "bi":"</i></b>", "bf":"</tt></b>", "b":"</b>", "i":"</i>", "f":"</tt>" ]);
  input = replace(input, ([ "__":":wiki:bi:wiki:", "==":":wiki:bf:wiki:", 
           "_":":wiki:i:wiki:", "=":":wiki:f:wiki:", "*":":wiki:b:wiki:" ]));
  array output=input/":wiki:";
  int i;
  for(i=1; i+2<sizeof(output); i+=4)
  {
    output[i]=begin[output[i]];
    output[i+2]=end[output[i+2]];
  }
  return(output*"");
}

string parse_wiki(string content)
{
//  indices(spider);

  mapping tmpstrings = ([]);

  content = spider.parse_html(content, ([]), ([ "verbatim":icontainer_verbatim, "pre":icontainer_verbatim ]), tmpstrings);
  content = parse_wiki_lines(content);
  content = parse_fixed_bold_italic(content);
  // FIXME: * must be handled after parse_wiki_lines, to avoid catching
  //        unordered lists, but = needs to be handled before,
  //        to avoid messing with the html output of parse_wiki_lines
  content = replace(content, ([ "[[":"<wikilink href=\"", "][":"\" title=\"", "]]":"\" />" ]));
  content = spider.parse_html(content, ([ "wikilink":itag_wikilink ]), ([]));
  content = replace(content, tmpstrings);

  return content;
}
