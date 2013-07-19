//
//  ConformSynthChannel.h
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

// range on all values: 0 - 1.0
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

static const NSInteger ConsumerNoteOff = -1;

@interface ConsumerSynthChannel : NSObject
{
	@public
	ConsumerADSREnvelope amplitudeEnvelope;
	ConsumerADSREnvelope filterEnvelope;
	ConsumerSynthWaveform oscillator1Waveform;
	float oscillator1Detune; // range: -1.0 - 1.0
	float oscillator1Amplitude; // range: 0 - 1.0
	NSInteger oscillator1Octave; // range: -2 - 2
	ConsumerSynthWaveform oscillator2Waveform;
	float oscillator2Detune; // range: -1.0 - 1.0
	float oscillator2Amplitude; // range: 0 - 1.0
	NSInteger oscillator2Octave; // range: -2 - 2
	float glide; // range: 0 - 1.0
	float filterCutoff; // range: 0 - 1.0
	float filterResonance; // range: -0.5 - 1.0
	float filterPeak; // range 0 - 1.0
	float lfoRate;
	float lfoDepth;
	BOOL hardSync;
}

@property (nonatomic, assign) NSInteger currentNote;

- (instancetype)initWithSampleRate:(float)sampleRate;

@end
