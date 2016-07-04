//
//  AudioSink.m
//  AAC
//
//  Created by Ken Sun on 2016/7/4.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "AudioSink.h"

typedef struct DataBuffer {
    const uint8_t *data;
    size_t size;
    struct DataBuffer *next;
} DataBuffer;

@interface AudioSink ()

@property (nonatomic) DataBuffer *head;
@property (nonatomic) DataBuffer *tail;

@end

@implementation AudioSink

static OSStatus outputProc(void *inRefCon,
                           AudioUnitRenderActionFlags *ioActionFlags,
                           const AudioTimeStamp *inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList *ioData)
{
    AudioSink *sink = (__bridge AudioSink*)inRefCon;
    
    for (int i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer ab = ioData->mBuffers[i];
        
        DataBuffer *buffer = sink.head;
        if (buffer) {
            memcpy(ab.mData, buffer->data, buffer->size);
            sink.head = buffer->next;
            free(buffer);
            buffer = NULL;
            if (!sink.head) {
                sink.tail = NULL;
            }
        } else {
            memset(ab.mData, 0, ab.mDataByteSize);
        }
    }
    return noErr;
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
    
    OSStatus status;
    
    UInt32 flagZero = 0, flagOne = 1;
    status = AudioUnitSetProperty(_m_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagZero, sizeof(flagZero));
    if (status == noErr) {
        status = AudioUnitSetProperty(_m_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flagOne, sizeof(flagOne));
    }
    if (status == noErr) {
        status = AudioUnitSetProperty(_m_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_pcmDesc, sizeof(_pcmDesc));
    }
    if (status == noErr) {
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void * _Nullable)(self);
        cb.inputProc = outputProc;
        status = AudioUnitSetProperty(_m_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &cb, sizeof(cb));
    }
    if (status == noErr) {
        status = AudioUnitInitialize(_m_audioUnit);
    }
    NSLog(@"setup audio sink status = %d", status);
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

- (void)pushData:(const uint8_t *)data size:(size_t)size
{
    if (!_head) {
        _head = malloc(sizeof(DataBuffer));
        _head->data = data;
        _head->size = size;
        _head->next = NULL;
        _tail = _head;
    } else {
        DataBuffer *buffer = malloc(sizeof(DataBuffer));
        buffer->data = data;
        buffer->size = size;
        buffer->next = NULL;
        _tail->next = buffer;
        _tail = buffer;
    }
}

@end
