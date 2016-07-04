//
//  AudioSource.h
//  AAC
//
//  Created by Ken Sun on 2016/7/1.
//  Copyright © 2016年 Alumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol AudioSourceDelegate;

@interface AudioSource : NSObject

@property (weak, nonatomic) id<AudioSourceDelegate> delegate;
@property (nonatomic) AudioComponentInstance m_audioUnit;
@property (nonatomic) AudioComponent m_component;
@property (nonatomic) AudioStreamBasicDescription pcmDesc;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDescription:(AudioStreamBasicDescription)desc;

- (void)start;
- (void)stop;

@end


@protocol AudioSourceDelegate <NSObject>

- (void)audioSource:(AudioSource *)audioSrc didOutputData:(uint8_t *)data size:(size_t)size frameCount:(int)frameCount;

@end