#include "opus_codec_buf.h"
#include <string.h>


/* 初始化环形缓冲区 */
opus_int32_t        opus_cbuf_init(opus_codec_buf *c)
{
    opus_int32_t    ret = OPUS_OPER_OK;
    
    if((ret = opus_mutex_init(&c->mutex)) != OPUS_OPER_OK)
    {
#ifdef DEBUG_CBUF
        debug("cbuf init fail ! mutex init fail !\n");
#endif
        return ret;
    }
    
    if((ret = opus_cond_init(&c->not_full)) != OPUS_OPER_OK)
    {
#ifdef DEBUG_CBUF
        debug("cbuf init fail ! cond not full init fail !\n");
#endif
        opus_mutex_destroy(&c->mutex);
        return ret;
    }
    
    if((ret = opus_cond_init(&c->not_empty)) != OPUS_OPER_OK)
    {
#ifdef DEBUG_CBUF
        debug("cbuf init fail ! cond not empty init fail !\n");
#endif
        opus_cond_destroy(&c->not_full);
        opus_mutex_destroy(&c->mutex);
        return ret;
    }
    
    c->size     = 0;
    c->next_in    = 0;
    c->next_out = 0;
    c->capacity    = OPUS_CBUF_MAX;
    
#ifdef DEBUG_CBUF
    debug("cbuf init success !\n");
#endif
    
    return ret;
}


/* 销毁环形缓冲区 */
void        opus_cbuf_destroy(opus_codec_buf    *c)
{
    opus_cond_destroy(&c->not_empty);
    opus_cond_destroy(&c->not_full);
    opus_mutex_destroy(&c->mutex);
    
#ifdef DEBUG_CBUF
    debug("cbuf destroy success \n");
#endif
}



/* 压入数据 */
opus_int32_t        opus_cbuf_enqueue(opus_codec_buf *c, uint8_t *data, uint32_t length)
{
    opus_int32_t    ret = OPUS_OPER_OK;
    
    if((ret = opus_mutex_lock(&c->mutex)) != OPUS_OPER_OK)    return ret;
    while (opus_cbuf_full(c)) {
        opus_cond_wait(&c->not_full,&c->mutex);
    }
    memcpy(c->data+c->next_in ,data,OPUS_INBUFSZIE);
    c->size += OPUS_INBUFSZIE;
    c->next_in += length;
    c->next_in %= c->capacity;
    opus_mutex_unlock(&c->mutex);

    
#ifdef DEBUG_CBUF
    //    debug("cbuf enqueue success ,data : %p\n",data);
    debug("enqueue\n");
#endif
    
    return ret;
}



/* 取出数据 */
opus_int32_t     opus_cbuf_dequeue(opus_codec_buf *c,uint8_t*data, uint32_t length)
{
    opus_int32_t    ret     = OPUS_OPER_OK;
    
    if((ret = opus_mutex_lock(&c->mutex)) != OPUS_OPER_OK)    return ret;
    
  
    if (length > c->size) {
        ret =  OPUS_READ_NULL;
    }else{
        if (c->next_out + length > c->capacity) {
            memcpy(data, c->data + c->next_out, c->capacity - c->next_out);
            memcpy(data + c->capacity - c->next_out, c->data + c->next_out, length - (c->capacity - c->next_out));
            c->next_out = length - (c->capacity - c->next_out);
            c->size -= length;
        }else{
            memcpy(data, c->data + c->next_out, length);
            c->next_out += length;
            c->size -= length;
        }
        c->next_out %= c->capacity;
        opus_cond_signal(&c->not_full);
    }
    opus_mutex_unlock(&c->mutex);
    /*
     * Let a waiting producer know there is room.
     * 取出了一个元素，又有空间来保存接下来需要存储的元素
     */
//    cond_signal(&c->not_full);
    
#ifdef DEBUG_CBUF
    //    debug("cbuf dequeue success ,data : %p\n",data);
    debug("dequeue\n");
#endif
    
    return ret;
}


/* 判断缓冲区是否为满 */
bool        opus_cbuf_full(opus_codec_buf    *c)
{
    return (c->capacity - c->size < OPUS_INBUFSZIE);
}

/* 判断缓冲区是否为空 */
bool        opus_cbuf_empty(opus_codec_buf *c)
{
    return (c->size == 0);
}

/* 获取缓冲区可存放的元素的总个数 */
opus_int32_t        opus_cbuf_capacity(opus_codec_buf *c)
{
    return c->capacity;
}
