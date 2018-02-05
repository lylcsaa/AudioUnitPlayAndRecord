#include "opus_thread.h"




/* mutex */
opus_int32_t        opus_mutex_init(opus_mutex_t    *m)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_mutex_init(&m->mutex, NULL)) != 0)
        ret = -OPUS_THREAD_MUTEX_INIT_ERROR;
    
    return ret;
}


opus_int32_t        opus_mutex_destroy(opus_mutex_t    *m)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_mutex_destroy(&m->mutex)) != 0)
        ret = -OPUS_MUTEX_DESTROY_ERROR;
    
    return ret;
}



opus_int32_t        opus_mutex_lock(opus_mutex_t    *m)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_mutex_lock(&m->mutex)) != 0)
        ret = -OPUS_THREAD_MUTEX_LOCK_ERROR;
    
    return ret;
}



opus_int32_t        opus_mutex_unlock(opus_mutex_t    *m)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_mutex_unlock(&m->mutex)) != 0)
        ret = -OPUS_THREAD_MUTEX_UNLOCK_ERROR;
    
    return ret;
}






/* cond */
opus_int32_t        opus_cond_init(opus_cond_t    *c)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_cond_init(&c->cond, NULL)) != 0)
        ret = -OPUS_THREAD_COND_INIT_ERROR;
    
    return ret;
}



opus_int32_t        opus_cond_destroy(opus_cond_t    *c)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_cond_destroy(&c->cond)) != 0)
        ret = -OPUS_COND_DESTROY_ERROR;
    
    return ret;
}



opus_int32_t        opus_cond_signal(opus_cond_t *c)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    
    if((ret = pthread_cond_signal(&c->cond)) != 0)
        ret = -OPUS_COND_SIGNAL_ERROR;
    
    return ret;
}




opus_int32_t        opus_cond_wait(opus_cond_t    *c,opus_mutex_t *m)
{
    opus_int32_t        ret = OPUS_OPER_OK;
    
    if((ret = pthread_cond_wait(&c->cond, &m->mutex)) != 0)
        ret = -OPUS_COND_WAIT_ERROR;
    
    return ret;
}
