//
//  AACEncoder.h
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACEncoderDelegate;

@interface AACEncoder : NSObject

@property (weak, nonatomic) id<AACEncoderDelegate> delegate;

@property (nonatomic) AudioStreamBasicDescription pcmDesc;
@property (nonatomic) AudioStreamBasicDescription aacDesc;
@property (nonatomic) AudioConverterRef m_audioConverter;

@property (nonatomic) int bytesPerSample;

@property (nonatomic) uint32_t outputPacketMaxSize;

@property (nonatomic) uint8_t *asc;

@property (nonatomic) BOOL sentConfig;


- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithInputDesc:(AudioStreamBasicDescription)inDesc
                       outputDesc:(AudioStreamBasicDescription)outDesc;

- (void)pushData:(const uint8_t*)data size:(size_t)size frameCount:(int)frameCount;

@end


@protocol AACEncoderDelegate <NSObject>

- (void)aacEncoder:(AACEncoder *)enc didOutputData:(uint8_t *)data size:(size_t)size pcmFrameCount:(int)frameCount;

@end