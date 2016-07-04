//
//  ViewController.m
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "ViewController.h"
#import "AACEncoder.h"
#import "AudioSource.h"
#import "AACDecoder.h"
#import "AudioSink.h"

@interface ViewController () <AudioSourceDelegate, AACEncoderDelegate, AACDecoderDelegate>

@property (strong, nonatomic) AACEncoder *aacEncoder;
@property (strong, nonatomic) AACDecoder *aacDecoder;
@property (strong, nonatomic) AudioSource *audioSource;
@property (strong, nonatomic) AudioSink *audioSink;

@property (nonatomic) AudioStreamBasicDescription pcmDesc;
@property (nonatomic) AudioStreamBasicDescription aacDesc;

@property (nonatomic) int channelCount;
@property (nonatomic) int sampleRate;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _channelCount = 2;
    _sampleRate = 44100;
    
    [self setupPCMDesc];
    [self setupAACDesc];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [session setActive:YES error:nil];
    
    __weak typeof(self) _self = self;
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            [_self start];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)start
{
    _audioSource = [[AudioSource alloc] initWithDescription:_pcmDesc];
    _audioSource.delegate = self;
    [_audioSource start];
    
    _aacEncoder = [[AACEncoder alloc] initWithInputDesc:_pcmDesc outputDesc:_aacDesc];
    _aacEncoder.delegate = self;
    
    _aacDecoder = [[AACDecoder alloc] initWithInputDesc:_aacDesc outputDesc:_pcmDesc];
    _aacDecoder.delegate = self;
    
    _audioSink = [[AudioSink alloc] initWithDescription:_pcmDesc];
    [_audioSink start];
}

- (void)setupPCMDesc
{
    AudioStreamBasicDescription desc = {0};
    desc.mSampleRate = _sampleRate;
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked);
    desc.mChannelsPerFrame = _channelCount;
    desc.mFramesPerPacket = 1;
    desc.mBitsPerChannel = 16;
    desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
    desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
    _pcmDesc = desc;
}

- (void)setupAACDesc
{
    AudioStreamBasicDescription desc = {0};
    desc.mFormatID = kAudioFormatMPEG4AAC;
    desc.mFormatFlags = kMPEG4Object_AAC_LC;
    desc.mFramesPerPacket = 1024;
    desc.mSampleRate = _sampleRate;
    desc.mChannelsPerFrame = _channelCount;
    _aacDesc = desc;
}


#pragma mark - AudioSource Delegate

- (void)audioSource:(AudioSource *)audioSrc didOutputData:(uint8_t *)data size:(size_t)size  frameCount:(int)frameCount
{
    [_aacEncoder pushData:data size:size frameCount:frameCount];
    //[_audioSink pushData:data size:size];
}


#pragma mark - AACEncoder Delegate

- (void)aacEncoder:(AACEncoder *)enc didOutputData:(uint8_t *)data size:(size_t)size pcmFrameCount:(int)frameCount
{
    NSLog(@"aac encoded data size = %zu", size);
    [_aacDecoder pushData:data size:size pcmFrameCount:frameCount];
}


#pragma mark - AACDecoder Delegate

- (void)aacDecoder:(AACDecoder *)enc didOutputData:(uint8_t *)data size:(size_t)size
{
    NSLog(@"aac decoded data size = %zu", size);
    [_audioSink pushData:data size:size];
}

@end
