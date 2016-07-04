//
//  AudioSink.h
//  AAC
//
//  Created by Ken Sun on 2016/7/4.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioSink : NSObject

@property (nonatomic) AudioComponentInstance m_audioUnit;
@property (nonatomic) AudioComponent m_component;
@property (nonatomic) AudioStreamBasicDescription pcmDesc;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDescription:(AudioStreamBasicDescription)desc;

- (void)start;
- (void)stop;

- (void)pushData:(const uint8_t*)data size:(size_t)size;

@end
