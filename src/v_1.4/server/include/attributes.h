#ifndef _ATTRIBUTES_H
#define _ATTRIBUTES_H

#define OBJ_OWNER          101
#define OBJ_NAME           102
#define OBJ_DESC           104
#define OBJ_ICON           105
#define OBJ_KEYWORDS       111
#define OBJ_COMMAND_MAP    112 // objects that can be executed with this
#define OBJ_POSITION_X     113
#define OBJ_POSITION_Y     114
#define OBJ_POSITION_Z     115
#define OBJ_LAST_CHANGED   116
#define OBJ_CREATION_TIME  119
#define OBJ_URL            "url"
#define OBJ_LINK_ICON      "obj:link_icon"
#define OBJ_SCRIPT         "obj_script"
#define OBJ_ANNOTATIONS_CHANGED "obj_annotations_changed"

#define DOC_TYPE            207
#define DOC_MIME_TYPE       208
#define DOC_USER_MODIFIED   213
#define DOC_LAST_MODIFIED   214
#define DOC_LAST_ACCESSED   215
#define DOC_EXTERN_URL      216
#define DOC_TIMES_READ      217
#define DOC_IMAGE_ROTATION  218
#define DOC_IMAGE_THUMBNAIL 219
#define DOC_IMAGE_SIZEX     220
#define DOC_IMAGE_SIZEY     221

#define CONT_SIZE_X         300
#define CONT_SIZE_Y         301
#define CONT_SIZE_Z         302
#define CONT_EXCHANGE_LINKS 303
#define CONT_MONITOR        "cont:monitor"
#define CONT_LAST_MODIFIED  "cont_last_modified"

#define GROUP_MEMBERSHIP_REQS 500
#define GROUP_EXITS           501
#define GROUP_MAXSIZE         502
#define GROUP_MSG_ACCEPT      503  // accept a user from the pending list
#define GROUP_MAXPENDING      504

#define USER_ADRESS        611
#define USER_FULLNAME      612
#define USER_MAILBOX       613
#define USER_WORKROOM      614
#define USER_LAST_LOGIN    615
#define USER_EMAIL         616
#define USER_UMASK         617
#define USER_MODE          618
#define USER_MODE_MSG      619
#define USER_LOGOUT_PLACE  620
#define USER_TRASHBIN      621
#define USER_BOOKMARKROOM  622
#define USER_FORWARD_MSG   623
#define USER_IRC_PASSWORD  624
#define USER_FIRSTNAME     "user_firstname"
#define USER_LANGUAGE      "user_language"
#define USER_SELECTION     "user_selection"
#define USER_FAVOURITES    "user_favorites"

#define DRAWING_TYPE       700
#define DRAWING_WIDTH      701
#define DRAWING_HEIGHT     702
#define DRAWING_COLOR      703
#define DRAWING_THICKNESS  704
#define DRAWING_FILLED     705

#define GROUP_WORKROOM      800
#define GROUP_EXCLUSIVE_SUBGROUPS 801


#define LAB_TUTOR          1000
#define LAB_SIZE           1001
#define LAB_ROOM           1002
#define LAB_APPTIME        1003

#define MAIL_MIMEHEADERS    1100
#define MAIL_IMAPFLAGS      1101

#define MESSAGEBOARD_ARCHIVE "messageboard_archive"

#define CONTROL_ATTR_USER     1
#define CONTROL_ATTR_CLIENT   2
#define CONTROL_ATTR_SERVER   3

#define DRAWING_LINE          1
#define DRAWING_RECTANGLE     2
#define DRAWING_TRIANGLE      3
#define DRAWING_POLYGON       4
#define DRAWING_CONNECTOR     5
#define DRAWING_CIRCLE        6
#define DRAWING_TEXT          7




#define REGISTERED_TYPE        0
#define REGISTERED_DESC        1
#define REGISTERED_EVENT_READ  2
#define REGISTERED_EVENT_WRITE 3
#define REGISTERED_ACQUIRE     4
#define REGISTERED_CONTROL     5
#define REGISTERED_DEFAULT     6

#define REG_ACQ_ENVIRONMENT   1
#define CLASS_ANY             0 // for packages and registering attributes

#endif

