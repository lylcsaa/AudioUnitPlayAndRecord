#ifndef __THREAD_H__
#define __THREAD_H__

#ifdef __cplusplus
extern "C" {
#endif
    
    /* Define to prevent recursive inclusion
     -------------------------------------*/
#include "opus_types.h"
#include <pthread.h>
    
    
    
    
    typedef    struct _opus_mutex
    {
        pthread_mutex_t        mutex;
    }opus_mutex_t;
    
    
    typedef    struct _opus_cond
    {
        pthread_cond_t        cond;
    }opus_cond_t;
    
    
    typedef    pthread_t        opus_tid_t;
    typedef    pthread_attr_t    opus_attr_t;
    typedef    void*    (* opus_thread_fun_t)(void*);
    
    
    typedef    struct _opus_thread
    {
        opus_tid_t            tid;
        opus_cond_t            *cv;
        opus_int32_t            state;
        opus_int32_t            stack_size;
        opus_attr_t         attr;
        opus_thread_fun_t    fun;
    }opus_thread_t;
    
    
    
    /* mutex */
    extern    opus_int32_t        opus_mutex_init(opus_mutex_t    *m);
    extern    opus_int32_t        opus_mutex_destroy(opus_mutex_t    *m);
    extern    opus_int32_t        opus_mutex_lock(opus_mutex_t    *m);
    extern    opus_int32_t        opus_mutex_unlock(opus_mutex_t    *m);
    
    
    /* cond */
    extern    opus_int32_t        opus_cond_init(opus_cond_t    *c);
    extern    opus_int32_t        opus_cond_destroy(opus_cond_t    *c);
    extern    opus_int32_t        opus_cond_signal(opus_cond_t *c);
    extern    opus_int32_t        opus_cond_wait(opus_cond_t    *c,opus_mutex_t *m);
    
    
    
    /* thread */
    /* 线程的创建，其属性的设置等都封装在里面 */
//    extern    int32_t        thread_create(thread_t *t);
//    extern    int32_t        thread_init(thread_t    *t);
    
#define    thread_join(t, p)     pthread_join(t, p)
#define    thread_self()         pthread_self()
#define    thread_sigmask        pthread_sigmask
    
    
#ifdef __cplusplus
}
#endif

#endif
/* END OF FILE 
 ---------------------------------------------------------------*/
