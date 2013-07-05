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
	NSInteger envelopePosition;
	NSInteger note;
	ConsumerEnvelopeState amplitudeEnvelopeState;
}

const NSInteger ConsumerMaxStateLength = 44100;

float noteFrequency(NSInteger note)
{
	return powf(2.0, ((note - 49.0) / 12.0)) * 440.0;
}

void fixPhase(float *input_p)
{
	float fit = floorf((*input_p - fmodf(*input_p, M_PI * 2.0)) / (M_PI * 2.0));
	*input_p = *input_p - (fit * (M_PI * 2.0));
}

float square(float input, float width)
{
	fixPhase(&input);

	if (width < 0)
	{
		width = 0;
	}
	else if (width > 1.0)
	{
		width = 1.0;
	}
	
	if (input < ((M_PI * 2.0) * width))
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
	fixPhase(&input);
	
	if (input < M_PI)
	{
		float value = (input * 2.0) / M_PI;
		return value - 1.0;
	}
	else
	{
		float value = ((input - M_PI) * 2.0) / M_PI;
		return 1.0 - value;
	}
}

float saw(float input)
{
	fixPhase(&input);
	
	float value = (input * 2.0) / (M_PI * 2.0);
	return value - 1.0;
}

float applyVolumeEnvelope(ConsumerSynthChannel *this)
{
	float amplitude = 0;
	
	if (this->notePosition == 0)
	{
		this->amplitudeEnvelopeState = ConsumerEnvelopeStateAttack;
		this->envelopePosition = 0;
	}

	if (this->amplitudeEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->amplitudeEnvelope.attack * ConsumerMaxStateLength;

		if (this->envelopePosition < attackLength)
		{
			amplitude = this->notePosition / attackLength;
			this->envelopePosition++;
		}
		else
		{
			this->amplitudeEnvelopeState = ConsumerEnvelopeStateDecay;
			this->envelopePosition = 0;
		}
	}
	else if (this->amplitudeEnvelopeState == ConsumerEnvelopeStateDecay)
	{
		float decayLength = this->amplitudeEnvelope.decay * ConsumerMaxStateLength;

		if (this->envelopePosition < decayLength)
		{
			amplitude = 1.0 - ((this->envelopePosition / decayLength) * (1.0 - this->amplitudeEnvelope.sustain));
			this->envelopePosition++;
		}
		else
		{
			this->amplitudeEnvelopeState = ConsumerEnvelopeStateSustain;
		}
	}
	else if (this->amplitudeEnvelopeState == ConsumerEnvelopeStateSustain)
	{
		amplitude = this->amplitudeEnvelope.sustain;

		if (this->_currentNote == ConsumerNoteOff)
		{
			this->amplitudeEnvelopeState = ConsumerEnvelopeStateRelease;
			this->envelopePosition = 0;
		}
	}
	else if (this->amplitudeEnvelopeState == ConsumerEnvelopeStateRelease)
	{
		float releaseLength = this->amplitudeEnvelope.release * ConsumerMaxStateLength;

		if (this->envelopePosition < releaseLength)
		{
			amplitude = this->amplitudeEnvelope.sustain - ((this->envelopePosition / releaseLength) * this->amplitudeEnvelope.sustain);
			this->envelopePosition++;
		}
		else
		{
			this->amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_currentNote = 0;
			this->note = 0;
		}
	}
	
	return amplitude;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	for (NSInteger i = 0; i < frames; i++)
	{
		float l = 0;
		float r = 0;
		
		if (this->note > 0)
		{
			float amplitude = applyVolumeEnvelope(this);

			NSInteger note = this->note;
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
				
				l = value * amplitude;
				r = l;
				
				this->notePosition++;
			}
		}
		else
		{
			this->notePosition = 0;
			this->amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
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
		_currentNote = 0;
		note = 0;
		notePosition = 0;
		oscillator1Waveform = ConsumerSynthWaveformSine;
		amplitudeEnvelope = (ConsumerADSREnvelope){ .attack = 0.5, .decay = 0.5, .sustain = 0.5, .release = 0.5 };
	}
	
	return self;
}

- (void)setCurrentNote:(NSInteger)currentNote
{
	@synchronized(self)
	{
		if (_currentNote <= 0)
		{
			notePosition = 0; // FIXME for glide?
		}
		
		_currentNote = currentNote;
		
		if (_currentNote != ConsumerNoteOff)
		{
			note = _currentNote;
		}
	}
}

@end
