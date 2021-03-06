/* $Id: crypto_types.h,v 1.1 2002/06/05 08:23:12 astra Exp $
 *
 * Defines the types INT32 and INT8 */

#ifndef CRYPTO_TYPES_H_INCLUDED
#define CRYPTO_TYPES_H_INCLUDED

#ifdef PIKE
#include "pike_types.h"
#include "global.h"
#else /* !PIKE */
#define INT32 long
#define INT16 short
#define INT8 char
#endif

#endif /* CRYPTO_TYPES_H_INCLUDED */
