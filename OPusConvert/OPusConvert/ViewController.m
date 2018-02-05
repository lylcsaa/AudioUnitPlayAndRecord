//
//  ViewController.m
//  OPusConvert
//
//  Created by wlx on 2018/1/30.
//  Copyright © 2018年 Tim. All rights reserved.
//

#import "ViewController.h"
#import "XTAudioUnitManager.h"
@interface ViewController ()

@end

@implementation ViewController
{
    NSData *_opusData;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"op_16" ofType:@"opus"];
    _opusData = [NSData dataWithContentsOfFile:filePath];
}
- (IBAction)playAndRecord:(UIButton *)sender
{
    if (sender.selected) {
        [[XTAudioUnitManager shareManager] stopRecord];
        [[XTAudioUnitManager shareManager]stopPlay];
    }else{
        [[XTAudioUnitManager shareManager] recorderAudio];
    }
    sender.selected = !sender.selected;
}
@end
