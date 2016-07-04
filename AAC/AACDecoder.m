//
//  AACDecoder.m
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "AACDecoder.h"
#import <AudioToolBox/AudioConverter.h>
#import <AudioToolBox/AudioFormat.h>

@interface AACDecoder ()

@property (strong, nonatomic) NSCondition *converterCond;

@end

@implementation AACDecoder

typedef struct {
    uint8_t* data;
    int size;
    int channelCount;
} UserData;

OSStatus decodeProc(AudioConverterRef audioConverter, UInt32 *ioNumDataPackets, AudioBufferList* ioData, AudioStreamPacketDescription** ioPacketDesc, void* inUserData )
{
    UserData* ud = (UserData*)inUserData;
    
    *ioNumDataPackets = 1;
    
    *ioPacketDesc = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription));
    (*ioPacketDesc)[0].mStartOffset = 0;
    (*ioPacketDesc)[0].mVariableFramesInPacket = 0;
    (*ioPacketDesc)[0].mDataByteSize = ud->size;
    
    ioData->mBuffers[0].mData = ud->data;
    ioData->mBuffers[0].mDataByteSize = ud->size;
    ioData->mBuffers[0].mNumberChannels = ud->channelCount;
    
    return noErr;
}

- (instancetype)initWithInputDesc:(AudioStreamBasicDescription)inDesc
                       outputDesc:(AudioStreamBasicDescription)outDesc
{
    if (self = [super init]) {
        _aacDesc = inDesc;
        _pcmDesc = outDesc;
        _converterCond = [[NSCondition alloc] init];
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    AudioConverterDispose(_m_audioConverter);
}

- (void)setup
{
    
    OSStatus result = 0;
    
    UInt32 outputBitrate = 128000;
    UInt32 propSize = sizeof(outputBitrate);
    UInt32 outputPacketSize = 0;
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioDecoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioDecoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    result = AudioConverterNewSpecific(&_aacDesc, &_pcmDesc, 2, requestedCodecs, &_m_audioConverter);
    if (result == noErr) {
        UInt32 value = 0;
        NSLog(@"Decoder info:");
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMinimumInputBufferSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMinimumInputBufferSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumInputBufferSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumInputBufferSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumInputPacketSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumInputPacketSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &propSize, &outputPacketSize);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumOutputPacketSize = %d",(int)result, outputPacketSize);
    }
    if (result == noErr) {
        _outputPacketMaxSize = outputPacketSize;
        _bytesPerSample = 2 * _pcmDesc.mChannelsPerFrame;
    } else {
        NSLog(@"Error setting up audio decoder %x", (int)result);
    }
}

- (void)pushData:(const uint8_t *)data size:(size_t)size pcmFrameCount:(int)frameCount
{
    if (!_asc && size == 2) {
        _asc = malloc(2);
        memcpy(_asc, data, 2);
        return;
    }
    // adts
    else if (size == 7 || size == 9) {
        NSLog(@"adts size = %zu", size);
        return;
    }
    
    const int required_bytes = frameCount * _pcmDesc.mBytesPerPacket;
    
    uint8_t *buffer = malloc(required_bytes);
    uint8_t* p_out = (uint8_t*)data;
    UInt32 num_packets = frameCount;
    
    AudioBufferList l;
    l.mNumberBuffers = 1;
    l.mBuffers[0].mDataByteSize = required_bytes;
    l.mBuffers[0].mData = buffer;
    
    UserData ud;
    ud.size = (int)size;
    ud.data = p_out;
    ud.channelCount = _pcmDesc.mChannelsPerFrame;
    
    AudioStreamPacketDescription output_packet_desc[num_packets];
    [_converterCond lock];
    OSStatus status = AudioConverterFillComplexBuffer(_m_audioConverter, decodeProc, &ud, &num_packets, &l, output_packet_desc);
    [_converterCond unlock];
    NSLog(@"status = %d, decoded number of packets = %d", status, num_packets);
    
    [_delegate aacDecoder:self didOutputData:buffer size:required_bytes];
}

@end
