//
//  ConsumerSynthController.h
//  consumer
//
//  Created by Johan Halin on 1.7.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConsumerSynthChannel.h"

@interface ConsumerSynthController : NSObject

@property (nonatomic, assign) NSInteger note;
@property (nonatomic, assign) ConsumerSynthWaveform waveform;
@property (nonatomic, assign) float amplitudeAttack;
@property (nonatomic, assign) float amplitudeDecay;
@property (nonatomic, assign) float amplitudeSustain;
@property (nonatomic, assign) float amplitudeRelease;
@property (nonatomic, assign) float filterAttack;
@property (nonatomic, assign) float filterDecay;
@property (nonatomic, assign) float filterSustain;
@property (nonatomic, assign) float filterRelease;
@property (nonatomic, assign) float glide;
@property (nonatomic, assign) float filterCutoff;
@property (nonatomic, assign) float filterResonance;

@end
