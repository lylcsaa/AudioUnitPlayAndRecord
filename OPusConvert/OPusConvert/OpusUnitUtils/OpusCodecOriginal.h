//
//  OpusCodec.h
//  Opus
//
//  Created by smn on 2018/1/22.
//  Copyright © 2018年 smn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpusCodecOriginal : NSObject

-(void)opusInit;

-(NSData*)encodePCMData:(NSData*)data;

-(NSData*)decodeOpusData:(NSData*)data;

- (NSData *)encode:(short *)pcmBuffer;

- (NSData *)encodeBuffer:(short [])pcmBuffer;

-(void)destroy;

- (void)opusInitWithSampleRate:(int)sampleRate channel:(int)channels bitRate:(int)bitRate;

- (void)opusDecodeInitWithSampleRate:(int)sampleRate channel:(int)channels bitRate:(int)bitRate;
-(void)destroyDecode;// added by smn,2018-2-2 解码器的释放

-(void)destroyEncode;
@end
