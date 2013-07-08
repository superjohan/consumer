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
	NSInteger _envelopePosition;
	NSInteger _note;
	ConsumerEnvelopeState _amplitudeEnvelopeState;
	float _sampleRate;
	float _noteTime;
	float _startFrequency;
	float _currentFrequency;
	float _targetFrequency;
	float _angle;
}

const NSInteger ConsumerMaxStateLength = 44100;

float noteFrequency(NSInteger note)
{
	return powf(2.0, ((note - 49.0) / 12.0)) * 440.0;
}

float square(float input, float width)
{
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
	float value = (input * 2.0) / (M_PI * 2.0);
	return value - 1.0;
}

float applyVolumeEnvelope(ConsumerSynthChannel *this)
{
	float amplitude = 0;
	
	if (floatsAreEqual(this->_noteTime, 0))
	{
		this->_amplitudeEnvelopeState = ConsumerEnvelopeStateAttack;
		this->_envelopePosition = 0;
	}

	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->amplitudeEnvelope.attack * ConsumerMaxStateLength;

		if (this->_envelopePosition < attackLength)
		{
			amplitude = this->_envelopePosition / attackLength;
			this->_envelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateDecay;
			this->_envelopePosition = 0;
		}
	}
	else if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateDecay)
	{
		float decayLength = this->amplitudeEnvelope.decay * ConsumerMaxStateLength;

		if (this->_envelopePosition < decayLength)
		{
			amplitude = 1.0 - ((this->_envelopePosition / decayLength) * (1.0 - this->amplitudeEnvelope.sustain));
			this->_envelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateSustain;
		}
	}
	else if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateSustain)
	{
		amplitude = this->amplitudeEnvelope.sustain;

		if (this->_currentNote == ConsumerNoteOff)
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateRelease;
			this->_envelopePosition = 0;
		}
	}
	else if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateRelease)
	{
		float releaseLength = this->amplitudeEnvelope.release * ConsumerMaxStateLength;

		if (this->_envelopePosition < releaseLength)
		{
			amplitude = this->amplitudeEnvelope.sustain - ((this->_envelopePosition / releaseLength) * this->amplitudeEnvelope.sustain);
			this->_envelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_currentNote = 0;
			this->_note = 0;
		}
	}
	
	return amplitude;
}

float applyFrequencyGlide(ConsumerSynthChannel *this)
{
	float frequency = 0;
	
	if ( ! floatsAreEqual(this->_currentFrequency, this->_targetFrequency))
	{
		float glide = this->glide;
		if (glide > 0)
		{
			float diff = this->_targetFrequency - this->_startFrequency;
			float timeDiff = glide * ConsumerMaxStateLength;
			float frequencyStep = diff / timeDiff;
			frequency = this->_currentFrequency + frequencyStep;
		}
		else
		{
			frequency = this->_targetFrequency;
		}
		
		if ((this->_targetFrequency > this->_startFrequency && frequency > this->_targetFrequency) || (this->_targetFrequency < this->_startFrequency && frequency < this->_targetFrequency))
		{
			frequency = this->_targetFrequency;
		}
	}
	else
	{
		frequency = noteFrequency(this->_note);
	}
	
	return frequency;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	for (NSInteger i = 0; i < frames; i++)
	{
		float l = 0;
		float r = 0;
		
		if (this->_note > 0)
		{
			float amplitude = applyVolumeEnvelope(this);

			float value = 0;
			if (this->_note > 0)
			{
				float frequency = applyFrequencyGlide(this);

				float angle = this->_angle + ((M_PI * 2.0) * frequency / this->_sampleRate);
				angle = fmodf(angle, M_PI * 2.0);
				
				if (this->oscillator1Waveform == ConsumerSynthWaveformSine)
				{
					value = sinf(angle);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformSquare)
				{
					value = square(angle, 0.5);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformTriangle)
				{
					value = triangle(angle);
				}
				else if (this->oscillator1Waveform == ConsumerSynthWaveformSaw)
				{
					value = saw(angle);
				}
				
				l = value * (amplitude * amplitude);
				r = l;
				
				this->_currentFrequency = frequency;
				this->_noteTime += .001; // FIXME
				this->_angle = angle;
			}
		}
		else
		{
			this->_noteTime = 0;
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_angle = 0;
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

- (instancetype)initWithSampleRate:(float)sampleRate
{
	if ((self = [super init]))
	{
		oscillator1Waveform = ConsumerSynthWaveformSine;
		amplitudeEnvelope = (ConsumerADSREnvelope){ .attack = 0.5, .decay = 0.5, .sustain = 0.5, .release = 0.5 };
		glide = 0;
		_sampleRate = sampleRate;
		_currentNote = 0;
		_note = 0;
		_noteTime = 0;
	}
	
	return self;
}

- (void)setCurrentNote:(NSInteger)currentNote
{
	@synchronized(self)
	{
		if (_currentNote <= 0)
		{
			_noteTime = 0; // FIXME for glide?
		}
		
		_currentNote = currentNote;

		if (_currentNote != ConsumerNoteOff)
		{
			_startFrequency = _currentFrequency;
			_targetFrequency = noteFrequency(_currentNote);
			_note = _currentNote;
		}
	}
}

@end
