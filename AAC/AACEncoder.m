//
//  AACEncoder.m
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import "AACEncoder.h"

@interface AACEncoder ()

@property (strong, nonatomic) NSCondition *converterCond;

@end

@implementation AACEncoder

typedef struct {
    uint8_t* data;
    int size;
    int packetSize;
    int channelCount;
} UserData;

OSStatus ioProc(AudioConverterRef audioConverter, UInt32 *ioNumDataPackets, AudioBufferList* ioData, AudioStreamPacketDescription** ioPacketDesc, void* inUserData )
{
    UserData* ud = (UserData*)inUserData;
    
    UInt32 maxPackets = ud->size / ud->packetSize;
    
    *ioNumDataPackets = MIN(maxPackets, *ioNumDataPackets);
    
    ioData->mBuffers[0].mData = ud->data;
    ioData->mBuffers[0].mDataByteSize = ud->size;
    ioData->mBuffers[0].mNumberChannels = ud->channelCount;
    
    return noErr;
}

- (instancetype)initWithInputDesc:(AudioStreamBasicDescription)inDesc
                       outputDesc:(AudioStreamBasicDescription)outDesc
{
    if (self = [super init]) {
        _pcmDesc = inDesc;
        _aacDesc = outDesc;
        _converterCond = [[NSCondition alloc] init];
        [self setup];
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
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
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    result = AudioConverterNewSpecific(&_pcmDesc, &_aacDesc, 2, requestedCodecs, &_m_audioConverter);
    
    if (result == noErr) {
        result = AudioConverterSetProperty(_m_audioConverter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
    }
    if (result == noErr) {
        UInt32 value = 0;
        NSLog(@"Encoder info:");
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMinimumInputBufferSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMinimumInputBufferSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumInputBufferSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumInputBufferSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumInputPacketSize, &propSize, &value);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumInputPacketSize = %d",(int)result, value);
        result = AudioConverterGetProperty(_m_audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &propSize, &outputPacketSize);
        NSLog(@"result = %x, kAudioConverterPropertyMaximumOutputPacketSize = %d",(int)result, outputPacketSize);
        result = noErr;
    }
    if (result == noErr) {
        _outputPacketMaxSize = outputPacketSize;
        _bytesPerSample = 2 * _pcmDesc.mChannelsPerFrame;
        uint8_t sampleRateIndex = 3;
        
        // http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
        _asc = (uint8_t*)malloc(2);
        _asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
        _asc[1] = ((sampleRateIndex & 0x1)<<7) | ((2 & 0xF) << 3); // | (1 << 2) for 960 samples per frame
    } else {
        NSLog(@"Error setting up audio encoder %x", (int)result);
    }
}

- (void)pushData:(const uint8_t*)data size:(size_t)size frameCount:(int)frameCount
{
    const size_t sampleCount = size / _bytesPerSample;
    const size_t aac_packet_count = sampleCount / _aacDesc.mFramesPerPacket;
    const size_t required_bytes = aac_packet_count * _outputPacketMaxSize;
    
    uint8_t *buffer = malloc(required_bytes);
    
    uint8_t* p = buffer;
    uint8_t* p_out = (uint8_t*)data;
    
    for ( size_t i = 0 ; i < aac_packet_count ; ++i ) {
        UInt32 num_packets = 1;
        
        AudioBufferList l;
        l.mNumberBuffers=1;
        l.mBuffers[0].mDataByteSize = _outputPacketMaxSize * num_packets;
        l.mBuffers[0].mData = p;
        
        UserData ud;

        ud.size = _aacDesc.mFramesPerPacket * _bytesPerSample;
        ud.data = p_out;
        ud.packetSize = _bytesPerSample;
        ud.channelCount = _pcmDesc.mChannelsPerFrame;
        
        AudioStreamPacketDescription output_packet_desc[num_packets];
        [_converterCond lock];
        OSStatus status = AudioConverterFillComplexBuffer(_m_audioConverter, ioProc, &ud, &num_packets, &l, output_packet_desc);
        [_converterCond unlock];
        NSLog(@"status = %x, encoded number of packets = %d", (int)status, num_packets);
        
        p += output_packet_desc[0].mDataByteSize;
        p_out += _aacDesc.mFramesPerPacket * _bytesPerSample;
    }
    const size_t totalBytes = p - buffer;

    if (totalBytes > 0) {
        if (!_sentConfig) {
            [_delegate aacEncoder:self didOutputData:_asc size:2 pcmFrameCount:0];
            _sentConfig = true;
        }
        [_delegate aacEncoder:self didOutputData:buffer size:totalBytes pcmFrameCount:frameCount];
    }
}

@end
