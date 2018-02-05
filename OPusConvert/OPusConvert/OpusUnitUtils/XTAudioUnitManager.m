//
//  XTAudioUnitManager.m
//  Xtvf2Demo
//
//  Created by wlx on 2017/10/28.
//  Copyright © 2017年 Chengyin. All rights reserved.
//

#import "XTAudioUnitManager.h"
#import <AVFoundation/AVFoundation.h>
#include "opus_codec_buf.h"
#import "OpusCodecOriginal.h"
// Audio Unit Set Property
typedef NS_ENUM(NSInteger,XTAudioCodecType) {
    XTAudioCodecTypeAAC,
    XTAudioCodecTypeOpus
};
#define INPUT_BUS  1      ///< A I/O unit's bus 1 connects to input hardware (microphone).
#define OUTPUT_BUS 0      ///< A I/O unit's bus 0 connects to output hardware (speaker).
#define DEFAULT_PACKET_BUFFER_SIZE 2048
#define OS_STATUS_DONE 'done'
NSFileHandle *audioFileHandle;
AudioConverterRef               _decodeConvertRef;
AudioConverterRef               _encodeConvertRef;
AudioStreamBasicDescription     _tagertFormat;
static int          pcm_buffer_size = 0;
static uint8_t      pcm_buffer[kTVURecoderPCMMaxBuffSize*2];
static uint8_t      mData[1024];
static uint8_t      outPutmData[1024];
static const int dataSize = 640;
static OSStatus    XTAudioOutputCallBack(void                         *inRefCon,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp          *inTimeStamp,
                                         UInt32                     inBusNumber,
                                         UInt32                      inNumberFrames,
                                         AudioBufferList              *ioData);
static OSStatus    XTAudioInputCallback(void                        *inRefCon,
                                        AudioUnitRenderActionFlags *ioActionFlags,
                                        const AudioTimeStamp         *inTimeStamp,
                                        UInt32                     inBusNumber,
                                        UInt32                     inNumberFrames,
                                        AudioBufferList             *ioData);
static OSStatus XTAudioDecodeConverterCallback(AudioConverterRef inAudioConverter,
                                               UInt32 *ioNumberDataPackets,
                                               AudioBufferList *ioData,
                                               AudioStreamPacketDescription **outDataPacketDescription,
                                               void *inUserData);
OSStatus XTAudioEncodeConvertCallback(AudioConverterRef              inAudioConverter,
                                      UInt32                         *ioNumberDataPackets,
                                      AudioBufferList                *ioData,
                                      AudioStreamPacketDescription   **outDataPacketDescription,
                                      void                           *inUserData);
static BOOL XTGetSoftwareCodecClassDesc(UInt32 formatId, AudioClassDescription* classDesc);
@interface XTAudioUnitManager ()

/**
 @property outputAudioFileType
 @brief the output file type
 Default value is kAudioFileCAFType
 */
@property (nonatomic, assign) AudioFileTypeID outputAudioFileType;

/**
 @property outputAudioFormat
 @brief the output file format
 Default value is kAudioFormatMPEG4AAC
 */
@property (nonatomic, assign) AudioFormatID outputAudioFormat;
//@property (nonatomic, strong)NSFileHandle *audioFileHandle;
/**
 @property outputAudioFormatFlags
 @brief the output file format flags
 Default value is kMPEG4Object_AAC_LC (lossless AAC codec)
 */
@property (nonatomic, assign) AudioFormatFlags outputAudioFormatFlags;


@property (nonatomic ,assign) AudioStreamBasicDescription playFormat;
@property (nonatomic, assign) double packetDuration;
/**
 **:播放的unit
 **/
@property (nonatomic,assign)AudioUnit audioUnit;
@property (nonatomic,assign)AudioUnit mixerUnit;
@property (nonatomic,assign)AUGraph processingGraph;
/**
 **:用于接收音频数据的数组
 **/
@property (nonatomic,strong)  NSMutableArray *packetArray;

@property (nonatomic,strong)OpusCodecOriginal *opusCodec;

@end
@implementation XTAudioUnitManager
{
    BOOL _isRunning;
    BOOL _started;
    XTAudioCodecType _audioCodecType;
    AudioFileStreamID _audioFileStream;    // the audio file stream parser
    //    BOOL _is
    
    
    AudioFileID _destinationAudioFileId;
    UInt32 _destinationFilePacketPosition;
    
    AudioStreamBasicDescription _sourceAsbd;

    NSInteger _readPktIndex;
    BOOL _isRecording;
    BOOL _isPlaying;
    opus_codec_buf _decode_buf;
    BOOL _decode_buf_isinit;
}
-(OpusCodecOriginal *)opusCodec{
    if (!_opusCodec) {
        _opusCodec = [[OpusCodecOriginal alloc] init];
    }
    return _opusCodec;
}
-(void)initDecoderBuf
{
    _decode_buf_isinit = opus_cbuf_init(&_decode_buf) == OPUS_OPER_OK;
}
-(void)destoryDecoderBuf
{
    
    opus_cbuf_destroy(&_decode_buf);
    _decode_buf_isinit = NO;
}

-(BOOL)setOpusCodecWithSampleRate:(int)sampleRate channels:(int)channels bitRate:(int)bitRate
{
    [self.opusCodec opusDecodeInitWithSampleRate:sampleRate channel:channels bitRate:kXDXRecoderConverterEncodeBitRate];
    _audioCodecType = XTAudioCodecTypeOpus;
    if (!_isPlaying) {
        _sourceAsbd = _canonicalAsbd;
        _sourceAsbd.mSampleRate = sampleRate;
        _sourceAsbd.mChannelsPerFrame = channels;
        if (_audioUnit == NULL) {
            [self XTSetUpIOUnit];
        }else{
            AudioComponentInstanceDispose(_audioUnit);
            _audioUnit = nil;
            [self XTSetUpIOUnit];
        }
        [self XTSetUpAudioSession];
        _isPlaying = YES;
    }
    if (self.runningBlock) {
        self.runningBlock(YES);
    }
    if (self.runningBlock2) {
        self.runningBlock2(YES);
    }
    return _isPlaying;
}
-(NSMutableArray *)packetArray
{
    if (!_packetArray) {
        _packetArray = [NSMutableArray array];
    }
    return _packetArray;
}
+(instancetype)shareManager
{
    static XTAudioUnitManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[XTAudioUnitManager alloc] init];
    });
    return mgr;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioCodecType = XTAudioCodecTypeAAC;
        _outputAudioFormat = kAudioFormatMPEG4AAC;
        _outputAudioFormatFlags = kMPEG4Object_AAC_LC;
        _outputAudioFileType = kAudioFileCAFType;
        _readPktIndex = 0;
        
        _isRecording = NO;
        _isPlaying = NO;
        _canonicalAsbd = (AudioStreamBasicDescription)
        {
            .mSampleRate = kXDXAudioSampleRate,
            .mFormatID = kAudioFormatLinearPCM,
            .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            .mFramesPerPacket = 1,
            .mChannelsPerFrame = kXDXRecodermChannelsPerFrame,
            .mBytesPerFrame =  2,
            .mBitsPerChannel = 8 * 2,
            .mBytesPerPacket = 2
        };
        
        [self.opusCodec opusInitWithSampleRate:_canonicalAsbd.mSampleRate channel:_canonicalAsbd.mChannelsPerFrame bitRate:kXDXRecoderConverterEncodeBitRate];
        
        // add AVAudioSession interruption handlers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:[AVAudioSession sharedInstance]];
        
        // we don't do anything special in the route change notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:[AVAudioSession sharedInstance]];
        
        // if media services are reset, we need to rebuild our audio chain
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMediaServicesWereReset:)
                                                     name:AVAudioSessionMediaServicesWereResetNotification
                                                   object:[AVAudioSession sharedInstance]];
    }
    return self;
}
#pragma mark- AVAudioSession Notifications

// we just print out the results for informational purposes
- (void)handleInterruption:(NSNotification *)notification
{
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
//    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        // your audio session is deactivated automatically when your app is interrupted
        // perform any other tasks required to handled being interrupted
        
        if (_isRecording) {
            _isRecording = NO;
        }
    }
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        // make sure to activate the session, it does not get activated for you automatically
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
//        if (nil != error) NSLog(@"AVAudioSession set active failed with error: %@", error);
        
        // perform any other tasks to have the app start up after an interruption
        
        UInt32                        bypassState = 0;

        // Synchronize bypass state
        OSStatus result = AudioUnitSetProperty(_audioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, 1, &bypassState, sizeof(bypassState));
        if (result) NSLog(@"Error setting voice unit bypass: %d\n", (int)result);
        
        AudioOutputUnitStart(_audioUnit);
    }
}
// we just print out the results for informational purposes
- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
//    NSLog(@"Route change:");
    switch (reasonValue) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"     NewDeviceAvailable");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"     OldDeviceUnavailable");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"     CategoryChange");
            NSLog(@" New Category: %@", [[AVAudioSession sharedInstance] category]);
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"     Override");
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"     WakeFromSleep");
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"     NoSuitableRouteForCategory");
            break;
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
            NSLog(@"    RouteConfigurationChange");
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
            NSLog(@"     Reason Unknown");
            break;
        default:
            NSLog(@"     Reason Really Unknown");
            NSLog(@"           Reason Value %d", reasonValue);
    }
    
//    NSLog(@"Previous route:\n");
//    NSLog(@"%@", routeDescription);
////
//    NSLog(@"Current route:\n");
//    NSLog(@"%@", [[AVAudioSession sharedInstance] currentRoute]);
}

// reset the world!
// see https://developer.apple.com/library/content/qa/qa1749/_index.html
- (void)handleMediaServicesWereReset:(NSNotification *)notification
{
//    NSLog(@"Media services have reset - ouch!");
    
//    [self resetIOUnit];
//    [self setupIOUnit];
}
#pragma mark 注释<--  播放目标音频  -->
-(BOOL)setAudioWithAudioFormat:(AudioStreamBasicDescription)audioFomat
{
    if (!_isPlaying) {
        _audioCodecType = XTAudioCodecTypeAAC;
        _sourceAsbd = audioFomat;
        if (_audioUnit == NULL) {
            [self  XTCreatDecoderAudioConvert:&audioFomat];
            [self XTSetUpIOUnit];
//            [self XTSetUpIOUnitByAUGraph];
        }else{
            AudioComponentInstanceDispose(_audioUnit);
            _audioUnit = nil;
            [self  XTCreatDecoderAudioConvert:&audioFomat];
            [self XTSetUpIOUnit];
//            [self XTSetUpIOUnitByAUGraph];
            [self XTCreatEncodeAudioConvert];
        }
        [self XTSetUpAudioSession];
        _isPlaying = YES;
    }
    if (self.runningBlock) {
        self.runningBlock(YES);
    }
    if (self.runningBlock2) {
        self.runningBlock2(YES);
    }
    return _isPlaying;
}
#pragma mark 注释<--  设置开始采集  -->
-(BOOL)recorderOpusAudio{
    _audioCodecType = XTAudioCodecTypeOpus;
    return [self recorderAudio];
}
-(BOOL)recorderAudio
{
    if (!_isRecording) {
        if (_audioUnit == NULL) {
            [self XTSetUpIOUnit];
        }
        [self XTSetUpAudioSession];
        [self initGlobalVar];
        if (_audioCodecType == XTAudioCodecTypeAAC) {
            [self XTCreatEncodeAudioConvert];
        }
        _isRecording = YES;
        if (!_isPlaying && _audioUnit != nil) {
            [self _startUnit];
        }
    }
    if (self.runningBlock) {
        self.runningBlock(YES);
    }
    if (self.runningBlock2) {
        self.runningBlock2(YES);
    }
    return _isRecording;
}
#pragma mark 注释<--  停止录制  -->
-(BOOL)stopRecord
{
    _isRecording = NO;
    _audioCodecType = XTAudioCodecTypeAAC;
    if (!_isPlaying) {
        [self distroyAudioService];
    }
    if (_audioCodecType ==XTAudioCodecTypeOpus) {
        [self.opusCodec destroyEncode];
    }
    if (self.runningBlock) {
        self.runningBlock(NO);
    }
    if (self.runningBlock2) {
        self.runningBlock2(NO);
    }
    return YES;
}
#pragma mark 注释<--  停止播放  -->
-(BOOL)stopPlay
{
    _isPlaying = NO;
    if (!_isRecording) {
        [self distroyAudioService];
        _readPktIndex = 0;
        [self.packetArray removeAllObjects];
    }
    
    if (_audioCodecType ==XTAudioCodecTypeOpus) {
        [self.opusCodec destroyDecode];
    }
    return YES;
}
#pragma mark 注释<--  停止录制和播放，并释放Audio Unit  -->
-(BOOL)stopAudioService
{
     _isRecording = NO;
    _isPlaying = NO;
    AudioOutputUnitStop(_audioUnit);
    [self distroyAudioService];
    if (self.runningBlock) {
        self.runningBlock(NO);
    }
    if (self.runningBlock2) {
        self.runningBlock2(NO);
    }
    return YES;
}
#pragma mark 注释<--  释放AudioUnit, AudioConvert  -->
-(void)dealloc{
    AudioConverterDispose(_decodeConvertRef);
    _decodeConvertRef = NULL;
    AudioConverterDispose(_encodeConvertRef);
    _encodeConvertRef = NULL;
    AudioComponentInstanceDispose(_audioUnit);
    _audioUnit = nil;
}
-(OSStatus)distroyAudioService
{
    if (!_isPlaying) {
        [self destoryDecoderBuf];
    }
    if (!_isPlaying && !_isRecording) {
        [self _stopUnit];
    }
    return noErr;
}
-(void)feedVoiceData:(NSData *)data
{
    if (_audioCodecType == XTAudioCodecTypeOpus) {
        NSData *pcmData = [self.opusCodec decodeOpusData:data];
        if (!_decode_buf_isinit) {
            [self initDecoderBuf];
            [self setOpusCodecWithSampleRate:_canonicalAsbd.mSampleRate channels:_canonicalAsbd.mChannelsPerFrame bitRate:kXDXRecoderConverterEncodeBitRate];
        }
        opus_cbuf_enqueue(&_decode_buf, (uint8_t*)pcmData.bytes, (uint32_t)pcmData.length);
    }else{
        [self.packetArray addObject:data];
    }
    if (_isPlaying) {
        [self _startUnit];
    }
}


#pragma mark- OutpuUnit Input Callback
#pragma mark 注释<--  初始化AudioUnit buffer  -->
- (void)initGlobalVar {
    // 初始化pcm_buffer，pcm_buffer是存储每次捕获的PCM数据，因为PCM若要转成AAC需要攒够2048个字节给转换器才能完成一次转换，Reset pcm_buffer to save convert handle
    memset(pcm_buffer, 0, pcm_buffer_size);
    pcm_buffer_size = 0;
}

-(void)encoderOutPut:(NSData *)encodeData
{
    [self feedVoiceData:encodeData];
//    if (self.outputDelegate && [self.outputDelegate respondsToSelector:@selector(audioUnitManager:outputAudioData:)]) {
//        [self.outputDelegate audioUnitManager:self outputAudioData:aacData];
//    }
}


-(void)XTSetUpAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL success;
    NSError* error;
    success = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    [audioSession setPreferredIOBufferDuration:0.01 error:&error]; // 10ms采集一次
    [audioSession setPreferredSampleRate:_canonicalAsbd.mSampleRate error:&error];  // 需和XDXRecorder中对应
    
    //set USB AUDIO device as high priority: iRig mic HD
    for (AVAudioSessionPortDescription *inputPort in [audioSession availableInputs])
    {
        if([inputPort.portType isEqualToString:AVAudioSessionPortUSBAudio])
        {
            [audioSession setPreferredInput:inputPort error:&error];
            [audioSession setPreferredInputNumberOfChannels:_canonicalAsbd.mChannelsPerFrame error:&error];
            break;
        }
    }
    
    if(!success)
        NSLog(@">>>>>>>AAVAudioSession error setCategory = %@",error.debugDescription);
    success = [audioSession setActive:YES error:&error];
    //Restrore default audio output to BuildinReceiver
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription *portDesc in [currentRoute outputs])
    {
        if([portDesc.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
        {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            break;
        }
    }
}
-(BOOL)XTSetUpIOUnitByAUGraph
{
    // 配置AudioUnit基本信息
    OSStatus result = noErr;
    
    result = NewAUGraph(&_processingGraph);
    
    // Open the output unit
    AudioComponentDescription desc = {
        kAudioUnitType_Output,               // type
        kAudioUnitSubType_VoiceProcessingIO, // subType
        kAudioUnitManufacturer_Apple,        // manufacturer
        0,
        0 };                              // flags
    
    AudioComponentDescription MixerUnitDescription ={
        kAudioUnitType_Mixer,
        kAudioUnitSubType_MultiChannelMixer,
        kAudioUnitManufacturer_Apple,
        0,
        0
    };
    
    AUNode iONode;
    AUNode mixNode;
    
    result = AUGraphAddNode(_processingGraph, &desc, &iONode);
    result = AUGraphAddNode(_processingGraph, &MixerUnitDescription, &mixNode);
    result = AUGraphOpen(_processingGraph);
    result = AUGraphNodeInfo(_processingGraph, mixNode, NULL, &_mixerUnit);
    result = AUGraphNodeInfo(_processingGraph, iONode, NULL, &_audioUnit);
    uint32_t busCount = 2;
    uint32_t guitarBus = 0;
    uint32_t beatsBus = 1;
    result = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
    UInt32 maximumFramesPerSlice = 4096;
    AudioUnitSetProperty (
                          _mixerUnit,
                          kAudioUnitProperty_MaximumFramesPerSlice,
                          kAudioUnitScope_Global,
                          0,
                          &maximumFramesPerSlice,
                          sizeof (maximumFramesPerSlice)
                          );
    
    
    for (int busNumber = 0 ; busNumber < busCount; busNumber++) {
        AURenderCallbackStruct renderProc = { XTAudioOutputCallBack, (__bridge void * _Nullable)(self) };
        result = AUGraphSetNodeInputCallback(_processingGraph, mixNode, busNumber, &renderProc);
    }
    
    AudioUnitSetProperty (
                          _mixerUnit,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Input,
                          guitarBus,
                          &_sourceAsbd,
                          sizeof (_sourceAsbd)
                          );
    AudioUnitSetProperty (
                          _mixerUnit,
                          kAudioUnitProperty_StreamFormat,
                          kAudioUnitScope_Input,
                          beatsBus,
                          &_sourceAsbd,
                          sizeof (_sourceAsbd)
                          );
    Float64 graphSampleRate = 16000.0;
    AudioUnitSetProperty (
                          _mixerUnit,
                          kAudioUnitProperty_SampleRate,
                          kAudioUnitScope_Output,
                          0,
                          &graphSampleRate,
                          sizeof (graphSampleRate));
    UInt32 flag = 1;
  
    AUGraphConnectNodeInput (
                             _processingGraph,
                             mixNode,         // source node
                             0,                 // source node output bus number
                             iONode,            // destination node
                             0                  // desintation node input bus number
                             );
    
    AUGraphInitialize(_processingGraph);
    
    UInt32 one; one = 1;
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
    if (result) {
        printf("couldn't enable input on the audio unit");
        goto end;
    }
//    AURenderCallbackStruct renderProc = { XTAudioOutputCallBack, (__bridge void * _Nullable)(self) };
    AURenderCallbackStruct inputProc = { XTAudioInputCallback, (__bridge void * _Nullable)(self) };
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &inputProc, sizeof(inputProc));
    if (result) {
        printf("couldn't set audio unit input proc");
        goto end;
    }
    
//    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderProc, sizeof(renderProc));
    if (result) {
        printf("couldn't set audio render callback");
        goto end;
    }
    
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_canonicalAsbd, sizeof(_canonicalAsbd));
    if (result) {
        printf("couldn't set the audio unit's output format");
        goto end;
    }
    
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &_canonicalAsbd, sizeof(_canonicalAsbd));
    if (result) {
        printf("couldn't set the audio unit's input client format");
        goto end;
    }
    flag     = 0;
    OSStatus status = AudioUnitSetProperty(_audioUnit,
                                           kAudioUnitProperty_ShouldAllocateBuffer,
                                           kAudioUnitScope_Output,
                                           INPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
        
        NSLog(@">>>>>>>couldn't AllocateBuffer of AudioUnitCallBack, status : %d \n",(int)status);
    }
    result = AudioUnitInitialize(_audioUnit);
    if (result) {
        printf("couldn't initialize the audio unit");
        goto end;
    }
end:
    return result;
}
-(BOOL)XTSetUpIOUnit
{
    
    // 配置AudioUnit基本信息
    OSStatus result = noErr;
    // Open the output unit
    AudioComponentDescription desc = { kAudioUnitType_Output,               // type
        kAudioUnitSubType_VoiceProcessingIO, // subType
        kAudioUnitManufacturer_Apple,        // manufacturer
        0, 0 };                              // flags
    
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    
    result = AudioComponentInstanceNew(comp, &_audioUnit);
    if (result) {
        printf("couldn't open the audio unit: %d", (int)result);
        goto end;
    }
    
    UInt32 one; one = 1;
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
    if (result) {
        printf("couldn't enable input on the audio unit");
        goto end;
    }
    AURenderCallbackStruct renderProc = { XTAudioOutputCallBack, (__bridge void * _Nullable)(self) };
    AURenderCallbackStruct inputProc = { XTAudioInputCallback, (__bridge void * _Nullable)(self) };
    result = AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &inputProc, sizeof(inputProc));
    if (result) {
        printf("couldn't set audio unit input proc");
        goto end;
    }
    
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderProc, sizeof(renderProc));
    if (result) {
        printf("couldn't set audio render callback");
        goto end;
    }
    
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_canonicalAsbd, sizeof(_canonicalAsbd));
    if (result) {
        printf("couldn't set the audio unit's output format");
        goto end;
    }
    
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &_canonicalAsbd, sizeof(_canonicalAsbd));
    if (result) {
        printf("couldn't set the audio unit's input client format");
        goto end;
    }
    UInt32 flag     = 0;
    OSStatus status = AudioUnitSetProperty(_audioUnit,
                                           kAudioUnitProperty_ShouldAllocateBuffer,
                                           kAudioUnitScope_Output,
                                           INPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
       
        NSLog(@">>>>>>>couldn't AllocateBuffer of AudioUnitCallBack, status : %d \n",(int)status);
    }
    result = AudioUnitInitialize(_audioUnit);
    if (result) {
        printf("couldn't initialize the audio unit");
        goto end;
    }
end:
    return result;
}
#pragma mark 注释<--  解码Opus数据  -->
-(OSStatus)decodeOpusDataToPlayWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                        audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                           inBusNumber:(uint32_t)inBusNumber
                        inNumberFrames:(uint32_t)inNumberFrames
                                ioData:(AudioBufferList*)ioData{
    if (!_isPlaying) {
        ioData->mNumberBuffers = 0;
        ioData->mBuffers[0].mNumberChannels = 0;
        ioData->mBuffers[0].mDataByteSize = 0;
        ioData->mBuffers[0].mData = NULL;
        return -1;
    }
    UInt32 packetSize = inNumberFrames;
   
            if (_decode_buf.size > inNumberFrames*2 ) {
                if (packetSize){
                    ioData->mNumberBuffers = 1;
                    ioData->mBuffers[0].mNumberChannels = 1;
                    ioData->mBuffers[0].mDataByteSize = inNumberFrames*2;
                    int ret = opus_cbuf_dequeue(&_decode_buf, ioData->mBuffers[0].mData, inNumberFrames*2);
                    if (ret == OPUS_READ_NULL) {
                        ioData->mNumberBuffers = 0;
                        ioData->mBuffers[0].mNumberChannels = 0;
                        ioData->mBuffers[0].mDataByteSize = 0;
                        ioData->mBuffers[0].mData = NULL;
                        return -1;
                    }
                    if (_outputBack) {
                        _outputBack((SInt16*)ioData->mBuffers[0].mData,1,inNumberFrames);
                    }
                    return noErr;
                }else{
                    ioData->mNumberBuffers = 0;
                    ioData->mBuffers[0].mNumberChannels = 0;
                    ioData->mBuffers[0].mDataByteSize = 0;
                    ioData->mBuffers[0].mData = NULL;
                    return -1;
                }
            }else{
                ioData->mNumberBuffers = 0;
                ioData->mBuffers[0].mNumberChannels = 0;
                ioData->mBuffers[0].mDataByteSize = 0;
                ioData->mBuffers[0].mData = NULL;
                return -1;
            }
    
    return noErr;
    
}
#pragma mark 注释<--  解码AAC数据  -->
-(OSStatus)decodeAACDataToPlayWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                        audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                           inBusNumber:(uint32_t)inBusNumber
                        inNumberFrames:(uint32_t)inNumberFrames
                                 ioData:(AudioBufferList*)ioData
{
    if (!_isPlaying) {
        ioData->mNumberBuffers = 0;
        ioData->mBuffers[0].mNumberChannels = 0;
        ioData->mBuffers[0].mDataByteSize = 0;
        ioData->mBuffers[0].mData = NULL;
        return -1;
    }
    UInt32 packetSize = inNumberFrames;
    if (_packetArray.count > 0) {
        
            AudioBufferList outBufferList;
            outBufferList.mNumberBuffers              = 1;
            outBufferList.mBuffers[0].mNumberChannels = _tagertFormat.mChannelsPerFrame;
            outBufferList.mBuffers[0].mData = outPutmData;
            outBufferList.mBuffers[0].mDataByteSize   = kTVURecoderPCMMaxBuffSize;
            
            OSStatus status = AudioConverterFillComplexBuffer(_decodeConvertRef, XTAudioDecodeConverterCallback, (__bridge void *)[XTAudioUnitManager shareManager], &packetSize, &outBufferList, NULL);
            if (status != noErr && status != 'bxna') {
                [[XTAudioUnitManager shareManager] _stopUnit];
                return -1;
            }else if (packetSize) {
                ioData->mNumberBuffers = 1;
                ioData->mBuffers[0].mNumberChannels = 1;
                ioData->mBuffers[0].mDataByteSize = outBufferList.mBuffers[0].mDataByteSize;
                ioData->mBuffers[0].mData = outBufferList.mBuffers[0].mData;
                if (_outputBack) {
                    _outputBack((SInt16*)ioData->mBuffers[0].mData,1,inNumberFrames);
                }
                return noErr;
            }
    }else {
        ioData->mNumberBuffers = 0;
        ioData->mBuffers[0].mNumberChannels = 0;
        ioData->mBuffers[0].mDataByteSize = 0;
        ioData->mBuffers[0].mData = NULL;
        return -1;
    }
    return noErr;
}
-(OSStatus)handleAudioUnitOutputCallbackWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                                  audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                                     inBusNumber:(uint32_t)inBusNumber
                                  inNumberFrames:(uint32_t)inNumberFrames
                                          ioData:(AudioBufferList*)ioData{
    if (_audioCodecType == XTAudioCodecTypeAAC) {
      return [self decodeAACDataToPlayWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    }else{
      return [self decodeOpusDataToPlayWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    }
}
static OSStatus    XTAudioOutputCallBack(void                         *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp          *inTimeStamp,
                                 UInt32                     inBusNumber,
                                 UInt32                      inNumberFrames,
                                 AudioBufferList              *ioData)
{
    
    return [[XTAudioUnitManager shareManager] handleAudioUnitOutputCallbackWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
}
-(OSStatus)handleAudioUnitInputCallbackWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                                 audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                                    inBusNumber:(uint32_t)inBusNumber
                                 inNumberFrames:(uint32_t)inNumberFrames
                                         ioData:(AudioBufferList*)ioData{
    OSStatus status = noErr;
    if (_audioCodecType == XTAudioCodecTypeAAC) {
        status = [self encodeAACAuidoWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    }else{
        status = [self encodeOpusAuidoWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    }
    return status;
}
#pragma mark 注释<--  编码AAC数据  -->
-(OSStatus)encodeAACAuidoWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                   audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                      inBusNumber:(uint32_t)inBusNumber
                   inNumberFrames:(uint32_t)inNumberFrames
                           ioData:(AudioBufferList*)ioData{
    if ([XTAudioUnitManager shareManager]->_isRecording) {
        /*
         注意：如果采集的数据是PCM需要将dataFormat.mFramesPerPacket设置为1，而本例中最终要的数据为AAC,因为本例中使用的转换器只有每次传入1024帧才能开始工作,所以在AAC格式下需要将mFramesPerPacket设置为1024.也就是采集到的inNumPackets为1，在转换器中传入的inNumPackets应该为AAC格式下默认的1，在此后写入文件中也应该传的是转换好的inNumPackets,如果有特殊需求需要将采集的数据量小于1024,那么需要将每次捕捉到的数据先预先存储在一个buffer中,等到攒够1024帧再进行转换。
         */
        AudioBufferList bufferList; //此缓存一定要记得动态设置
        UInt16 numSamples=inNumberFrames*1;
        UInt16 samples[numSamples];
        memset (&samples, 0, sizeof (samples));
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mData = samples;
        bufferList.mBuffers[0].mNumberChannels = 1;
        bufferList.mBuffers[0].mDataByteSize = numSamples*sizeof(UInt16);
        
        AudioUnitRender([XTAudioUnitManager shareManager]->_audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
        void  *bufferData = bufferList.mBuffers[0].mData;
        UInt32   bufferSize = bufferList.mBuffers[0].mDataByteSize;
        //        printf(">>>>>>>Audio Recoder Render dataSize : %d \n",(unsigned int)bufferSize);
        // 由于PCM转成AAC的转换器每次需要有1024个采样点（每一帧2个字节）才能完成一次转换，所以每次需要2048大小的数据，这里定义的pcm_buffer用来累加每次存储的bufferData
        
        memcpy(pcm_buffer+pcm_buffer_size, bufferData, bufferSize);
        
        pcm_buffer_size = pcm_buffer_size + bufferSize;
        
        if(pcm_buffer_size >= kTVURecoderPCMMaxBuffSize) {
            
            UInt32   maxPacketSize    = 0;
            
            UInt32   size             = sizeof(maxPacketSize);
            
            OSStatus status;
            status = AudioConverterGetProperty(_encodeConvertRef,
                                               kAudioConverterPropertyMaximumOutputPacketSize,
                                               &size,
                                               &maxPacketSize);
            if (status != noErr) {
                return status;
            }
            printf("<<===============>>-%d\n",(unsigned int)maxPacketSize);
            AudioBufferList outBufferList;
            outBufferList.mNumberBuffers              = 1;
            outBufferList.mBuffers[0].mNumberChannels = _tagertFormat.mChannelsPerFrame;
            //            outBufferList.mBuffers[0].mData           = malloc(maxPacketSize);
            outBufferList.mBuffers[0].mData = mData;
            outBufferList.mBuffers[0].mDataByteSize   = kTVURecoderPCMMaxBuffSize;
            AudioStreamPacketDescription outputPacketDescriptions;
            // inNumPackets设置为1表示编码产生1帧数据即返回，官方：On entry, the capacity of outOutputData expressed in packets in the converter's output format. On exit, the number of packets of converted data that were written to outOutputData. 在输入表示输出数据的最大容纳能力 在转换器的输出格式上，在转换完成时表示多少个包被写入
            UInt32 inNumPackets = 1;
            
            // inNumPackets设置为1表示编码产生1024帧数据即返回
            // Notice : Here, due to encoder characteristics, 1024 frames of data must be given to the encoder in order to complete a conversion, 在此处由于编码器特性,必须给编码器1024帧数据才能完成一次转换,也就是刚刚在采集数据回调中存储的pcm_buffer
            status = AudioConverterFillComplexBuffer(_encodeConvertRef,
                                                     XTAudioEncodeConvertCallback,
                                                     pcm_buffer,
                                                     &inNumPackets,                                                     &outBufferList,
                                                     &outputPacketDescriptions);
            
            
            if(status != noErr){
                return status;
            }else{
                [self encoderOutPut:[NSData dataWithBytes:outBufferList.mBuffers[0].mData length:outBufferList.mBuffers[0].mDataByteSize]];
            }
            // 因为采样不可能每次都精准的采集到1024个样点，所以如果大于2048大小就先填满2048，剩下的跟着下一次采集一起送给转换器
            memcpy(pcm_buffer, pcm_buffer + kTVURecoderPCMMaxBuffSize, pcm_buffer_size - kTVURecoderPCMMaxBuffSize);
            pcm_buffer_size = pcm_buffer_size - kTVURecoderPCMMaxBuffSize;
        }
        if ([XTAudioUnitManager shareManager].inputBack) {
            [XTAudioUnitManager shareManager].inputBack((SInt16*)bufferList.mBuffers[0].mData,1,inNumberFrames);
        }
    }
    
    return noErr;
}
#pragma mark 注释<--  编码Opus数据  -->
-(OSStatus)encodeOpusAuidoWithFlag:(AudioUnitRenderActionFlags *)ioActionFlags
                   audioTimeStamp:(const AudioTimeStamp*)inTimeStamp
                      inBusNumber:(uint32_t)inBusNumber
                   inNumberFrames:(uint32_t)inNumberFrames
                           ioData:(AudioBufferList*)ioData{
    if (_isRecording) {
       
        AudioBufferList bufferList; //此缓存一定要记得动态设置
        UInt16 numSamples=inNumberFrames*1;
        UInt16 samples[numSamples];
        memset (&samples, 0, sizeof (samples));
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mData = samples;
        bufferList.mBuffers[0].mNumberChannels = 1;
        bufferList.mBuffers[0].mDataByteSize = numSamples*sizeof(UInt16);

        AudioUnitRender(_audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
        void  *bufferData = bufferList.mBuffers[0].mData;
        UInt32 bufferSize = bufferList.mBuffers[0].mDataByteSize;
        memcpy(pcm_buffer+pcm_buffer_size, bufferData, bufferSize);
        pcm_buffer_size = pcm_buffer_size + bufferSize;
        if (pcm_buffer_size >= dataSize) {
            NSData *tempData = [NSData dataWithBytes:pcm_buffer length:dataSize];
            NSData *opusData = [self.opusCodec encodePCMData:tempData];
            [self encoderOutPut:opusData];
            memcpy(pcm_buffer, pcm_buffer + dataSize, pcm_buffer_size - dataSize);
            pcm_buffer_size = pcm_buffer_size - dataSize;
        }
        NSLog(@"pcm_buffer_size=======%d",pcm_buffer_size);
        
    }
    return noErr;
}
static OSStatus    XTAudioInputCallback(void                        *inRefCon,
                                        AudioUnitRenderActionFlags *ioActionFlags,
                                        const AudioTimeStamp         *inTimeStamp,
                                        UInt32                     inBusNumber,
                                        UInt32                     inNumberFrames,
                                        AudioBufferList             *ioData)
{
    return [[XTAudioUnitManager shareManager] handleAudioUnitInputCallbackWithFlag:ioActionFlags audioTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
}

static OSStatus XTAudioDecodeConverterCallback(AudioConverterRef inAudioConverter,
                                               UInt32 *ioNumberDataPackets,
                                               AudioBufferList *ioData,
                                               AudioStreamPacketDescription **outDataPacketDescription,
                                               void *inUserData)
{
    if ([XTAudioUnitManager shareManager]->_packetArray.count > 0) {
        NSData *packet = [XTAudioUnitManager shareManager]->_packetArray[0];
        ioData->mNumberBuffers = 1;
        ioData->mBuffers[0].mData = (void *)packet.bytes;
        ioData->mBuffers[0].mDataByteSize = (UInt32)packet.length;
        static AudioStreamPacketDescription aspdesc;
        aspdesc.mDataByteSize = (UInt32)packet.length;
        aspdesc.mStartOffset = 0;
        aspdesc.mVariableFramesInPacket = 1;
        *outDataPacketDescription = &aspdesc;
        *ioNumberDataPackets = 1;
        [[XTAudioUnitManager shareManager]->_packetArray removeObjectAtIndex:0];
        return noErr;
    }else{
        *ioNumberDataPackets = 0;
        return 'bxnd';
    }
}
OSStatus XTAudioEncodeConvertCallback(AudioConverterRef              inAudioConverter,
                                      UInt32                         *ioNumberDataPackets,
                                      AudioBufferList                *ioData,
                                      AudioStreamPacketDescription   **outDataPacketDescription,
                                      void                           *inUserData) {
    
    ioData->mBuffers[0].mData           = inUserData;
    ioData->mBuffers[0].mNumberChannels = _tagertFormat.mChannelsPerFrame;
    ioData->mBuffers[0].mDataByteSize   = kXDXRecoderAACFramesPerPacket * kXDXRecoderAudioBytesPerPacket * _tagertFormat.mChannelsPerFrame;
    
    return 0;
}
-(void)_startUnit
{
    OSStatus result = noErr;
    result = AudioOutputUnitStart(_audioUnit);
    if (result) {
        printf("couldn't AudioOutputUnitStart unit");
    }
}
-(void)_stopUnit
{
    OSStatus result = noErr;
    result = AudioOutputUnitStop(_audioUnit);
    if (result) {
        printf("couldn't AudioOutputUnitStop unit");
    }
}
static BOOL XTGetSoftwareCodecClassDesc(UInt32 formatId, AudioClassDescription* classDesc)
{
#if TARGET_OS_IPHONE
    UInt32 size;
    
    if (AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, sizeof(formatId), &formatId, &size) != 0)
    {
        return NO;
    }
    
    UInt32 decoderCount = size / sizeof(AudioClassDescription);
    AudioClassDescription encoderDescriptions[decoderCount];
    
    if (AudioFormatGetProperty(kAudioFormatProperty_Decoders, sizeof(formatId), &formatId, &size, encoderDescriptions) != 0)
    {
        return NO;
    }
    
    for (UInt32 i = 0; i < decoderCount; ++i)
    {
        if (encoderDescriptions[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer)
        {
            *classDesc = encoderDescriptions[i];
            
            return YES;
        }
    }
#endif
    
    return NO;
}
- (void)XTCreatDecoderAudioConvert:(AudioStreamBasicDescription *)asbd
{
    OSStatus status;
    Boolean writable;
    UInt32 cookieSize;
    
    _sourceAsbd = *asbd;
    _playFormat = _sourceAsbd;
    
    _canonicalAsbd.mSampleRate = _sourceAsbd.mSampleRate;
    _canonicalAsbd.mChannelsPerFrame = _sourceAsbd.mChannelsPerFrame;
    
    AudioClassDescription classDesc;
    if (XTGetSoftwareCodecClassDesc(_sourceAsbd.mFormatID, &classDesc))
    {
        AudioConverterNewSpecific(&_sourceAsbd, &_canonicalAsbd, 1, &classDesc, &_decodeConvertRef);
    }
    
    if (!_decodeConvertRef)
    {
        status = AudioConverterNew(&_sourceAsbd, &_canonicalAsbd, &_decodeConvertRef);
        
        if (status)
        {
            NSLog(@"new AudioConverter inctance faild");
            return;
        }
    }
    
    status = AudioFileStreamGetPropertyInfo(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    
    if (!status)
    {
        void *cookieData = alloca(cookieSize);
        
        status = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
        
        if (status)
        {
            return;
        }
//        logHex(cookieData, cookieSize);
        status = AudioConverterSetProperty(_decodeConvertRef, kAudioConverterDecompressionMagicCookie, cookieSize, cookieData);
        
        if (status)
        {
            return;
        }
    }
}
- (NSString *)XTCreatEncodeAudioConvert{
    // 此处目标格式其他参数均为默认，系统会自动计算，否则无法进入encodeConverterComplexInputDataProc回调
    AudioStreamBasicDescription sourceDes = _canonicalAsbd;
    _tagertFormat.mFormatID                   = kAudioFormatMPEG4AAC;
    _tagertFormat.mSampleRate                 = _canonicalAsbd.mSampleRate;
    _tagertFormat.mChannelsPerFrame           = _canonicalAsbd.mChannelsPerFrame;
    _tagertFormat.mFramesPerPacket            = kXDXRecoderAACFramesPerPacket;

    OSStatus status     = 0;
    UInt32 targetSize   = sizeof(_tagertFormat);
    status              = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &targetSize, &_tagertFormat);
    
    // select software coding,选择软件编码
    AudioClassDescription audioClassDes;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                        sizeof(_tagertFormat.mFormatID),
                                        &_tagertFormat.mFormatID,
                                        &targetSize);
//    NSLog(@">>>>>>>pcm,get kAudioFormatProperty_Encoders status:%d",(int)status);
    
    UInt32 numEncoders = targetSize/sizeof(AudioClassDescription);
    AudioClassDescription audioClassArr[numEncoders];
    AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                           sizeof(_tagertFormat.mFormatID),
                           &_tagertFormat.mFormatID,
                           &targetSize,
                           audioClassArr);
//    NSLog(@">>>>>>>pcm wrirte audioClassArr status:%d",(int)status);
    
    for (int i = 0; i < numEncoders; i++) {
        if (audioClassArr[i].mSubType == kAudioFormatMPEG4AAC && audioClassArr[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            memcpy(&audioClassDes, &audioClassArr[i], sizeof(AudioClassDescription));
            break;
        }
    }
    
    if (_encodeConvertRef == NULL) {
        status          = AudioConverterNewSpecific(&sourceDes, &_tagertFormat, 1,
                                                    &audioClassDes, &_encodeConvertRef);
        
        if (status != noErr) {
            NSLog(@">>>>>>>Audio Recoder, new convertRef failed status:%d \n",(int)status);
            return @"Error : New convertRef failed \n";
        }
    }
    
    targetSize      = sizeof(sourceDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentInputStreamDescription, &targetSize, &sourceDes);
//    NSLog(@">>>>>>>pcm get sourceDes status:%d",(int)status);
    
    targetSize      = sizeof(_tagertFormat);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentOutputStreamDescription, &targetSize, &_tagertFormat);
//    NSLog(@">>>>>>>pcm get targetDes status:%d",(int)status);
    
    // 设置码率，需要和采样率对应
    UInt32 bitRate  = kXDXRecoderConverterEncodeBitRate;
    status          = AudioConverterSetProperty(_encodeConvertRef,
                                                kAudioConverterEncodeBitRate,
                                                sizeof(bitRate), &bitRate);
//    NSLog(@">>>>>>>pcm set covert property bit rate status:%d",(int)status);
    if (status != noErr) {
        NSLog(@">>>>>>>Audio Recoder set covert property bit rate status:%d",(int)status);
        return @"Error : Set covert property bit rate failed";
    }
    
    return nil;
}
-(void)cleanAudioDatas
{
        [self.packetArray removeAllObjects];
}
@end
