//
//  XTAudioUnitManager.h
//  Xtvf2Demo
//
//  Created by wlx on 2017/10/28.
//  Copyright © 2017年 Chengyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "XTAudioParamsHeader.h"
@class XTAudioUnitManager;
typedef void(^AudioInputCallback)(const SInt16 *    src,
                                  int                stride,
                                  int                 inFramesToProcess);
typedef void(^AudioOutputCallback)(const SInt16 *    src,
                                   int                stride,
                                   int                 inFramesToProcess);
typedef void(^AudioUnitRunningCallback) (BOOL isRunning);
@protocol XTAudioUnitManagerOutputDelegate <NSObject>
-(void)audioUnitManager:(XTAudioUnitManager*)audioUnitManager outputAudioData:(NSData*)audioData;
@end
@interface XTAudioUnitManager : NSObject

@property (nonatomic,weak)id<XTAudioUnitManagerOutputDelegate> outputDelegate;
@property (nonatomic,assign) BOOL isLive;

@property (nonatomic,copy)AudioInputCallback inputBack;
@property (nonatomic,copy)AudioOutputCallback outputBack;
@property (nonatomic,copy)AudioUnitRunningCallback runningBlock;
@property (nonatomic,copy)AudioUnitRunningCallback runningBlock2;
@property (nonatomic,assign)AudioStreamBasicDescription canonicalAsbd;
+(instancetype)shareManager;


#pragma mark 注释<--  控制播放和录制的方法 -->
-(BOOL)setAudioWithAudioFormat:(AudioStreamBasicDescription)audioFomat;
-(BOOL)setOpusCodecWithSampleRate:(int)sampleRate channels:(int)channels bitRate:(int)bitRate;
-(void)feedVoiceData:(NSData*)data;
-(BOOL)recorderAudio;
-(BOOL)recorderOpusAudio;
-(BOOL)stopRecord;
-(BOOL)stopPlay;
-(BOOL)stopAudioService;
-(void)cleanAudioDatas;
@end
