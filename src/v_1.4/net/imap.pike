/* Copyright (C) 2002  Christian Schmidt
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
 * implements a imap4-server, see rfc2060
 * sTeam-documents are converted using the mailbox-module
 */

inherit "/net/coal/login";
inherit "/net/base/line";

#include <macros.h>
#include <config.h>
#include <database.h>
#include <events.h>

#include <client.h>
#include <attributes.h>

//states of the server
#define STATE_NONAUTHENTICATED 1
#define STATE_AUTHENTICATED 2
#define STATE_SELECTED 3

//flags for mails
#define SEEN     (1<<0)
#define ANSWERED (1<<1)
#define FLAGGED  (1<<2)
#define DELETED  (1<<3)
#define DRAFT    (1<<4)

static int _state = STATE_NONAUTHENTICATED;
static string sServer = _Server->query_config("machine");
static string sDomain = _Server->query_config("domain");
static string sFQDN = sServer+"."+sDomain;
static object oMailBox,oUser;
static int iUIDValidity=0;
static mapping (int:int) mMessageNums=([]);

//the following maps commands to functions
//depending on the state of the server
static mapping mCmd = ([
    STATE_NONAUTHENTICATED: ([
        "CAPABILITY":   capability,
        "NOOP":         noop,
        "LOGOUT":       logout,
        "AUTHENTICATE": authenticate,
        "LOGIN":        login,
    ]),
    STATE_AUTHENTICATED: ([
        "CAPABILITY":   capability,
        "NOOP":         noop,
        "LOGOUT":       logout,
        "SELECT":       select,
        "EXAMINE":      examine,
        "CREATE":       do_create,
        "DELETE":       delete,
        "RENAME":       rename,
        "SUBSCRIBE":    subscribe,
        "UNSUBSCRIBE":  unsubscribe,
        "LIST":         list,
        "LSUB":         lsub,
        "STATUS":       status,
        "APPEND":       append,
    ]),
    STATE_SELECTED: ([
        "CAPABILITY":   capability,
        "NOOP":         noop,
        "LOGOUT":       logout,
        "SELECT":       select,
        "EXAMINE":      examine,
        "CREATE":       do_create,
        "DELETE":       delete,
        "RENAME":       rename,
        "SUBSCRIBE":    subscribe,
        "UNSUBSCRIBE":  unsubscribe,
        "LIST":         list,
        "LSUB":         lsub,
        "STATUS":       status,
        "APPEND":       append,
        "CHECK":        check,
        "CLOSE":        close,
        "EXPUNGE":      expunge,
        "SEARCH":       do_search,
        "FETCH":        fetch,
        "STORE":        store,
        "COPY":         copy,
        "UID":          uid,
    ]),
]);



/**********************************************************
 * conversion, parser...
 */

//converts a timestamp to a human-readable form
static string time_to_string(int timestamp)
{
    array(string) month=({"Jan","Feb","Mar","Apr","May","Jun",
                          "Jul","Aug","Sep","Oct","Nov","Dec"});

    mapping(string:int) parts=localtime(timestamp);
    parts["year"]+=1900;
    string result;
    if(parts["mday"]<10) result=" "+parts["mday"];
    else result=(string)parts["mday"];
    result=result+"-"+month[parts["mon"]]+"-"+parts["year"]+" ";
    if(parts["hour"]<10) result+="0"+parts["hour"];
    else result+=parts["hour"];
    result+=":";

    if(parts["min"]<10) result+="0"+parts["min"];
    else result+=parts["min"];
    result+=":";

    if(parts["sec"]<10) result+="0"+parts["sec"];
    else result+=parts["sec"];
    result+=" ";

    int timezone=parts["timezone"]/-3600;
    if(timezone<0)
    {
        timezone=0-timezone;
        result+="-";
    }
    else result+="+";
    if(timezone<10) result=result+"0"+timezone+"00";
    else result=result+timezone+"00";
    return result;
}

//convert a flag-pattern to a string
static string flags_to_string(int flags)
{
    string t="";

    if (flags==0) return t;

    if (flags & SEEN) t=t+"\\Seen ";
    if (flags & ANSWERED) t=t+"\\Answered ";
    if (flags & FLAGGED) t=t+"\\Flagged ";
    if (flags & DELETED) t=t+"\\Deleted ";
    if (flags & DRAFT) t=t+"\\Draft ";

    t=String.trim_whites(t);

    return t;
}

//convert a flag-string to a number
static int string_to_flags(string flags)
{
    int t=0;

    array parts = flags/" ";
    int err=0;

    for (int i=0;i<sizeof(parts);i++)  //parse flags
    {
        string tmp=upper_case(parts[i]);
        tmp=String.trim_whites(tmp); //remove trailing whitespace
        switch(tmp)
        {
            case "\\SEEN":
                t=t|SEEN;
                break;
            case "\\ANSWERED":
                t=t|ANSWERED;
                break;
            case "\\FLAGGED":
                t=t|FLAGGED;
                break;
            case "\\DELETED":
                t=t|DELETED;
                break;
            case "\\DRAFT":
                t=t|DRAFT;
                break;
            default: //unsupported flag -> error!
                LOG("Unknown flag in STORE: "+tmp);
                err=1;
        }
    }

    if(err) t=-1;

    return t;
}

//convert a range-string ("4:7") to array (4,5,6,7)
static array(int) parse_range(string range)
{
    array(int) set=({});

    if(sscanf(range,"%d:%d", int min, int max)==2)
    {
        for(int i=min;i<=max;i++) set=set+({i});
    }
    else if(sscanf(range,"%d",int val)==1) set=set+({val});
    //if range can't be parsed, an empty array is returned

    return set;
}

//convert a set ("2,4:7,12") to array (2,4,5,6,7,12);
static array(int) parse_set(string range)
{
    array(int) set=({});

    array(string) parts=range/","; //split range into single ranges/numbers
    foreach(parts,string tmp) {set=set+parse_range(tmp);}

    return set;
}

//split a quoted string into its arguments
static array(string) parse_quoted_string(string data)
{
    array(string) result=({});

    if(search(data,"\"")!=-1)
    {
        //process string
        int i=0,j=0;
        while(i<sizeof(data))
        {
            switch (data[i])
            {
                case '\"':
                    j=search(data,"\"",i+1); //search for matching "
                    if (j==-1) return ({}); //syntax error
                    else result=result+({data[i+1..j-1]});
                    i=j+1;
                    break;
                case ' ':
                    i=i+1;
                    break;
                default:
                    j=search(data," ",i); //unquoted string mixed with quoted string
                    if (j==-1)
                    {
                        result=result+({data[i..sizeof(data)-1]});
                        i=sizeof(data);
                    }
                    else
                    {
                        result=result+({data[i..j-1]});
                        i=j+1;
                    }
                    break;
            }
        }
    }
    else result=data/" "; //data had no ", just split at spaces

    return result;
}

//parse the parameter of a fetch-command
//see rfc2060 for details
static array(string) parse_fetch_string(string data)
{
    array(string) result=({});
    array(string) tmp;

    if(data[0]=='(')
    {
        if(data[sizeof(data)-1]==')')
            {
                data=data[1..sizeof(data)-2]; //remove ()
                tmp=parse_quoted_string(data);
            }
    }
    else tmp=({data}); //parameter has only one argument


    int i=0;

    while(i<sizeof(tmp))
    {
        switch(upper_case(tmp[i]))
        {
            case "ENVELOPE":
            case "FLAGS":
            case "INTERNALDATE":
            case "RFC822":
            case "RFC822.HEADER":
            case "RFC822.SIZE":
            case "RFC822.TEXT":
            case "BODY":
            case "BODYSTRUCTURE":
            case "UID":
                string t=upper_case(tmp[i]);
                result=({t})+result;
                i++;
                break;
            case "ALL":
                result=({"FLAGS","INTERNALDATE","RFC822.SIZE","ENVELOPE"})+result;
                i++;
                break;
            case "FAST":
                result=({"FLAGS","INTERNALDATE","RFC822.SIZE"})+result;
                i++;
                break;
            case "FULL":
                result=({"FLAGS","INTERNALDATE","RFC822.SIZE","ENVELOPE","BODY"})+
                 result;
                i++;
                break;
            default:
                if(search(upper_case(tmp[i]),"BODY")!=-1) //"BODY..." has special syntax
                {
                    string t="";
                    int j=i+1;
                    if(j==sizeof(tmp)) //last argument, no further processing needed
                    {
                        result+=({upper_case(tmp[i])});
                        return result;
                    }
                    if(search(tmp[i],"]")==-1)
                    {
                        while(search(tmp[j],"]")==-1 && j<sizeof(tmp))
                            j++; //search for closing ]
                        if(j<sizeof(tmp))
                            for(int a=i;a<=j;a++) t+=tmp[a]+" ";
                            //copy the whole thing as one string
                        else
                        {
                            LOG("unexpected end of string while parsing BODY...");
                            return ({}); //syntax error
                        }

                        t=t[0..sizeof(t)-2];
                        result+=({t});
                        i=j+1;
                    }
                    else
                    {
                        result+=({upper_case(tmp[i])});
                        i++;
                    }
                }
                else
                {
                    LOG("unknown argument to FETCH found: "+upper_case(tmp[i]));
                    return ({}); //syntax error
                }
                break;
        }
    }//while

    return result;
}

//reformat a mail-adress, see rfc2060
string adress_structure(string data)
{
    data-="\"";
    string result="(";

    array(string) parts=data/",";
    for(int i=0;i<sizeof(parts);i++)
    {
        string name,box,host;
        int res=sscanf(parts[i],"%s<%s@%s>",name,box,host);
        if(res!=3)
        {
            res=sscanf(parts[i],"%s@%s",box,host); 
            if (res!=2)
            {
                LOG("parse error in adress_structure() !");
                return ""; //parse error
            }
            name="NIL";
        }
        if(sizeof(name)==0) name="NIL";
        else
        {
            name=String.trim_whites(name);
            name="\""+name+"\"";
        }
        result+="("+name+" NIL \""+box+"\" \""+host+"\")";
    }

    result+=")";
    return result;
}

//convert header-informations to structured envelope-data
string get_envelope_data(int num)
{
    mapping(string:string) headers=oMailBox->message_headers(num);
    string t,result="(\"";

    t=headers["date"];
    if(t==0) t=time_to_string(oMailBox->message_internal_date(num));
    result=result+t+"\" ";

    t=headers["subject"];
    if(t==0) t="";
    result=result+"\""+t+"\" ";

    string from=headers["from"];
    if(from==0) from="NIL";
        else from=adress_structure(from);
    result=result+from+" ";

    t=headers["sender"];
    if(t==0) t=from;
        else t=adress_structure(t);
    result=result+t+" ";

    t=headers["reply-to"];
    if(t==0) t=from;
        else t=adress_structure(t);
    result=result+t+" ";

    t=headers["to"];
    if(t==0) t="NIL";
        else t=adress_structure(t);
    result=result+t+" ";

    t=headers["cc"];
    if(t==0) t="NIL";
        else t=adress_structure(t);
    result=result+t+" ";

    t=headers["bcc"];
    if(t==0) t="NIL";
        else t=adress_structure(t);
    result=result+t+" ";

    t=headers["in-reply-to"];
    if(t==0) t="NIL";
        else t="\""+t+"\"";
    result=result+t+" ";

    t=headers["message-id"];
    if(t==0) t="NIL";
        else t="\""+t+"\"";
    result=result+t;

    result+=")";
    return result;
}

//combine all headers of a message to one string
string headers_to_string(mapping headers)
{
    string result="";

    foreach(indices(headers),string key)
        result+=String.capitalize(key)+": "+headers[key]+"\r\n";

    return result+"\r\n"; //header and body are seperated by newline
}

//parse & process the "BODY..." part of a fetch-command
//see rfc2060 for complete syntax of "BODY..."
string process_body_command(int num, string data)
{
    string result,tmp,dummy,cmd,arg;
    mapping(string:string) headers;
    int i=0;

    data-=".PEEK";
    while(data[i]!='[' && i<sizeof(data)) i++;
    if(i==sizeof(data)) return ""; //parse error
    result=data[0..i];
    tmp=data[i+1..sizeof(data)-2];
    if(sscanf(tmp,"%s(%s)", cmd, arg)==0)
        cmd=tmp;
    cmd-=" ";
    switch(cmd)
    {
        case "HEADER":
            headers=oMailBox->message_headers(num);
            dummy=headers_to_string(headers);
            result+="HEADER] {"+sizeof(dummy)+"}\r\n"+dummy;
            break;
        case "TEXT":
            dummy=oMailBox->message_body(num)+"\r\n";
            result+="TEXT] {"+sizeof(dummy)+"}\r\n"+dummy;
            break;
        case "HEADER.FIELDS":
            dummy="";
            headers=oMailBox->message_headers(num);
            array(string) wanted=arg/" ";
            foreach(wanted,string key)
                if(headers[lower_case(key)]!=0)
                    dummy+=String.capitalize(lower_case(key))+
                     ": "+headers[lower_case(key)]+"\r\n";
            dummy+="\r\n";
            result+="HEADER] {"+sizeof(dummy)+"}\r\n"+dummy;
            break;
        default:
            int part;
            if(sscanf(cmd,"%d",part)==1)
            {
                dummy=oMailBox->message_body(num);
                result+="1] {"+sizeof(dummy)+"}\r\n"+dummy;
            }
            else
            {
                headers=oMailBox->message_headers(num);
                dummy=headers_to_string(headers)+"\r\n";
                dummy+=oMailBox->message_body(num)+"\r\n";
                result+="] {"+sizeof(dummy)+"}\r\n"+dummy;
            }
            break;
    }

    return result;
}

//get the imap-bodystructure of a message
string get_bodystructure(int num)
{
    string result="(\"TEXT\" \"PLAIN\" NIL NIL NIL \"8BIT\" ";
    result+=oMailBox->get_body_size(num)+" ";
    result+=sizeof(oMailBox->message_body(num)/"\n")+")";

    return result;
}

static void send_reply_untagged(string msg)
{
    send_message("* "+msg+"\r\n");
}

static void send_reply(string tag, string msg)
{
    send_message(tag+" "+msg+"\r\n");
}

void create(object f)
{
    ::create(f);

    string sTime=ctime(time());
    sTime=sTime-"\n";   //remove trailing LF
    send_reply_untagged("OK IMAP4rev1 Service Ready on "+sFQDN+", "+sTime);
}

//called automaticly for selected events (oUser->listen_to_event(...))
void notify(int event, mixed ... args)
{
    int id;
    
    switch(event)
    {
        case EVENT_ENTER_INVENTORY:
            if(args[0]->get_object_id()!=iUIDValidity) break;
             //target object is not the mailbox -> ignore this event
            
            id=args[1]->get_object_id();
            LOG(oUser->get_identifier()+" recieved new mail #"+id);
            int num=oMailBox->get_num_messages();
            send_reply_untagged(num+" EXISTS");
            
            mMessageNums+=([id:num]);
             //new message added, update mapping of uids to msns
            break;
        case EVENT_LEAVE_INVENTORY:
            if(args[0]->get_object_id()!=iUIDValidity) break;
             //mailbox is not mentioned is this event -> ignore it
            
            id=args[1]->get_object_id();
            LOG("Mail #"+id+
             " removed from mailbox of "+oUser->get_identifier());
            send_reply_untagged(mMessageNums[id]+" EXPUNGE");
            
            m_delete(mMessageNums,id);
             //message deleted, remove its record from mapping of uids to msns
            break;
     }
}

/***************************************************************************
 * IMAP commands
 */


static void capability(string tag, string params)
{
    if ( sizeof(params)>0 ) send_reply(tag,"BAD arguments invalid");
    else
    {
        send_reply_untagged("CAPABILITY IMAP4rev1");
        send_reply(tag,"OK CAPABILITY completed");
    }
}

static void noop(string tag, string params)
{
    send_reply(tag,"OK NOOP completed");
}

static void logout(string tag, string params)
{
    send_reply_untagged("BYE server closing connection");
    send_reply(tag,"OK LOGOUT complete");

    if( objectp(oUser) )
    {
//        oUser->dispose_event(EVENT_ENTER_INVENTORY|EVENT_LEAVE_INVENTORY,oMailBox->this());
        oUser->disconnect();
    }

    close_connection();
}

static void authenticate(string tag, string params)
{
    send_reply(tag,"NO AUTHENTICATE command not supported - use LOGIN instead");
}

static void login(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);
    if( sizeof(parts)==2 )
    {
        oUser = MODULE_USERS->lookup(parts[0]);
        if ( objectp(oUser) )
        {
            if ( oUser->check_user_password(parts[1]) ) //passwd ok, continue
            {
                login_user(oUser);
                _state = STATE_AUTHENTICATED;
                send_reply(tag,"OK LOGIN completed");
            }
            else send_reply(tag,"NO LOGIN wrong password");
        }
        else send_reply(tag,"NO LOGIN unknown user");
    }
    else send_reply(tag,"BAD arguments invalid");
}

static void select(string tag, string params)
{
    //deselect any selected mailbox
    _state = STATE_AUTHENTICATED;
    iUIDValidity=0;

    params = params-"\""; //strip " from params

    //TODO: support subfolders of inbox
    if ( upper_case(params)=="INBOX" )
    {
        _state = STATE_SELECTED;
        oMailBox = _Server->get_module("mailbox")->get_mailbox(oUser);

        iUIDValidity=oMailBox->get_object_id();
        oMailBox->init_mailbox();
        mMessageNums=oMailBox->get_uid2msn_mapping();

        oUser->listen_to_event(EVENT_ENTER_INVENTORY|EVENT_LEAVE_INVENTORY,oMailBox->this());

        int num = oMailBox->get_num_messages();
        
        send_reply_untagged("FLAGS (\\Answered \\Deleted \\Seen \\Flagged \\Draft)");
        send_reply_untagged("OK [PERMANENTFLAGS (\\Answered \\Deleted \\Seen \\Flagged \\Draft)]");
        send_reply_untagged(num+" EXISTS");
        send_reply_untagged("0 RECENT"); //"recent"-flag is not supported yet
        send_reply_untagged("OK [UIDVALIDITY "+iUIDValidity+"] UIDs valid");

        send_reply(tag,"OK [READ-WRITE] SELECT completed");
    }
    else send_reply(tag,"NO SELECT failed, Mailbox does not exist");
}

static void examine(string tag, string params)
{
    //deselect any selected mailbox
    _state = STATE_AUTHENTICATED;
    iUIDValidity=0;


    //TODO: support subfolders of inbox
    if ( params=="INBOX" )
    {
        _state = STATE_SELECTED;
        oMailBox = _Server->get_module("mailbox")->get_mailbox(oUser);
        iUIDValidity=oMailBox->get_object_id();

        int num = oMailBox->get_num_messages();

        send_reply_untagged("FLAGS (\\Answered \\Deleted \\Seen \\Flagged \\Draft)");
        send_reply_untagged(num+" EXISTS");
        send_reply_untagged("0 RECENT");
        send_reply_untagged("OK [UIDVALIDITY "+iUIDValidity+"] UIDs valid");

        send_reply(tag,"OK [READ-ONLY] EXAMINE completed");
    }
    else send_reply(tag,"NO EXAMINE failed, Mailbox does not exist");
}

static void do_create(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);

    if(sizeof(parts)==1) send_reply(tag,"NO CREATE Permission denied");
    else send_reply(tag,"BAD arguments invalid");

    //creation of subfolders is not supported yet
}

static void delete(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);

    if(sizeof(parts)==1) send_reply(tag,"NO DELETE Permission denied");
    else send_reply(tag,"BAD arguments invalid");
}

static void rename(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);

    if(sizeof(parts)==2) send_reply(tag,"NO RENAME Permission denied");
    else send_reply(tag,"BAD arguments invalid");
}

static void subscribe(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);

    if(sizeof(parts)==1) send_reply(tag,"NO SUBSCRIBE not supported");
    else send_reply(tag,"BAD arguments invalid");
}

static void unsubscribe(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);

    if(sizeof(parts)==1) send_reply(tag,"NO UNSUBSCRIBE not supported");
    else send_reply(tag,"BAD arguments invalid");
}

static void list(string tag, string params)
{
    array(string) args=parse_quoted_string(params);
    if(sizeof(args)==2)
    {
        if ( args[0]=="" || upper_case(args[0])=="INBOX" ) //TODO: support subfolders
        {
            //list selected mailbox -> INBOX
            switch ( args[1] )
            {
                case "":
                    send_reply_untagged("LIST (\\Noselect) \".\" \"\"");
                    break;
                case "*":
                case "%":
                    send_reply_untagged("LIST (\\Noinferiors) \".\" \"INBOX\" ");
                    break; //TODO: list all subfolders if supported
                case "INBOX":
                case "INBOX*":
                    send_reply_untagged("LIST (\\Noinferiors) \".\" \"INBOX\" ");
                    break;
                default:
                    break; //TODO: list matching subfolders
            }
            send_reply(tag,"OK LIST completed");
        }
        else send_reply(tag,"NO LIST cannot list that reference or name");
    }
    else send_reply(tag,"BAD arguments invalid");
}

static void lsub(string tag, string params)
{
    send_reply(tag,"OK LSUB completed");
}

static void status(string tag, string params)
{
    if(sscanf(params,"%s (%s)",string mailbox, string what)==2)
    {
        mailbox=upper_case(mailbox)-"\"";
        if(mailbox=="INBOX")
        {
            if(_state==STATE_AUTHENTICATED)
                oMailBox=_Server->get_module("mailbox")->get_mailbox(oUser);
            array(string) items=what/" ";
            string result="";
            foreach(items, string tmp)
            {
                switch (upper_case(tmp))
                {
                    case "MESSAGES":
                        result+=" MESSAGES "+oMailBox->get_num_messages();
                        break;
                    case "RECENT":
                        result+=" RECENT 0"; // recent-flag is not supported yet
                        break;
                    case "UIDNEXT":
                        result+=" UIDNEXT 12345"; //TODO: return correct value
                        break;
                    case "UIDVALIDITY":
                        result+=" UIDVALIDITY "+iUIDValidity;
                        break;
                    case "UNSEEN":
                        int max=oMailBox->get_num_messages();
                        int unseen=max;
                        for(int i=0;i<max;i++)
                            if(oMailBox->has_flag(i,SEEN)) unseen--;
                        result+=" UNSEEN "+unseen;
                        break;
                    default:
                        send_reply(tag,"BAD arguments invalid");
                        return;
                        break;
                }
            }
            result="("+String.trim_whites(result)+")";
            send_reply_untagged("STATUS \""+mailbox+"\" "+result);
            send_reply(tag,"OK STATUS completed");
        }
        else send_reply(tag,"NO mailbox does not exist");
    }
    else send_reply(tag,"BAD arguments invalid");
}

static void append(string tag, string params)
{
    send_reply(tag,"NO command is not implemented yet!");
}

static void check(string tag, string params)
{
    send_reply(tag,"OK CHECK completed");
}

static void close(string tag, string params)
{
    send_reply(tag,"NO command is not implemented yet!");
}

static void expunge(string tag, string params)
{
    oMailBox->delete_mails();
    /* This causes the mailbox-module to delete all mails, which have the
     * deleted-flag set. The notify-function of this socket is called then
     * with EVENT_LEAVE_INVENTORY, which sends the required "* #msn EXPUNGE"
     * message(s) to the connected mailclient.
     */

    send_reply(tag,"OK EXPUNGE completed");
}

static void do_search(string tag, string params)
{
    array(string) parts = parse_quoted_string(params);
    int i=0,err=0;
    int not=0, or=0;
    int num=oMailBox->get_num_messages();

    array(int) result=({});
    array(int) tmp=({});

    while (i<sizeof(parts))
    {
        tmp=({});
        switch(parts[i])
        {   //not all search-parameters are supported yet
            case "ALL":
                for(int j=0;j<num;j++) tmp=tmp+({j+1});
                result=tmp;
                i++;
                break;
            case "ANSWERED":
                for (int j=0;j<num;j++)
                    if(oMailBox->has_flag(j,ANSWERED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "BCC":
                i+=2;
                break;
            case "BEFORE":
                i+=2;
                break;
            case "BODY":
                i+=2;
                break;
            case "CC":
                i+=2;
                break;
            case "DELETED":
                for (int j=0;j<num;j++)
                    if(oMailBox->has_flag(j,DELETED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "FLAGGED":
                for (int j=0;j<num;j++)
                    if(oMailBox->has_flag(j,FLAGGED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "FROM":
                i+=2;
                break;
            case "KEYWORD":
                i+=2;
                break;
            case "NEW":
                break;
            case "OLD":
                break;
            case "ON":
                i+=2;
                break;
            case "RECENT":
                i++;
                break;
            case "SEEN":
                for (int j=0;j<num;j++)
                    if(oMailBox->has_flag(j,SEEN)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "SINCE":
                i+=2;
                break;
            case "SUBJECT":
                i+=2;
                break;
            case "TEXT":
                i+=2;
                break;
            case "TO":
                i+=2;
                break;
            case "UNANSWERED":
                for (int j=0;j<num;j++)
                    if(!oMailBox->has_flag(j,ANSWERED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "UNDELETED":
                for (int j=0;j<num;j++)
                    if(!oMailBox->has_flag(j,DELETED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "UNFLAGGED":
                for (int j=0;j<num;j++)
                    if(!oMailBox->has_flag(j,FLAGGED)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "UNKEYWORD":
                i+=2;
                break;
            case "UNSEEN":
                for (int j=0;j<num;j++)
                    if(!oMailBox->has_flag(j,SEEN)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "DRAFT":
                for (int j=0;j<num;j++)
                    if(oMailBox->has_flag(j,DRAFT)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            case "HEADER":
                i+=3;
                break;
            case "LARGER":
                i+=2;
                break;
            case "NOT":
                not=1; i++;
                break;
            case "OR":
                or=1; i++;
                break;
            case "SENTBEFORE":
                i+=2;
                break;
            case "SENTON":
                i+=2;
                break;
            case "SENTSINCE":
                i+=2;
                break;
            case "SMALLER":
                i+=2;
                break;
            case "UID":
                i+=2;
                break;
            case "UNDRAFT":
                for (int j=0;j<num;j++)
                    if(!oMailBox->has_flag(j,DRAFT)) tmp=tmp+({j+1});
                result=result&tmp;
                i++;
                break;
            default:
                //todo: support "(...)"
                tmp=parse_set(parts[i]);
                if (tmp!=({}))
                {
                    result=result&tmp;
                    i++;
                }
                else
                {
                    send_reply(tag,"BAD arguments invalid");
                    return;
                }
                break;
        }
    }//while

    if(!err)
    {
        string final_result="";
        for(i=0;i<sizeof(result);i++) final_result=final_result+" "+result[i];
        send_reply_untagged("SEARCH"+final_result);
        send_reply(tag,"OK SEARCH completed");
    }
    else send_reply(tag,"BAD arguments invalid");
}

static void fetch(string tag, string params, int|void uid_mode)
{
    int num=sscanf(params,"%s %s",string range, string what);
    if(num!=2)
    {
        send_reply(tag,"BAD arguments invalid");
        return;
    }

    int err=0;
    array(int) nums=({});

    if(uid_mode)
    {
//        LOG("starting FETCH in uid-mode: "+range);
        
        if(search(range,"*")!=-1)
        {
            if(range=="*" || range=="1:*")
            {
//                LOG("range selects ALL messages");
                range="1:"+oMailBox->get_num_messages();
                nums=parse_set(range);
                if( nums==({}) ) err=1;
            }
            else
            {
                int start;
                sscanf(range,"%d:*",start);
//                LOG("starting uid is "+start);
                if(zero_type(mMessageNums[start])==1)
                {
                    //search for following uid
                    int max=0xFFFFFFFF;
                    foreach(indices(mMessageNums),int t)
                        if(t>start && t<max)
                            max=t;
                    start=max;
//                      LOG("uid not present, next fitting is "+start);
                }
                if(start<0xFFFFFFFF) start=mMessageNums[start];
                else start=oMailBox->get_num_messages()+1;
//                LOG("starting msn is "+start);
                nums=parse_set(start+":"+oMailBox->get_num_messages());
                if( nums==({}) ) err=1;
            }
        }
        else
        {
            nums=parse_set(range);
            if( nums==({}) ) err=1;
//            LOG("uids:\n"+sprintf("%O",nums));
            nums=oMailBox->uid_to_num(nums);
//            LOG("msns:\n"+sprintf("%O",nums));
        }
    }
    else
    {
        if(range=="*") range="1:*";
        range=replace(range,"*",(string)oMailBox->get_num_messages());
        nums=parse_set(range);
        if( nums==({}) ) err=1;
    }

    array(string) parts=parse_fetch_string(what);
    if( parts==({}) ) err=1;
//    LOG("fetch attributes parsed, result:\n"+sprintf("%O",parts));

    if(!err)
    {
        foreach(nums, int i)
        {
            string res=i+" FETCH (";
            if(uid_mode) res+="UID "+oMailBox->get_message_uid(i-1)+" ";
            for(int j=0;j<sizeof(parts);j++)
            {
                switch(parts[j])
                {
                    case "FLAGS":
                        string tmp=flags_to_string(oMailBox->get_flags(i-1));
                        res+="FLAGS ("+tmp+") ";
                        break;
                    case "UID":
                        if(uid_mode) break; //UID is already in response string
                        int uid=oMailBox->get_message_uid(i-1);
                        res+="UID "+uid+" ";
                        break;
                    case "INTERNALDATE":
                        res+="INTERNALDATE \""+
                         time_to_string(oMailBox->message_internal_date(i-1))+
                         "\" ";
                        break;
                    case "ENVELOPE":
                        res+="ENVELOPE "+
                         get_envelope_data(i-1)+" ";
                        break;
                    case "RFC822.SIZE":
                        res+="RFC822.SIZE "+
                         oMailBox->get_message_size(i-1)+" ";
                        break;
                    case "RFC822.HEADER":
                        string dummy=headers_to_string(oMailBox->message_headers(i-1));
                        res+="RFC822.HEADER {"+sizeof(dummy)+"}\r\n"+dummy;
                        break;
                    case "RFC822":
                        res+="RFC822 "+oMailBox->message_body(i-1)+" ";
                        break;
                    case "BODYSTRUCTURE":
                    case "BODY":
                        res+="BODY "+get_bodystructure(i-1)+" ";
                        break;
                    default:
                        if(search(upper_case(parts[j]),"BODY")!=-1)
                        {
                            if(search(upper_case(parts[j]),"PEEK")==-1
                               && !oMailBox->has_flag(i-1,SEEN))
                            {
                                oMailBox->add_flags(i-1,SEEN);
                                res+="FLAGS ("+
                                 flags_to_string(oMailBox->get_flags(i-1))+") ";
                            }
                            res+=process_body_command(i-1,parts[j]);
                        }
                        else
                        {
                            send_reply(tag,"BAD arguments invalid");
                            return;
                        }
                        break;
                }
            }
            res=String.trim_whites(res)+")";
            send_reply_untagged(res);
        }
        send_reply(tag,"OK FETCH completed");
    }
    else
    {
        if(nums==({})) send_reply(tag,"OK FETCH completed"); //empty or invalid numbers
        else send_reply_untagged("BAD arguments invalid"); //parse error
    }
}

static void store(string tag, string params, int|void uid_mode)
{
    int num=sscanf(params,"%s %s (%s)",string range, string cmd, string tflags);

    if(num!=3)
    {
        send_reply(tag,"BAD arguments invalid");
        return;
    }

    int err=0;

    array(int) nums=({});

    if(uid_mode)
    {
        if(range=="*" || range=="1:*")
        {
            range=replace(range,"*",(string)oMailBox->get_num_messages());
            nums=parse_set(range);
            if( nums==({}) ) err=1;
        }
        else
        {
            nums=parse_set(range);
            if( nums==({}) ) err=1;
            nums=oMailBox->uid_to_num(nums);
        }
    }
    else
    {
        if(range=="*") range="1:*";
        range=replace(range,"*",(string)oMailBox->get_num_messages());
        nums=parse_set(range);
        if( nums==({}) ) err=1;
    }

    int flags=string_to_flags(tflags);
    if (flags==-1) err=1; //can't parse flags

    if(err==0)
    {
        int silent=0;
        string tmp;
        cmd=upper_case(cmd);

        switch(cmd)
        {
            case "FLAGS.SILENT":
                silent=1;
            case "FLAGS":
                foreach(nums,int i)
                {
                    oMailBox->set_flags(i-1,flags);
                    if (!silent)
                    {
                        tmp=flags_to_string(oMailBox->get_flags(i-1));
                        send_reply_untagged(i+" FETCH (FLAGS ("+tmp+"))");
                    }
                }
                break;
            case "+FLAGS.SILENT":
                silent=1;
            case "+FLAGS":
                foreach(nums,int i)
                {
                    oMailBox->add_flags(i-1,flags);
                    if (!silent)
                    {
                        tmp=flags_to_string(oMailBox->get_flags(i-1));
                        send_reply_untagged(i+" FETCH (FLAGS ("+tmp+"))");
                    }
                }
                break;
            case "-FLAGS.SILENT":
                silent=1;
            case "-FLAGS":
                foreach(nums,int i)
                {
                    oMailBox->del_flags(i-1,flags);
                    if (!silent)
                    {
                        tmp=flags_to_string(oMailBox->get_flags(i-1));
                        send_reply_untagged(i+" FETCH (FLAGS ("+tmp+"))");
                    }
                }
                break;
            default:
                send_reply(tag,"BAD arguments invalid");
                return;
        }
        send_reply(tag,"OK STORE completed");
    }
    else send_reply(tag,"BAD arguments invalid");
}

static void copy(string tag, string params)
{
    send_reply(tag,"NO command is not implemented yet!");
}

static void uid(string tag, string params)
{
    sscanf(params,"%s %s",string cmd,string args);
    args=String.trim_whites(args);

    switch(upper_case(cmd))
    {
        case "COPY":
            send_reply(tag,"NO command is not implemented yet!");
            break;
        case "FETCH":
            fetch(tag, args, 1);
            break;
        case "SEARCH":
            send_reply(tag,"NO command is not implemented yet!");
            break;
        case "STORE":
            store(tag, args, 1);
            break;
        default:
            send_reply(tag,"BAD arguments invalid");
            break;
    }
    //completion reply is already sent in called funtion
    //no further send_reply() is needed!
}

static void process_command(string cmd)
{
    string sTag, sCommand, sParams;

    array(string) tcmd = cmd/" ";

    if(sizeof(tcmd)>1) //tag + command
    {
        if(sizeof(tcmd)==2) //command without parameter(s)
        {
            sTag=tcmd[0];
            sCommand=tcmd[1];
            sParams="";
        }
        else sscanf(cmd,"%s %s %s", sTag, sCommand, sParams);

        sCommand = upper_case(sCommand);

//      LOG("Tag: "+sTag+" ; Command: "+sCommand+" ; Params: "+sParams);

        function f = mCmd[_state][sCommand];
        if ( functionp(f) ) f(sTag, sParams);
        else send_reply(sTag,"BAD command not recognized");
    }
    else send_reply(cmd,"BAD command not recognized");
}

string get_socket_name() { return "imap4"; }

int get_client_features() { return CLIENT_FEATURES_EVENTS; }
