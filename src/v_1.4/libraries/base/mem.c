#include <stdio.h>

#ifndef NOLIB
#include <global.h>
#include <stralloc.h>
#include <interpret.h>
#include <svalue.h>
#include <machine.h>
#include <module_support.h>
#include <backend.h>
#endif
#ifndef DEBUG_MALLOC
#define _MALLOC malloc
#define _FREE   free
#define _IDX(a,i) ( a[i] )
#else
#define _MALLOC alloc_memory
#define _FREE   free_memory
#define _IDX(a,i) ( idx(a,i) )
#endif

struct MemBlock {
    struct MemBlock* next;
    void*            addr;
    void*            copy;
    int              size;
};

struct MemBlock* memory = NULL;
struct MemBlock* memCurrent = NULL;

void assert(int cond, char* out)
{
    if ( !cond ) {
	char* x = NULL;
	*x;
    }
}

void* alloc_memory(int sz)
{
    void*                       res;
    struct MemBlock* block = memory;

    res = (void*)malloc(sz);

    block = (struct MemBlock*)malloc(sizeof(struct MemBlock));
    block->next = NULL;
    block->size = sz;
    block->addr  = res;
    block->copy = NULL;
    if ( memCurrent != NULL )
	memCurrent->next = block;
    else
	memory = block;

    memCurrent = block;
    return res;
}

struct MemBlock* get_memblock(void* addr)
{
    struct MemBlock* block = memory;
    
    while ( block->addr != addr && block->next != NULL ) 
	block = block->next;
    return block;
}

char idx(char* addr, int i)
{
    struct MemBlock* block = memory;
    
    while ( block->addr != addr && block->next != NULL ) 
	block = block->next;
    
    assert(block->addr == addr, "No memory allocated for pointer !");
    assert(i >= 0 && i < block->size, "Adress out of bounds !");
    return (char)(addr[i]);
}

void free_memory(void* buf)
{
    struct MemBlock* block = memory;
    struct MemBlock* prev  = NULL;

    while ( block->addr != buf && block->next != NULL ) {
	prev = block; 
	assert(prev->addr != NULL, "NULL Adress found !");
	block = block->next;
    }
    
    assert(block->addr == buf, "Failed to free memory !");
    if ( block->next == NULL ) {
	if ( prev != NULL ) prev->next = NULL;
	memCurrent = prev;
	free(block);
    }
    else {
	if ( prev != NULL ) prev->next = block->next;
	if ( block == memory ) memory = block->next;
	free(block);
    }
    free(buf);
}

void
describe_leaks()
{
    struct MemBlock* block = memory;
    
    while ( block != NULL ) {
	fprintf(stderr, "Memory block at %x Size=%d!\n", &block, block->size);
	if ( block->copy != NULL )
	    fprintf(stderr,"Block: %s\n", block->copy);
	block = block->next;
    }
}
char*
create_string(char* str, char* src, int len)
{
    struct MemBlock* block;

    if  ( len <= 0 ) len = 1;

    if ( str != NULL )
	_FREE(str);

    str = (char*)_MALLOC(len);
    strncpy(str, src, len - 1);
    str[len-1] = '\0';
    

    /*fprintf(stderr, "Created String: %s\n", str);*/
    return str;
}

char* 
create_string_strip_spaces(char* str, char* src, int len)
{
    char* rsrc;
    int   i, j;

    i = 0;
    while ( i < len && src[i] == ' ' ) i++;
    j = len-1;
    while ( j > 0 && src[j] == ' ' ) j--;

    return create_string(str, &src[i], (len-i)-(len-j)+1);
}

char*
create_string_append(char* str, char* src, int len)
{
    struct MemBlock* block;
    int               olen;
    char*             nstr;

    if ( str == NULL )
	return create_string(str, src, len);

    olen = strlen(str);
    nstr = (char*)_MALLOC(len + olen + 2);
    strncpy(nstr, src, olen);
    nstr[olen] = '\0';
    strncpy(&nstr[olen+1], src, len);
    nstr[len+olen+1] = '\0';
    _FREE(str);
    return nstr;
}
