#ifndef TYPES_H
#define TYPES_H

#include <stdbool.h>
/*
typedef unsigned char           byte;
typedef unsigned short          word;
typedef unsigned int            dword;
typedef int                     bool;
typedef signed char             int8_t;
typedef unsigned char           uint8_t;
typedef signed short int        int16_t;
typedef unsigned short int      uint16_t;
*/
typedef signed int              opus_int32_t;
/*
typedef unsigned int            uint32_t;
typedef unsigned long long      uint64_t;
typedef long long               int64_t;
typedef int8_t                  int8;
typedef uint8_t                 uint8;
typedef int16_t                 int16;
typedef uint16_t                uint16;
typedef int32_t                 int32;
typedef uint32_t                uint32;
typedef int64_t                 int64;
typedef uint64_t                uint64;
typedef unsigned char           uchar_t;
typedef uint32_t                wchar_t;
typedef uint32_t                size_t;
typedef uint32_t                addr_t;
typedef int32_t                 pid_t;
*/
#define OPUS_INBUFSZIE 640
#define OPUS_CBUF_MAX  OPUS_INBUFSZIE*10

//#define USE_XT_MEM_POOL 1

enum{
OPUS_OPER_OK,
OPUS_OPER_ERR,
OPUS_THREAD_MUTEX_INIT_ERROR,
OPUS_MUTEX_DESTROY_ERROR,
OPUS_THREAD_MUTEX_LOCK_ERROR,
OPUS_THREAD_MUTEX_UNLOCK_ERROR,
OPUS_THREAD_COND_INIT_ERROR,
OPUS_COND_DESTROY_ERROR,
OPUS_COND_SIGNAL_ERROR,
OPUS_COND_WAIT_ERROR,
OPUS_OPER_NO_DATA
};
enum{
    OPUS_READ_NULL = -1,
    OPUS_READ_SUCCESS
};

#endif


