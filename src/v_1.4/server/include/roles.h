#ifndef _ROLES_H
#define _ROLES_H

#define ROLE_READ_ALL          1 // roles are related to sanction permissions
#define ROLE_EXECUTE_ALL       2
#define ROLE_MOVE_ALL          4
#define ROLE_WRITE_ALL         8
#define ROLE_INSERT_ALL        16
#define ROLE_ANNOTATE_ALL      32
#define ROLE_SANCTION_ALL      (1<<8)
#define ROLE_REBOOT            (1<<16) // here are sanction-permission 
#define ROLE_REGISTER_CLASSES  (1<<17) // independent roles(at negative rights)
#define ROLE_GIVE_ROLES        (1<<18)
#define ROLE_CHANGE_PWS        (1<<19)
#define ROLE_REGISTER_MODULES  (1<<20)
#define ROLE_CREATE_TOP_GROUPS (1<<21)

#define ROLE_ALL_ROLES       (1<<31)-1+(1<<30)

#endif
