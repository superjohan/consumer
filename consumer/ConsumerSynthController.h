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
@property (nonatomic, assign) ConsumerSynthWaveform osc1Waveform;
@property (nonatomic, assign) float osc1Detune;
@property (nonatomic, assign) float osc1Amplitude;
@property (nonatomic, assign) NSInteger osc1Octave;
@property (nonatomic, assign) ConsumerSynthWaveform osc2Waveform;
@property (nonatomic, assign) float osc2Detune;
@property (nonatomic, assign) float osc2Amplitude;
@property (nonatomic, assign) NSInteger osc2Octave;
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
@property (nonatomic, assign) float filterPeak;
@property (nonatomic, assign) float reverbDryWetMix;
@property (nonatomic, assign) float delayDryWetMix;

- (void)configure;

@end
