#ifndef __CBUF_H__
#define __CBUF_H__

#ifdef __cplusplus
extern "C" {
#endif
    
    /* Define to prevent recursive inclusion
     -------------------------------------*/
#include "opus_thread.h"
    typedef    struct _opus_cbuf
    {
        opus_int32_t        size;            /* 当前缓冲区中存放的数据的个数 */
        opus_int32_t        next_in;        /* 缓冲区中下一个保存数据的位置 */
        opus_int32_t        next_out;        /* 从缓冲区中取出下一个数据的位置 */
        opus_int32_t        capacity;        /* 这个缓冲区的可保存的数据的总个数 */
        opus_mutex_t        mutex;            /* Lock the structure */
        opus_cond_t         not_full;        /* Full -> not full condition */
        opus_cond_t         not_empty;        /* Empty -> not empty condition */
        uint8_t        data[OPUS_CBUF_MAX];/* 缓冲区中保存的数据指针 */
    }opus_codec_buf;
    
    
    /* 初始化环形缓冲区 */
    extern    opus_int32_t        opus_cbuf_init(opus_codec_buf *c);
    
    /* 销毁环形缓冲区 */
    extern    void           opus_cbuf_destroy(opus_codec_buf *c);
    
    /* 压入数据 */
    extern    opus_int32_t        opus_cbuf_enqueue(opus_codec_buf *c, uint8_t *data, uint32_t lenth);
    
    /* 取出数据 */
    extern    opus_int32_t       opus_cbuf_dequeue(opus_codec_buf *c,uint8_t*data, uint32_t length);
    
    
    /* 判断缓冲区是否为满 */
    extern    bool           opus_cbuf_full(opus_codec_buf    *c);
    
    /* 判断缓冲区是否为空 */
    extern    bool           opus_cbuf_empty(opus_codec_buf *c);
    
    /* 获取缓冲区可存放的元素的总个数 */
    extern    opus_int32_t        opus_cbuf_capacity(opus_codec_buf *c);
    
    
#ifdef __cplusplus
}
#endif

#endif
/* END OF FILE 
 ---------------------------------------------------------------*/
