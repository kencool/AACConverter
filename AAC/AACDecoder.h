//
//  AACDecoder.h
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACDecoderDelegate;

@interface AACDecoder : NSObject

@property (weak, nonatomic) id<AACDecoderDelegate> delegate;

@property (nonatomic) AudioStreamBasicDescription pcmDesc;
@property (nonatomic) AudioStreamBasicDescription aacDesc;
@property (nonatomic) AudioConverterRef m_audioConverter;

@property (nonatomic) int bytesPerSample;

@property (nonatomic) uint32_t outputPacketMaxSize;

@property (nonatomic) uint8_t *asc;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithInputDesc:(AudioStreamBasicDescription)inDesc
                       outputDesc:(AudioStreamBasicDescription)outDesc;

- (void)pushData:(const uint8_t*)data size:(size_t)size pcmFrameCount:(int)frameCount;

@end


@protocol AACDecoderDelegate <NSObject>

- (void)aacDecoder:(AACDecoder *)enc didOutputData:(uint8_t *)data size:(size_t)size;

@end