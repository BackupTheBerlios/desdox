#ifndef _MACROS_H
#define _MACROS_H


#include "exception.h"
#include "config.h"

#define bool int
#define true  1
#define false 0
#define null  0

#define PROXY(o) (o->this)
#define MIN(i,j) (i < j ? i : j)
#define CALLER Caller.get_caller(this_object(), backtrace())
#define MCALLER (CALLER == master() ? PREVCALLER : CALLER)

#define PREVCALLER function_object(backtrace()[-3][2])

#define CALLINGFUNCTION function_name(backtrace()[-2][2])

#define CALLERCLASS backtrace()[-2][0]

#define CALLERPROGRAM object_program(function_object(backtrace()[-2][2]))

#define MESSAGE(s, args...) werror(s+"\n", args)

#ifdef DEBUG
#define LOG(s) werror(s+"\n")
#else
#define LOG(s)
#endif

#define FATAL(s, args...) werror(s+"\n", args)

#define _LOG(s) werror("("+this_object()->get_object_id()+") "+s+"\n")

#ifdef DEBUG
#define TRACE(s) werror("["+master()->stupid_describe(this_object())+"]"+s+"\n")
#else
#define TRACE(s) 
#endif

#define LOG_DB(s) catch {_Server->get_module("log")->log_database(s); }
//#define LOG_DB

//#define LOG_DB(s) werror("DB:"+s+"\n")

//#define SECURITY_LOG(s) if ( 1 ) { mixed __err = catch { _LOG->log_security(s); }; if (__err != 0 ) { _LOG->log_security("Error in logging !"+sprintf("%O",__err)); } }

#define SECURITY_LOG(s) if (1) {if (_Server->get_module("log")) _Server->get_module("log")->log_security(s);}
#define LOG_BOOT(s) catch { _LOG->log_boot(s); }

#define LOG_EVENT(s) catch{_LOG->log_event(s);}

#define LOG_ERR(s) catch{_LOG->log_error(s);}

#define LOG_DEBUG(s) catch{_Server->get_module("log")->log_debug(s);}
#define PRINT_BT(c) ("Error: " + c[0] + "\n" + master()->describe_backtrace(c[1]))

#define THROW(c, e) throw( ({ c, backtrace(), e}))
#define IS_SOCKET(o) (master()->is_socket(o))

#define NIL (([])[""])

#define CONTENTOF(x) _FILEPATH->path_to_object(x)->get_content()

#define T_INT     "int"
#define T_STRING  "string"
#define T_FLOAT   "float"
#define T_OBJECT  "object"
#define T_MAPPING "mapping"
#define T_ARRAY   "array"



#define IS_PROXY(o) (object_program(o) == (program)"/kernel/proxy.pike")

#define URLTYPE_FS       0
#define URLTYPE_DB       1
#define URLTYPE_HTTP     2
#define URLTYPE_RELOC    3
#define URLTYPE_DBO      4
#define URLTYPE_DBFT     5

#define MAX_BUFLEN       65504    

#endif





