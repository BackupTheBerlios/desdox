/*
 * $Id: md5.h,v 1.1 2002/06/05 08:23:12 astra Exp $
 */

#include "crypto_types.h"

#define MD5_DATASIZE    64
#define MD5_DATALEN     16
#define MD5_DIGESTSIZE  16
#define MD5_DIGESTLEN    4

struct md5_ctx {
  unsigned INT32 digest[MD5_DIGESTLEN]; /* Digest */
  unsigned INT32 count_l, count_h;      /* Block count */
  unsigned INT8 block[MD5_DATASIZE];   /* One block buffer */
  int index;                            /* index into buffer */
};

void md5_init(struct md5_ctx *ctx);
void md5_update(struct md5_ctx *ctx, unsigned INT8 *buffer, unsigned INT32 len);
void md5_final(struct md5_ctx *ctx);
void md5_digest(struct md5_ctx *ctx, INT8 *s);
void md5_copy(struct md5_ctx *dest, struct md5_ctx *src);
