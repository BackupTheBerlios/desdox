#ifndef _CONFIG_H
#define _CONFIG_H

//#define DEBUG 1
//#define PROFILING 
//#define DEBUG_MEMORY
//#define EVENT_DEBUG

#define USER_SCRIPTS 0

#define BLOCK_SIZE 32000
#define DB_CHUNK_SIZE 8192
#define SOCKET_READ_SIZE 65536
#define HTTP_MAX_BODY  20000000

#define OBJ_COAL   "/kernel/securesocket.pike"
#define OBJ_SCOAL   "/kernel/securesocket.pike"
#define OBJ_NNTP   "/net/nntp.pike"
#define OBJ_SMTP   "/net/smtp.pike"
#define OBJ_IMAP   "/net/imap.pike"
#define OBJ_POP3   "/net/pop3.pike"
#define OBJ_IRC    "/net/irc.pike"
#define OBJ_FTP    "/net/ftp.pike"
#define OBJ_JABBER "/net/jabber.pike"
#define OBJ_TELNET "/net/telnet.pike"
#define OBJ_XMLRPC "/net/xmlrpc.pike"

#define STEAM_VERSION "1.4.4"

#define CLASS_PATH "classes/"

#define LOGFILE_DB "logs/database.log"
#define LOGFILE_SECURITY "logs/security.log"
#define LOGFILE_ERROR "logs/errors.log"
#define LOGFILE_BOOT "logs/boot.log"
#define LOGFILE_EVENT "logs/events.log"
#define LOGFILE_DEBUG "logs/debug.log"

#define STEAM_DB_CONNECT _Server->get_database()

#define CFG_WEBSERVER      "web_server"
#define CFG_WEBPORT_HTTP   "web_port_http"
#define CFG_WEBPORT_FTP    "web_port_ftp"
#define CFG_WEBPORT        "web_port_"
#define CFG_WEBPORT_URL    "web_port"
#define CFG_WEBMOUNT       "web_mount"
#define CFG_MAILSERVER     "mail_server"
#define CFG_MAILPORT       "mail_port"
#define CFG_EMAIL          "account_email"
#define CFG_DOMAIN         "domain"


#define CFG_WEBPORT_PRESENTATION  "web_port"
#define CFG_WEBPORT_ADMINISTRATION "web_port_http"

#define THREAD_READ 1
#undef RESTRICTED_NAMES

#endif
