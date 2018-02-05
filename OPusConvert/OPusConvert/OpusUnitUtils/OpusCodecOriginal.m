//
//  OpusCodec.m
//  Opus
//
//  Created by smn on 2018/1/22.
//  Copyright © 2018年 smn. All rights reserved.
//

#import "OpusCodecOriginal.h"

#import "opus.h"

#define kDefaultSampleRate 16000

#define WB_FRAME_SIZE  320

#define MAX_SIZE 4000

@implementation OpusCodecOriginal
{
    OpusEncoder *enc;
    
    OpusDecoder *dec;
    
    unsigned char opus_data_encoder[MAX_SIZE];
    
    NSFileHandle *fileHandle;
    
    int wb_frame_size;
}

- (void)opusInitWithSampleRate:(int)sampleRate channel:(int)channels bitRate:(int)bitRate {
    int error;
    
    enc = opus_encoder_create(sampleRate, channels, OPUS_APPLICATION_VOIP, &error);//(采样率，声道数,,)
    
    opus_encoder_ctl(enc, OPUS_SET_BITRATE(bitRate));//比特率
    
    opus_encoder_ctl(enc, OPUS_SET_BANDWIDTH(OPUS_AUTO));//OPUS_BANDWIDTH_NARROWBAND 宽带窄带
    
    opus_encoder_ctl(enc, OPUS_SET_VBR(0));
    
    opus_encoder_ctl(enc, OPUS_SET_VBR_CONSTRAINT(1));
    
    opus_encoder_ctl(enc, OPUS_SET_COMPLEXITY(8));//录制质量 1-10
    
    opus_encoder_ctl(enc, OPUS_SET_PACKET_LOSS_PERC(0));
    
    opus_encoder_ctl(enc, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));//信号
}

- (void)opusDecodeInitWithSampleRate:(int)sampleRate channel:(int)channels bitRate:(int)bitRate{
    int error;
    
    dec = opus_decoder_create(sampleRate, channels, &error);
}

- (void)opusInit
{
    int error;
    
    enc = opus_encoder_create(kDefaultSampleRate, 1, OPUS_APPLICATION_VOIP, &error);//(采样率，声道数,,)
    
    dec = opus_decoder_create(kDefaultSampleRate, 1, &error);
    
    opus_encoder_ctl(enc, OPUS_SET_BITRATE(kDefaultSampleRate));//比特率
    
    opus_encoder_ctl(enc, OPUS_SET_BANDWIDTH(OPUS_AUTO));//OPUS_BANDWIDTH_NARROWBAND 宽带窄带
    
    opus_encoder_ctl(enc, OPUS_SET_VBR(0));
    
    opus_encoder_ctl(enc, OPUS_SET_VBR_CONSTRAINT(1));
    
    opus_encoder_ctl(enc, OPUS_SET_COMPLEXITY(8));//录制质量 1-10
    
    opus_encoder_ctl(enc, OPUS_SET_PACKET_LOSS_PERC(0));
    
    opus_encoder_ctl(enc, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));//信号
}

- (NSData *)encodeBuffer:(short [])pcmBuffer{
    
    int frame_size = WB_FRAME_SIZE;
    
//    short input_frame[frame_size];
    
    opus_int32 max_data_bytes = MAX_SIZE ;//随便设大,此时为原始PCM大小
    
//    memcpy(input_frame, pcmBuffer, frame_size * sizeof(short));//frame_size * sizeof(short)
    
    int encodeBack = opus_encode(enc, pcmBuffer, frame_size, opus_data_encoder, max_data_bytes);
    
    NSLog(@"encodeBack===%d",encodeBack);
    
    if (encodeBack > 0)
    {
        NSData *ecodedData = [NSData dataWithBytes:opus_data_encoder length:encodeBack];
        return ecodedData;
    }
    
    else
        
    {
        return nil;
    }
}

- (NSData *)encode:(short *)pcmBuffer
{
//    NSLog(@"--->>lengthOfShorts = %ld  size = %lu",(long)lengthOfShorts,sizeof(short));
    
    int frame_size = WB_FRAME_SIZE;
    
    short input_frame[frame_size];
    
    opus_int32 max_data_bytes = MAX_SIZE ;//随便设大,此时为原始PCM大小
    
    memcpy(input_frame, pcmBuffer, frame_size * sizeof(short));//frame_size * sizeof(short)
    
    int encodeBack = opus_encode(enc, input_frame, frame_size, opus_data_encoder, max_data_bytes);
    
    NSLog(@"encodeBack===%d",encodeBack);
    
    if (encodeBack > 0)
    {
        NSData *ecodedData = [NSData dataWithBytes:opus_data_encoder length:encodeBack];
        return ecodedData;
    }
    
    else
        
    {
        return nil;
    }
}

//int decode(unsigned char* in_data, int len, short* out_data, int* out_len) {

- (NSData *)encodePCMData:(NSData*)data
{
    NSLog(@"原始数据长度--->>%lu",(unsigned long)data.length);
    return  [self encode:(short *)[data bytes]];
}

- (NSData *)decodeOpusData:(NSData*)data
{
    int len = (int)[data length];
    
    Byte *byteData = (Byte*)malloc(len);
    
    memcpy(byteData, [data bytes], len);
    
    int frame_size = MAX_SIZE;
    
    short decodedBuffer[frame_size ];
    
    int nDecodedByte = sizeof(short) * [self decode:byteData length:len output:decodedBuffer];
//    int nDecodedByte = [self decode:byteData length:len output:decodedBuffer];
    
    NSData *PCMData = [NSData dataWithBytes:(Byte *)decodedBuffer length:nDecodedByte];
//    [self wirtePCMDataWithFileHandle:PCMData];
    return PCMData;
}

- (int)decode:(unsigned char *)encodedBytes length:(int)lengthOfBytes output:(short *)decoded

{
    
//    int frame_size = WB_FRAME_SIZE;
    
    unsigned char cbits[MAX_SIZE];
    
    memcpy(cbits, encodedBytes, lengthOfBytes);
    
    int pcm_num = opus_decode(dec, cbits, lengthOfBytes, decoded, MAX_SIZE, 0);
    
    NSLog(@"解压后长度=%d",pcm_num);
    
    return pcm_num;
    
}
// added by smn,2018-2-2 解码器的释放
-(void)destroyDecode
{
    if (!dec) {
        opus_decoder_destroy(dec);
    }
   }
-(void)destroyEncode{
    if (enc) {
        opus_encoder_destroy(enc);
    }
}

-(void)destroy
{
    opus_encoder_destroy(enc);
    opus_decoder_destroy(dec);
}

- (void)wirtePCMDataWithFileHandle:(NSData *)data{
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/file.pcm"];
    fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:data];
}

@end
