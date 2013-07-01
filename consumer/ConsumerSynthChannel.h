//
//  ConformSynthChannel.h
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import <Foundation/Foundation.h>

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
	ConsumerSynthWaveformSine,
	ConsumerSynthWaveformSquare,
	ConsumerSynthWaveformTriangle,
	ConsumerSynthWaveformSaw,
};

@interface ConsumerSynthChannel : NSObject
{
	@public
	float sampleRate;
	NSInteger currentNote;
	ConsumerADSREnvelope amplitudeEnvelope;
	ConsumerSynthWaveform oscillator1Waveform;
}

@end
