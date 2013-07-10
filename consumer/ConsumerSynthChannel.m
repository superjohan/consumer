//
//  ConformSynthChannel.m
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerSynthChannel.h"
#import "ConsumerHelperFunctions.h"

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
	NSInteger _amplitudeEnvelopePosition;
	NSInteger _filterEnvelopePosition;
	NSInteger _note;
	ConsumerEnvelopeState _amplitudeEnvelopeState;
	ConsumerEnvelopeState _filterEnvelopeState;
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
		this->_amplitudeEnvelopePosition = 0;
	}

	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->amplitudeEnvelope.attack * ConsumerMaxStateLength;

		if (this->_amplitudeEnvelopePosition < attackLength)
		{
			amplitude = this->_amplitudeEnvelopePosition / attackLength;
			this->_amplitudeEnvelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateDecay;
			this->_amplitudeEnvelopePosition = 0;
		}
	}
	
	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateDecay)
	{
		float decayLength = this->amplitudeEnvelope.decay * ConsumerMaxStateLength;

		if (this->_amplitudeEnvelopePosition < decayLength)
		{
			amplitude = 1.0 - ((this->_amplitudeEnvelopePosition / decayLength) * (1.0 - this->amplitudeEnvelope.sustain));
			this->_amplitudeEnvelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateSustain;
		}
	}
	
	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateSustain)
	{
		amplitude = this->amplitudeEnvelope.sustain;

		if (this->_currentNote == ConsumerNoteOff)
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateRelease;
			this->_amplitudeEnvelopePosition = 0;
		}
	}
	
	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateRelease)
	{
		float releaseLength = this->amplitudeEnvelope.release * ConsumerMaxStateLength;

		if (this->_amplitudeEnvelopePosition < releaseLength)
		{
			amplitude = this->amplitudeEnvelope.sustain - ((this->_amplitudeEnvelopePosition / releaseLength) * this->amplitudeEnvelope.sustain);
			this->_amplitudeEnvelopePosition++;
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

void applyFilterEnvelope(ConsumerSynthChannel *this, UInt32 frames)
{
	if (floatsAreEqual(this->_noteTime, 0))
	{
		this->_filterEnvelopeState = ConsumerEnvelopeStateAttack;
		this->_filterEnvelopePosition = 0;
	}
	
	float cutoff = 0;
	float resonance = 0;
	
	if (this->_filterEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->filterEnvelope.attack * ConsumerMaxStateLength;
		
		if (this->_filterEnvelopePosition < attackLength)
		{
			cutoff = (this->_filterEnvelopePosition / attackLength) * this->filterPeak;
			resonance = (this->_filterEnvelopePosition / attackLength) * this->filterPeak;
			this->_filterEnvelopePosition += frames;
		}
		else
		{
			this->_filterEnvelopeState = ConsumerEnvelopeStateDecay;
			this->_filterEnvelopePosition = 0;
		}
	}
	
	if (this->_filterEnvelopeState == ConsumerEnvelopeStateDecay)
	{
		float decayLength = this->filterEnvelope.decay * ConsumerMaxStateLength;
		
		if (this->_filterEnvelopePosition < decayLength)
		{
			cutoff = this->filterPeak - ((this->_filterEnvelopePosition / decayLength) * (this->filterPeak - this->filterEnvelope.sustain));
			resonance = this->filterPeak - ((this->_filterEnvelopePosition / decayLength) * (this->filterPeak - this->filterEnvelope.sustain));
			this->_filterEnvelopePosition += frames;
		}
		else
		{
			this->_filterEnvelopeState = ConsumerEnvelopeStateSustain;
			this->_filterEnvelopePosition = 0;
		}
	}
	
	if (this->_filterEnvelopeState == ConsumerEnvelopeStateSustain)
	{
		cutoff = this->filterEnvelope.sustain;
		resonance = this->filterEnvelope.sustain;
		
		if (this->_currentNote == ConsumerNoteOff)
		{
			this->_filterEnvelopeState = ConsumerEnvelopeStateRelease;
			this->_filterEnvelopePosition = 0;
		}
	}
	
	if (this->_filterEnvelopeState == ConsumerEnvelopeStateRelease)
	{
		float releaseLength = this->filterEnvelope.release * ConsumerMaxStateLength;
		
		if (this->_filterEnvelopePosition < releaseLength)
		{
			cutoff = this->filterEnvelope.sustain - ((this->_filterEnvelopePosition / releaseLength) * this->filterEnvelope.sustain);
			resonance = this->filterEnvelope.sustain - ((this->_filterEnvelopePosition / releaseLength) * this->filterEnvelope.sustain);
			this->_filterEnvelopePosition += frames;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
		}
	}
		
	convertLinearValue(&cutoff);
	float finalCutoff = (float)(this->_sampleRate / 2) * (cutoff * this->filterCutoff);
	float finalResonance = 40.0 * (resonance * this->filterResonance);
	applyFilter(this, finalCutoff, finalResonance);
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

void applyFilter(ConsumerSynthChannel *this, float cutoff, float resonance)
{
	AudioUnitSetParameter(this->filterUnit, kLowPassParam_CutoffFrequency, kAudioUnitScope_Global, 0, cutoff, 0);
	AudioUnitSetParameter(this->filterUnit, kLowPassParam_Resonance, kAudioUnitScope_Global, 0, resonance, 0);
}

void convertLinearValue(float *value)
{
	float v = *value;
	*value = v * v;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	if (this->_note > 0)
	{
		applyFilterEnvelope(this, frames);
	}
	
	for (NSInteger i = 0; i < frames; i++)
	{
		float l = 0;
		float r = 0;
		
		if (this->_note > 0)
		{
			float amplitude = applyVolumeEnvelope(this);
			float frequency = applyFrequencyGlide(this);
			float angle = this->_angle + ((M_PI * 2.0) * frequency / this->_sampleRate);
			angle = fmodf(angle, M_PI * 2.0);
			float value = 0;
			
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
			
			convertLinearValue(&amplitude);
			
			l = value * amplitude;
			r = l;
			
			this->_currentFrequency = frequency;
			this->_noteTime += .001; // FIXME
			this->_angle = angle;
		}
		else
		{
			this->_noteTime = 0;
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_filterEnvelopeState = ConsumerEnvelopeStateMax;
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
		filterEnvelope = (ConsumerADSREnvelope){ .attack = 0.5, .decay = 0.5, .sustain = 0.5, .release = 0.5 };
		glide = 0;
		filterCutoff = 1.0;
		filterResonance = 0;
		filterPeak = 1.0;
		_sampleRate = sampleRate;
		_currentNote = 0;
		_note = 0;
		_noteTime = 0;
		_amplitudeEnvelopePosition = 0;
		_filterEnvelopePosition = 0;
	}
	
	return self;
}

- (void)setCurrentNote:(NSInteger)currentNote
{
	@synchronized (self)
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
