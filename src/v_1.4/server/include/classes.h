#ifndef _CLASSES_H
#define _CLASSES_H

#include "config.h"

#define CLASS_USER CLASS_PATH + "user.pike"

#define CLASS_PATH "/classes/"

#define CLASS_NAME_USER "User"
#define CLASS_NAME_OBJECT "Object"
#define CLASS_NAME_CONTAINER "Container"
#define CLASS_NAME_ROOM "Room"
#define CLASS_NAME_GROUP "Group"
#define CLASS_NAME_DOCUMENT "Document"
#define CLASS_NAME_LINK "Link"
#define CLASS_NAME_DOCHTML "DocHTML"
#define CLASS_NAME_DOCWIKI "DocWiki"
#define CLASS_NAME_DOCLPC "DocLPC"
#define CLASS_NAME_EXIT    "Exit"
#define CLASS_NAME_DOCEXTERN "DocExtern"
#define CLASS_NAME_ANNOTATION "Annotation"
#define CLASS_NAME_DRAWING "Drawing"
#define CLASS_NAME_GHOST   "Ghost"
#define CLASS_NAME_TRASHBIN "TrashBin"
#define CLASS_NAME_LAB "Laboratory"
#define CLASS_NAME_BUG "Bug"

#define CLASS_OBJECT        (1<<0)
#define CLASS_CONTAINER     (1<<1)
#define CLASS_ROOM          (1<<2)
#define CLASS_USER          (1<<3)
#define CLASS_DOCUMENT      (1<<4)
#define CLASS_LINK          (1<<5)
#define CLASS_GROUP         (1<<6)
#define CLASS_EXIT          (1<<7)
#define CLASS_DOCEXTERN     (1<<8)
#define CLASS_DOCLPC        (1<<9)
#define CLASS_SCRIPT        (1<<10)
#define CLASS_DOCHTML       (1<<11)
#define CLASS_ANNOTATION    (1<<12)
#define CLASS_FACTORY       (1<<13)
#define CLASS_MODULE        (1<<14)
#define CLASS_DATABASE      (1<<15)
#define CLASS_PACKAGE       (1<<16)
#define CLASS_IMAGE         (1<<17)
#define CLASS_MESSAGEBOARD  (1<<18)
#define CLASS_GHOST         (1<<19)
#define CLASS_MP3           (1<<20)
#define CLASS_TRASHBIN      (1<<21)
#define CLASS_DOCXML        (1<<22)
#define CLASS_DOCXSL        (1<<23)
#define CLASS_LAB           (1<<24)
#define CLASS_DOCWIKI       (1<<25)
#define CLASS_BUG           (1<<26)

#define CLASS_SERVER        0x00000000
#define CLASS_LOCAL         0x10000000
#define CLASS_DRAWING       0x20000000
#define CLASS_USERDEF       0x30000000

#endif
