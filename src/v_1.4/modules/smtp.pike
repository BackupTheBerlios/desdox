inherit "/kernel/module";

#include <macros.h>
#include <config.h>
#include <database.h>
#include <attributes.h>

#define SMTP_DEBUG

#ifdef SMTP_DEBUG
#define SMTP_LOG(s) werror(s+"\n")
#else
#define SMTP_LOG(s)
#endif
//! This is the SMTP module for sTeam. It sends mail to some e-mail adress
//! by using a local mailserver or doing MX lookup and sending directly
//! to the targets mail server.

static Thread.Queue MsgQueue = Thread.Queue();
static object oSMTP; // cache smtp object (connection)
static array(object) aMessages;

class Message {
    string email;
    string subject;
    string body;
    string from;
    string fromobj;
    string fromname;
    string mimetype;
    string date;
    string message_id;
    string in_reply_to;
    string reply_to;
    string mail_followup_to;
    
    void create(void|mapping m) {
	if ( mappingp(m) ) {
	    email = m->email;
	    subject = m->subject;
	    body = m->body;
	    from = m->from;
	    fromobj = m->fromobj;
	    fromname = m->fromname;
	    mimetype = m->mimetype;
	    date = m->date;
	    message_id = m->message_id;
	    in_reply_to = m->in_reply_to;
	    reply_to = m->reply_to;
	    mail_followup_to = m->mail_followup_to;
	}
    }
    
    mapping get_data() {
	return ([
	    "email": email,
	    "subject": subject,
	    "body": body,
	    "from": from,
	    "fromobj": fromobj,
	    "fromname": fromname,
	    "mimetype": mimetype,
	    "date": date,
	    "message_id": message_id,
	    "in_reply_to": in_reply_to,
	    "reply_to": reply_to,
	    "mail_followup_to": mail_followup_to,
	    ]);
    }
};

void init_module()
{
    add_data_storage(retrieve_mails, restore_mails);
    aMessages = ({ });
}

void restore_mails(mapping data)
{
    if ( CALLER != _Database )
	steam_error("CALLER is not the database !");
    foreach ( indices(data->mails), mapping mail ) {
	object msg = Message(mail);
	aMessages += ({ msg });
	MsgQueue->write(msg);
    }
}

mapping retrieve_mails()
{
    if ( CALLER != _Database )
	steam_error("CALLER is not the database !");
    mapping data = ([ "mails": ({ }), ]);
    foreach ( aMessages, object msg ) 
	data->mails += ({ msg->get_data() });
    return data;
}
	

void runtime_install()
{
    SMTP_LOG("Init module SMTP !");

    // an initial connection needs to be created to load some libraries
    // otherwise creating connections will fail after the sandbox
    // is in place (chroot("server/"))
    string server = _Server->query_config(CFG_MAILSERVER);
    mixed err = catch(oSMTP = Protocols.SMTP.client(
	server,	(int)_Server->query_config(CFG_MAILPORT)));
    if ( err ) 
	FATAL("Failed to connect to " + server+" :\n"+sprintf("%O\n", err));
    start_thread(smtp_thread);
}

void 
send_mail(string email, string subject, string body, void|string from, void|string fromobj, void|string mimetype, void|string fromname, void|string date, void|string message_id, void|string in_reply_to, void|string reply_to, void|string mail_followup_to)
{
    Message msg = Message();
    msg->email   = email;
    msg->subject = subject;
    msg->body    = body;
    msg->mimetype = (stringp(mimetype) ? mimetype : "text/plain");
    msg->date    = date||MOD("message")->get_time(time());
    msg->message_id = message_id||("<"+(string)time()+(fromobj||("@"+_Server->get_server_name()))+">");
    if(reply_to)
      msg->reply_to=reply_to;
    if(mail_followup_to)
      msg->mail_followup_to=mail_followup_to;
    if(in_reply_to)
      msg->in_reply_to=in_reply_to;

    SMTP_LOG("send_mail(to="+email+"\n"+")\n");
    
    if ( stringp(from) )
        msg->from    = from;
    if ( stringp(fromobj) )
	msg->fromobj = fromobj;
    if ( stringp(fromname) )
        msg->fromname = fromname;

    aMessages += ({ msg });
    require_save();

    MsgQueue->write(msg);
}

void send_mail_mime(string email, object message)
{
    mapping mimes = message->query_attribute(MAIL_MIMEHEADERS);
    string from;
    sscanf(mimes->from, "%*s<%s>", from);
    send_mail(email, message->get_identifier(), message->get_content(), from);
}

static mixed cb_tag(Parser.HTML p, string tag)
{
    if ( search(tag, "<br") >= 0 || search (tag, "<BR") >= 0 )
	return ({ "\n" });
    return ({ "" });
}

void send_message(Message msg)
{
  string server;
  int      port;
  mixed     err;
  object   smtp;

  server = _Server->query_config(CFG_MAILSERVER);
  port   = (int)_Server->query_config(CFG_MAILPORT);

  SMTP_LOG("send_message("+server+":"+port+")");


  // if no server is configured use the e-mail of the sender
  if ( !stringp(server) || strlen(server) == 0 ) {
      string host = array_sscanf(msg->email, "%*s@%s")[0];
      server = Protocols.DNS.client()->get_primary_mx(host);
      port = 25;
  }
  if ( !stringp(msg->from) )
      msg->from = _Server->query_config(CFG_EMAIL); 

  if ( stringp(msg->mimetype) && search(msg->mimetype, "text") != -1 ) {
      object parser = Parser.HTML();
      parser->_set_tag_callback(cb_tag);
      parser->feed(msg->body);
      parser->finish();
      msg->body = parser->read();
  }
  
  if ( !stringp(msg->mimetype) )
      msg->mimetype = "text/plain";

  MIME.Message mmsg = MIME.Message(
      msg->body||"",
      ([ "Content-Type": (msg->mimetype||"text/plain") + "; charset=iso-8859-1",
	 "Subject": msg->subject||"",
         "Date": msg->date||"",
         "From": msg->fromname||msg->from||msg->fromobj||"",
         "To": (msg->fromobj ? msg->fromobj : msg->email)||"",
	 "Message-Id": msg->message_id||"",
	 ]) );
	 
      if(msg->mail_followup_to)
         mmsg->headers["Mail-Followup-To"]=msg->mail_followup_to;
      if(msg->reply_to)
         mmsg->headers["Reply-To"]=msg->reply_to;
      if(msg->in_reply_to)
         mmsg->headers["In-Reply-To"]=msg->in_reply_to;

  smtp = Protocols.SMTP.client(server, port);
  
  smtp->send_message(msg->from, ({ msg->email }), (string)mmsg);
  MESSAGE("send_message("+msg->email + ") send!");
  aMessages -= ({ msg });
  require_save();
}

void smtp_thread()
{
    Message msg;

    while ( 1 ) {
	SMTP_LOG("smtp-thread running...");
	msg = MsgQueue->read();
	mixed err = catch {
	    send_message(msg);
	};
	if ( err != 0 ) {
	    MESSAGE("Error while sending message:" + err[0] + 
		sprintf("\n%O\n", err[1]));
	    MESSAGE("MAILSERVER="+_Server->query_config(CFG_MAILSERVER));
	    if ( objectp(oSMTP) ) {
		destruct(oSMTP);
		oSMTP = 0;
	    }
	    // dont repeat sending messages with syntax errors !
	    if ( search(err[0], "Syntax error") == -1 )
		MsgQueue->write(msg); // send again, or try to
	    else {
		aMessages -= ({ msg });
		require_save();
	    }
	    
	    sleep(60); // wait one minute before retrying
	}
    }
}

string get_identifier() { return "smtp"; }







