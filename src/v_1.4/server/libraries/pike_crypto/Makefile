CC=gcc

OBJS=md5.o crypt_md5.o md5_pike.o
SOURCES=md5.c crypt_md5.c md5_pike.c

CFLAGS=-I$(PIKE_INCLUDE_PREFIX)
INSTALL=install -c
DEST=../crypto.pmod.so

all: crypto.so


.SUFFIXES: .c .o

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

crypto.so: $(OBJS)
	$(LD) -E -shared -o crypto.so $(OBJS) -L..

clean:
	rm -f *.o *~ crypto.so

install: 
	$(INSTALL) crypto.so $(DEST)


