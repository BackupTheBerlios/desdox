#ifndef _FUNC_H
#define _FUNC_H

#include <coal.h>

#define _FUNC_NUMPARAMS   0
#define _FUNC_SYNOPSIS    1
#define _FUNC_KEYWORDS    2
#define _FUNC_DESCRIPTION 3
#define _FUNC_PARAMS      4
#define _FUNC_ARGS        5

#define PARAM_INT (1<<CMD_TYPE_INT)
#define PARAM_FLOAT (1<<CMD_TYPE_FLOAT)
#define PARAM_STRING (1<<CMD_TYPE_STRING)
#define PARAM_OBJECT (1<<CMD_TYPE_OBJECT)
#define PARAM_ARRAY  (1<<CMD_TYPE_ARRAY)
#define PARAM_MAPPING (1<<CMD_TYPE_MAPPING)

#endif




