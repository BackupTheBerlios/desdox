#ifndef EXCEPTION_H
#define EXCEPTION_H
#define E_ERROR    (1<<0 ) // an error has occured
#define E_LOCAL    (1<<1 ) // local exception, user defined
#define E_MEMORY   (1<<2 )  // some memory messed up, uninitialized mapping,etc
#define E_EVENT    (1<<3 ) // some exception on an event
#define E_ACCESS   (1<<4 )
#define E_PASSWORD (1<<5 )
#define E_NOTEXIST (1<<6 )
#define E_FUNCTION (1<<7 )
#define E_FORMAT   (1<<8 )
#define E_OBJECT   (1<<9 )
#define E_TYPE     (1<<10 )
#define E_MOVE     (1<<11 )
#define E_LOOP     (1<<12 )
#define E_LOCK     (1<<13)
#define E_QUOTA    (1<<14)
#define E_TIMEOUT  (1<<15)
#define E_CONNECT  (1<<16)
#define E_UPLOAD   (1<<17)
#define E_DOWNLOAD (1<<18)
#endif
