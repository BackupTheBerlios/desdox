/* Copyright (C) 2002, 2003 Christian Schmidt
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

/*
 * implements a smtp-server (see rfc2821 for details)
 * is called automaticly on connection attempt to smtp-port
 */

inherit "/net/coal/login";
inherit "/net/base/line";

#include <macros.h>
#include <config.h>
#include <database.h>
#include <attributes.h>
#include <classes.h>
#include <exception.h>

#define SMTP_DEBUG

#ifdef SMTP_DEBUG
#define DEBUG_SMTP(s, args...) werror(s+"\n", args)
#else
#define DEBUG_SMTP
#endif

//states for the smtp-server, see rfc2821
#define STATE_INITIAL 1
#define STATE_IDENTIFIED 2
#define STATE_TRANSACTION 3
#define STATE_RECIPIENT 4
#define STATE_DATA 5

static int _state = STATE_INITIAL;
static int _esmtp = 0;
static string sServer = _Server->query_config("machine");
static string sDomain = _Server->query_config("domain");
static string sIP = _Server->query_config("ip");
static string sFQDN = sServer+"."+sDomain;
//static object oUser;
static object oRcpt;

static string sMessage="";
static array(object) aoRecipients=({});

//sends a reply to the client, prefixed by a response code
//if msg is more than one line, each is preceded by this code
static void send_reply(int code, string msg)
{
    array lines = msg / "\n";
    for(int i=0;i<sizeof(lines); i++)   //multiline reply
    {
        if(i==sizeof(lines)-1) send_message(""+code+" "+lines[i]+"\r\n");
        else send_message(""+code+"-"+lines[i]+"\r\n");
    }
}

//called upon connection, greets the client
void create(object f)
{
    ::create(f);

    string sTime=ctime(time());
    sTime=sTime-"\n";   //remove trailing LF
    oUser = MODULE_USERS->lookup("postman");
    send_reply(220,sFQDN+" sTeaMail SMTP-Server ver1.0 ready, "+sTime);
}

static void ehlo(string client)
{
    if(_state!=STATE_INITIAL)
    {
        //reset everything important
        sMessage="";
        aoRecipients=({});
    }
    _esmtp=1;   //client supports ESMTP
    _state=STATE_IDENTIFIED;    //client identified correctly

    string addr=query_address();
    sscanf(addr,"%s %*s",addr); //addr now contains ip of connecting host

    //verify if given name is correct    
    object dns = Protocols.DNS.client();
    array res = dns->gethostbyaddr(addr);
    if (res[0]==client)    
        send_reply(250,sServer+" Hello "+client+" ["+addr+"]");
    else send_reply(250,sServer+" Hello "+client+" ["+addr+"] (Expected \"EHLO "+res[0]+"\")");
}

static void helo(string client)
{
    if(_state!=STATE_INITIAL)
    {
        //reset everything important
        sMessage="";
        aoRecipients=({});
    }
    _esmtp=0;   //client does not support ESMTP
    _state=STATE_IDENTIFIED;    //client identified correctly

    string addr=query_address();
    sscanf(addr,"%s %*s",addr);
    
    //verify if given name is correct    
    object dns = Protocols.DNS.client();
    array res = dns->gethostbyaddr(addr);
    if (res[0]==client)    
        send_reply(250,sServer+" Hello "+client+" ["+addr+"]");
    else send_reply(250,sServer+" Hello "+client+" ["+addr+"] (Expected \"HELO "+res[0]+"\")");    
}

static void help()
{
    send_reply(250,"This is the opensTeam-Mailserver\n"+
     "Contact: http://www.open-steam.org");
}

static void mail(string sender)
{
    //sender must look like '<sender@domain>'
    if(sscanf(sender,"<%s@%s>",string sender, string domain)==2)
    {
        _state=STATE_TRANSACTION;   //waiting for RCPT command(s) now
        send_reply(250,"Sender accepted"); //NOTE: sender can't be verified
    }
    else send_reply(501,"syntax error, return path has illegal format");
}

static void rcpt(string recipient)
{

    if (sscanf(recipient,"<%s>",string address)==1)
    {
        if(lower_case(address)=="postmaster")
            address="postmaster@"+sFQDN; //rcpt to:<postmaster> is always local!

        sscanf(address,"%s@%s",string user, string domain);

        DEBUG_SMTP("Mail to domain=%s - LOCALDOMAIN=%s", domain, sFQDN);
        
        int success = 0;
        if(lower_case(domain)==lower_case(sFQDN))
            success = 1;
        else
        {   //test if given domain-name matches local ip-adress (->accept it)
            //workaround for multiple domains on same machine
            //like "uni-paderborn.de"<->"upb.de"
            object dns = Protocols.DNS.client();
            array result = dns->gethostbyname(lower_case(domain));
            string tmp_ip;
            if(sizeof(result[1])>0) tmp_ip=result[1][0];
            else tmp_ip="";
//            DEBUG_SMTP("IP for target-domain is: "+tmp_ip);            
            if(tmp_ip==sIP) success=1;
        }

        if(success==1) //only accept for local domain
        {
            user=lower_case(user);
            if(user=="postmaster") user="root";//change to other user,if needed

	    // send message to object ?
	    int oid;
	    if ( sscanf(user, "%d", oid) == 1 ) 
	    {
	      oRcpt = find_object(oid);
	      // make sure everyone can store annotations
	      mixed err = catch {
		_SECURITY->access_annotate(oRcpt, oRcpt, 0);
	      };
	      if ( err != 0 ) {
		send_reply(550, "Access denied - recipient does not accept messages.");
		return;
	      }

              if(oRcpt->get_object_class() & CLASS_GROUP) 
                aoRecipients += oRcpt->get_members();
              else 
                aoRecipients += ({ oRcpt });

	      send_reply(250,"Recipient ok");
	      _state=STATE_RECIPIENT; //waiting for DATA or RCPT
	      DEBUG_SMTP("got mail for object %O", oRcpt);
	      return; // done
	    }
	    
	    oRcpt = MODULE_USERS->lookup(user);
	    if(objectp(oRcpt)) //recipient is single user
	    {
	      aoRecipients+=({oRcpt});
	      send_reply(250,"Recipient ok");
	      _state=STATE_RECIPIENT; //waiting for DATA or RCPT
	    }
	    else
	      {
            oRcpt = MODULE_GROUPS->lookup(user);
            if(objectp(oRcpt)) //recipient is a group
            {
                aoRecipients+=oRcpt->get_members(); //add members to recipients
                send_reply(250,"Recipient ok");
                _state=STATE_RECIPIENT; //waiting for DATA or RCPT
            }
            else send_reply(550,"unknown recipient");
        }
        }
        else send_reply(550,"we do not relay for you!");
    }
    else send_reply(501,"syntax error, recipient adress has illegal format");
}

static void data()
{
    //"minimize" list of recipients
    aoRecipients=Array.uniq(aoRecipients);
    
    send_reply(354,"send message now, end with single line containing '.'");
    _state=STATE_DATA;

    //add "received"-Header, see rfc for details
    string addr=query_address();
    sscanf(addr,"%s %*s",addr);
    sMessage="Received: from "+addr+" by "+sFQDN+" "+ctime(time())-"\n";
}

static void process_data(string data)
{
    if(data!=".") {
        sMessage+="\n"+data; // append line to msg, continue
    }
    else //"." ends data-transfer
    {
        sMessage+="\r\n";
        send_reply(250,"Message accepted, size is "+sizeof(sMessage));

        // create sTeam object from message

        object msg = MIME.Message(sMessage);
	string mimetype=msg->type+"/"+msg->subtype;

	object factory = _Server->get_factory(CLASS_DOCUMENT);
	object mail = factory->execute
		  ( (["name": msg->headers["subject"],
		     "mimetype": mimetype]));
        
        array (object) parts = msg->body_parts;
        if ( arrayp(parts) ) 
        {
          foreach(parts, MIME.Message obj) 
          {
            string name = obj->headers["subject"];
            if(name==0) 
              name = obj->get_filename();
            if(name==0) 
              name = "Attachment to msg #"+mail->get_object_id();
            string mimetype2=obj->type+"/"+obj->subtype;
            object annotation = factory->execute
		  ( ([ "name": name, "mimetype" : mimetype2 ]));
            if(obj->getdata()!=0)
              annotation->set_content(obj->getdata());
            else 
              annotation->set_content("dummy value, no real content right now");
            annotation->set_attribute(MAIL_MIMEHEADERS,obj->headers);
            mail->add_annotation(annotation);
            DEBUG_SMTP("Attachment \"%s\" annotated to #%d, type is %s", name, mail->get_object_id(), mimetype2);
          }    
        }
	    
        if(msg->getdata()!=0)
          mail->set_content(msg->getdata());
        else
          mail->set_content("This document was received as a multipart e-mail,"
	      "\nthe content(s) can be found in the annotations/attachments!");

        mail->set_attribute(MAIL_MIMEHEADERS,msg->headers);


	DEBUG_SMTP("Recipients of E-Mail=%O",aoRecipients);
        //store message now
	      
        for(int i=sizeof(aoRecipients)-1; i>=0; i--)
	{
	  object thismail;
	  oRcpt=aoRecipients[i];

	  // duplicate the mail for everybody except the last recipient.
	  // (if everyone except the first is duplicated then the original
	  // might be altered or removed before the duplication is complete
	  if(i>0)
	    thismail=mail->duplicate();
	  else
	    thismail=mail;
	  
	  if ( oRcpt->get_object_class() & CLASS_USER ||
	       oRcpt->get_object_class() & CLASS_GROUP ) 
	  {
	    oRcpt->mail(thismail);
	    DEBUG_SMTP("E-Mail stored for user "+oRcpt->get_identifier()+", type is "+mimetype);
	  }
	  else 
	  {
	    // non-user: have to store as an annotation

	    oRcpt->add_annotation(thismail);
	    thismail->set_acquire(oRcpt);
	    DEBUG_SMTP("E-Mail stored as annotation on "+oRcpt->get_identifier());
	  }
	}
	_state=STATE_IDENTIFIED;
	sMessage="";
	aoRecipients=({});
    }
}

static void rset()
{
    if(_state>STATE_IDENTIFIED) _state=STATE_IDENTIFIED;
    sMessage="";
    aoRecipients=({});
    send_reply(250,"RSET completed");
}

static void noop()
{
    send_reply(250,"NOOP completed");
}

static void quit()
{
    send_reply(221,""+sServer+" closing connection");
    close_connection();
}

static void vrfy(string user)
{
    send_reply(252,"Cannot VRFY user, but will accept message and attempt delivery");
    //verification code may be added here
}

//this function is called for each line the client sends
static void process_command(string cmd)
{
    if(_state==STATE_DATA)
    {
        process_data(cmd);
        return;
    }

    string command,params;
    if(sscanf(cmd,"%s %s",command,params)!=2)
    {
        command=cmd;
        params="";
    }

    switch(upper_case(command))
    {
        case "EHLO":
            if(search(params," ")==-1) ehlo(params);
            else send_reply(501,"wrong number of arguments");
            break;
        case "HELO":
            if(search(params," ")==-1) helo(params);
            else send_reply(501,"wrong number of arguments");
            break;
        case "HELP":
            help();
            break;
        case "MAIL":
            if(_state==STATE_IDENTIFIED)
            {
                array(string) parts=params/":";
                if(upper_case(parts[0])=="FROM" && sizeof(parts)==2)
                    mail( String.trim_whites(parts[1]) );
                else send_reply(501,"syntax error");
            }
            else send_reply(503,"bad sequence of commands - EHLO expected");
            break;
        case "RCPT":
            if(_state==STATE_TRANSACTION||_state==STATE_RECIPIENT)
            {
                array(string) parts=params/":";
                if(upper_case(parts[0])=="TO" && sizeof(parts)==2)
                    rcpt( String.trim_whites(parts[1]) );
                else send_reply(501,"syntax error");
            }
            else send_reply(503,"bad sequence of commands");
            break;
        case "DATA":
            if(_state==STATE_RECIPIENT)
            {
                if (params=="") data();
                else send_reply(501,"wrong number of arguments");
            }
            else send_reply(501,"bad sequence of commands");
            break;
        case "RSET":
            if (params=="") rset();
            else send_reply(501,"wrong number of arguments");
            break;
        case "NOOP":
            noop();
            break;
        case "QUIT":
            if (params=="") quit();
            else send_reply(501,"wrong number of arguments");
            break;
        case "VRFY":
            vrfy(params);
            break;
        default:
            send_reply(500,"command not recognized");
            break;
    }
}
