//
//  AudioSource.m
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "AudioSource.h"

@interface AudioSource ()

- (void)handleInputData:(uint8_t *)data size:(size_t)data_size frameCount:(int)inNumberFrames;

@end

@implementation AudioSource

static OSStatus inputProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber,
                          UInt32 inNumberFrames,
                          AudioBufferList *ioData)
{
    AudioSource *src = (__bridge AudioSource*)inRefCon;
    
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = src.pcmDesc.mChannelsPerFrame;
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    
    OSStatus status = AudioUnitRender(src.m_audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      &buffers);
    
    if (status == noErr) {
        [src handleInputData:buffers.mBuffers[0].mData size:buffers.mBuffers[0].mDataByteSize frameCount:inNumberFrames];
    }
    return status;
}

- (instancetype)initWithDescription:(AudioStreamBasicDescription)desc
{
    if (self = [super init]) {
        _pcmDesc = desc;
        [self setup];
    }
    return self;
}

- (void)setup
{
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    _m_component = AudioComponentFindNext(NULL, &acd);
    
    AudioComponentInstanceNew(_m_component, &_m_audioUnit);
    if(!_m_audioUnit) {
        NSLog(@"AudioComponentInstanceNew failed");
        return ;
    }

    UInt32 flagOne = 1;
    
    AudioUnitSetProperty(_m_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void * _Nullable)(self);
    cb.inputProc = inputProc;
    AudioUnitSetProperty(_m_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &_pcmDesc, sizeof(_pcmDesc));
    AudioUnitSetProperty(_m_audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
    AudioUnitInitialize(_m_audioUnit);
}

- (void)start
{
    OSStatus ret = AudioOutputUnitStart(_m_audioUnit);
    if (ret != noErr) {
        NSLog(@"Failed to start microphone!");
    }
}

- (void)stop
{
    AudioOutputUnitStop(_m_audioUnit);
}

- (void)handleInputData:(uint8_t *)data size:(size_t)size frameCount:(int)inNumberFrames
{
    [_delegate audioSource:self didOutputData:data size:size frameCount:inNumberFrames];
}

@end
