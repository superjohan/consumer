//
//  ConformSynthChannel.m
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerSynthChannel.h"
#import "ConsumerHelperFunctions.h"
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

typedef NS_ENUM(NSInteger, ConsumerEnvelopeState)
{
	ConsumerEnvelopeStateAttack,
	ConsumerEnvelopeStateDecay,
	ConsumerEnvelopeStateSustain,
	ConsumerEnvelopeStateRelease,
	ConsumerEnvelopeStateMax,
};

@interface ConsumerSynthChannel () <AEAudioPlayable>
@end

@implementation ConsumerSynthChannel
{
	NSInteger notePosition;
	ConsumerEnvelopeState amplitudeEnvelopeState;
}

float noteFrequency(NSInteger note)
{
	return powf(2.0, ((note - 49.0) / 12.0)) * 440.0;
}

float square(float input, float offset)
{
	float fit = floorf((input - fmodf(input, M_PI * 2.0)) / (M_PI * 2.0));
	input = input - (fit * (M_PI * 2.0));

	if (offset < 0)
	{
		offset = 0;
	}
	else if (offset > 1.0)
	{
		offset = 1.0;
	}
	
	if (input < ((M_PI * 2.0) * offset))
	{
		return -1.0;
	}
	else
	{
		return 1.0;
	}
}

float triangle(float input)
{
	return 0;
}

float saw(float input)
{
	return 0;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	for (NSInteger i = 0; i < frames; i++)
	{
		float l = 0;
		float r = 0;
		
		if (this->currentNote > 0)
		{
			NSInteger note = this->currentNote;
			float value = 0;
			if (note > 0)
			{
				float frequency = noteFrequency(note);
				float phase = (M_PI * 2.0) * ((this->notePosition / this->sampleRate) * frequency);
				
				if (this->oscillator1Waveform == ConsumerSynthWaveformSine)
				{
					value = sinf(phase);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformSquare)
				{
					value = square(phase, 0.5);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformTriangle)
				{
					value = triangle(phase);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformSaw)
				{
					value = saw(phase);
				}
				
				l = value;
				r = l;
				
				this->notePosition++;
			}
		}
		else
		{
			this->notePosition = 0;
		}
		
		clampStereo(&l, &r, 1.0);
		
		((float *)audio->mBuffers[0].mData)[i] = l;
		((float *)audio->mBuffers[1].mData)[i] = r;
	}

	return noErr;
}

- (AEAudioControllerRenderCallback)renderCallback
{
	return &renderCallback;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		currentNote = 0;
		notePosition = 0;
		oscillator1Waveform = ConsumerSynthWaveformSine;
	}
	
	return self;
}

@end
