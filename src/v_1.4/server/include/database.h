#ifndef _DATABASE_H
#define _DATABASE_H

#define ID_DATABASE 1

#define _SECURITY _Server->get_module("security")
#define _FILEPATH _Server->get_module("filepath:tree")
#define _TYPES _Server->get_module("types")
#define _LOG _Server->get_module("log")

#define OBJ(s) _FILEPATH->path_to_object(s)

#define MODULE_USERS   (_Server ? _Server->get_module("users") : 0)
#define MODULE_GROUPS  (_Server ? _Server->get_module("groups") : 0)
#define MODULE_OBJECTS (_Server ? _Server->get_module("objects") : 0)
#define MODULE_SMTP    (_Server ? _Server->get_module("smtp") : 0)
#define MODULE_URL     (_Server ? _Server->get_module("url") : 0)
#define SECURITY_CACHE (_Server ? _Server->get_module("Security:cache"):0)

#define MOD(s) (_Server->get_module(s))
#define USER(s) MODULE_USERS->lookup(s)
#define GROUP(s) MODULE_GROUPS->lookup(s)

#define _ROOTROOM MODULE_OBJECTS->lookup("rootroom")
#define _STEAMUSER MODULE_GROUPS->lookup("sTeam")
#define _ROOT MODULE_USERS->lookup("root")
#define _GUEST MODULE_USERS->lookup("guest")

#define _ADMIN MODULE_GROUPS->lookup("Admin")
#define _WORLDUSER (MODULE_GROUPS?MODULE_GROUPS->lookup("Everyone"):0)
#define _AUTHORS MODULE_GROUPS->lookup("authors")
#define _REVIEWER MODULE_GROUPS->lookup("reviewer")
#define _BUILDER MODULE_GROUPS->lookup("builder")
#define _CODER MODULE_GROUPS->lookup("coder")


#define PSTAT_FAIL_DELETED       -3
#define PSTAT_FAIL_UNSERIALIZE   -2
#define PSTAT_FAIL_COMPILE       -1
#define PSTAT_DISK                0
#define PSTAT_SAVE_OK             1
#define PSTAT_SAVE_PENDING        2

#define PSTAT_NAMES ({ "deleted", "unserialize failed", "compile failed", \
"on disk", "Ok", "save pending" })

#define PSTAT(i) PSTAT_NAMES[(i+3)]

#endif





