#ifndef _ACCESS_H
#define _ACCESS_H

#define ACCESS_READ(o1,o2) (_Security->AccessReadObj(o1, o2))
#define ACCESS_WRITE(o1, o2) (_Security->AccessWriteObj(o1, o2))

#define FAIL           -1
#define ACCESS_DENIED   0
#define ACCESS_GRANTED  1
#define ACCESS_BLOCKED  2

#define SANCTION_READ          1
#define SANCTION_EXECUTE       2
#define SANCTION_MOVE          4
#define SANCTION_WRITE         8
#define SANCTION_INSERT       16
#define SANCTION_ANNOTATE     32

#define SANCTION_SANCTION    (1<<8)
#define SANCTION_LOCAL       (1<<9)
#define SANCTION_ALL         (1<<15)-1
#define SANCTION_SHIFT_DENY   16
#define SANCTION_COMPLETE    (0xffffffff)
#define SANCTION_POSITIVE    (0xffff0000)
#define SANCTION_NEGATIVE    (0x0000ffff)

#define SANCTION_READ_ROLE (SANCTION_READ|SANCTION_EXECUTE|SANCTION_ANNOTATE)

#endif
