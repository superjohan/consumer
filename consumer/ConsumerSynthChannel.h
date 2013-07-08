//
//  ConformSynthChannel.h
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

typedef struct
{
	float attack;
	float decay;
	float sustain;
	float release;
}
ConsumerADSREnvelope;

typedef NS_ENUM(NSInteger, ConsumerSynthWaveform)
{
	ConsumerSynthWaveformSine = 0,
	ConsumerSynthWaveformSquare,
	ConsumerSynthWaveformTriangle,
	ConsumerSynthWaveformSaw,
};

const NSInteger ConsumerNoteOff = -1;

@interface ConsumerSynthChannel : NSObject
{
	@public
	ConsumerADSREnvelope amplitudeEnvelope;
	ConsumerSynthWaveform oscillator1Waveform;
	float glide; // range: 0 - 1.0
	AudioUnit filterUnit;
	float filterCutoff; // range: 0 - 1.0
	float filterResonance; // range: -0.5 - 1.0
}

@property (nonatomic, assign) NSInteger currentNote;

- (instancetype)initWithSampleRate:(float)sampleRate;

@end
