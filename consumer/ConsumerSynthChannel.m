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
	float _osc1StartFrequency;
	float _osc1CurrentFrequency;
	float _osc1TargetFrequency;
	float _osc2StartFrequency;
	float _osc2CurrentFrequency;
	float _osc2TargetFrequency;
	float _osc1Angle;
	float _osc2Angle;
	float _lfoAngle;
}

const NSInteger ConsumerMaxStateLength = 44100;
const float ConsumerLFOMaxFrequency = 10.0;

float noteFrequency(float note)
{
	return powf(2.0, ((note - 49.0) / 12.0)) * 440.0;
}

float noteFromFrequency(float frequency)
{
	return 12.0 * log2f(frequency / 440.0) + 49.0;
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
		return 1.0;
	}
	else
	{
		return -1.0;
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
	
	float envelopeValue = 0;

	if (this->_filterEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->filterEnvelope.attack * ConsumerMaxStateLength;
		
		if (this->_filterEnvelopePosition < attackLength)
		{
			envelopeValue = (this->_filterEnvelopePosition / attackLength) * this->filterPeak;
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
			envelopeValue = this->filterPeak - ((this->_filterEnvelopePosition / decayLength) * (this->filterPeak - this->filterEnvelope.sustain));
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
		envelopeValue = this->filterEnvelope.sustain;
		
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
			envelopeValue = this->filterEnvelope.sustain - ((this->_filterEnvelopePosition / releaseLength) * this->filterEnvelope.sustain);
			this->_filterEnvelopePosition += frames;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
		}
	}
		
	float cutoffRange = 1.0 - this->filterCutoff;
	float cutoff = this->filterCutoff + (cutoffRange * envelopeValue);
	convertLinearValue(&cutoff);
	convertLinearValue(&cutoff);
	float finalCutoff = (float)(this->_sampleRate / 2) * cutoff;
	float resonance = this->filterResonance * envelopeValue;
	float finalResonance = 40.0 * resonance;
	applyFilter(this, finalCutoff, finalResonance);
}

float applyFrequencyGlide(float glide, float startFrequency, float currentFrequency, float targetFrequency, NSInteger note)
{
	if (note == 0) // band aid for threading issues...
	{
		return currentFrequency;
	}
	
	float frequency = 0;
	
	if ( ! floatsAreEqual(currentFrequency, targetFrequency))
	{
		if (glide > 0)
		{
			float diff = targetFrequency - startFrequency;
			float timeDiff = glide * ConsumerMaxStateLength;
			float frequencyStep = diff / timeDiff;
			frequency = currentFrequency + frequencyStep;
		}
		else
		{
			frequency = targetFrequency;
		}
		
		if ((targetFrequency > startFrequency && frequency > targetFrequency) || (targetFrequency < startFrequency && frequency < targetFrequency))
		{
			frequency = targetFrequency;
		}
	}
	else
	{
		frequency = noteFrequency(note);
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
	// FIXME: should be logarithmic
	float v = *value;
	*value = v * v;
}

void calculateSample(ConsumerSynthChannel *this, float *sample, float amplitude, float frequency, float originalFrequency, float *angle, ConsumerSynthWaveform waveform, float *currentFrequency)
{
	float angle1 = *angle + ((M_PI * 2.0) * frequency / this->_sampleRate);
	angle1 = fmodf(angle1, M_PI * 2.0);
	float value = 0;
	
	if (waveform == ConsumerSynthWaveformSine)
	{
		value = sinf(angle1);
	}
	else if (waveform == ConsumerSynthWaveformSquare)
	{
		value = square(angle1, 0.5);
	}
	else if (waveform == ConsumerSynthWaveformTriangle)
	{
		value = triangle(angle1);
	}
	else if (waveform == ConsumerSynthWaveformSaw)
	{
		value = saw(angle1);
	}
	
	convertLinearValue(&amplitude);
	
	*sample = value * amplitude;
	*currentFrequency = originalFrequency;
	*angle = angle1;
}

void applyDetune(float detune, float *frequency)
{
	float f = *frequency;
	
	if (detune < 0)
	{
		float currentNote = noteFromFrequency(f);
		float min = noteFrequency(currentNote - 1.0);
		float freq = ((min / f) * detune) * (min - f);
		*frequency = f - freq;
	}
	else if (detune > 0)
	{
		float currentNote = noteFromFrequency(f);
		float max = noteFrequency(currentNote + 1.0);
		float freq = ((max / f) * detune) * (max - f);
		*frequency = f + freq;
	}
}

void applyOctave(NSInteger octave, float *frequency)
{
	if (octave == 0)
	{
		return;
	}
	
	float note = noteFromFrequency(*frequency);
	float freq = noteFrequency(note + (octave * 12));
	*frequency = freq;
}

void applyLFO(float rate, float depth, float *angle, float *frequency, float sampleRate)
{
	float angle1 = *angle + ((M_PI * 2.0) * rate / sampleRate);
	angle1 = fmodf(angle1, M_PI * 2.0);
	float value = sinf(angle1);
	float note = noteFromFrequency(*frequency);
	float range = note - noteFrequency(note);
	*frequency += value * ((depth * 0.1) * range); // FIXME: fix depth range instead of multiplying by 0.1
	*angle = angle1;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	if (this->_note > 0)
	{
		// TODO: move to main sample calculation loop when using own filter implementation
		applyFilterEnvelope(this, frames);
	}
	
	for (NSInteger i = 0; i < frames; i++)
	{
		float sample = 0;
		
		if (this->_note > 0)
		{
			float amplitude = applyVolumeEnvelope(this);
			
			float osc1 = 0;
			float osc1Freq = applyFrequencyGlide(this->glide, this->_osc1StartFrequency, this->_osc1CurrentFrequency, this->_osc1TargetFrequency, this->_note);
			float detunedOsc1 = osc1Freq;
			applyDetune(this->oscillator1Detune, &detunedOsc1);
			applyOctave(this->oscillator1Octave, &detunedOsc1);
			applyLFO(this->lfoRate, this->lfoDepth, &this->_lfoAngle, &detunedOsc1, this->_sampleRate);
			calculateSample(this, &osc1, amplitude, detunedOsc1, osc1Freq, &this->_osc1Angle, this->oscillator1Waveform, &this->_osc1CurrentFrequency);
			osc1 *= this->oscillator1Amplitude;
			
			float osc2 = 0;
			float osc2Freq = applyFrequencyGlide(this->glide, this->_osc2StartFrequency, this->_osc2CurrentFrequency, this->_osc2TargetFrequency, this->_note);
			float detunedOsc2 = osc2Freq;
			applyDetune(this->oscillator2Detune, &detunedOsc2);
			applyOctave(this->oscillator2Octave, &detunedOsc2);
			applyLFO(this->lfoRate, this->lfoDepth, &this->_lfoAngle, &detunedOsc2, this->_sampleRate);
			calculateSample(this, &osc2, amplitude, detunedOsc2, osc2Freq, &this->_osc2Angle, this->oscillator2Waveform, &this->_osc2CurrentFrequency);
			osc2 *= this->oscillator2Amplitude;
			
			sample = osc1 + osc2;
			
			this->_noteTime += .001; // FIXME
		}
		else
		{
			this->_noteTime = 0;
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_filterEnvelopeState = ConsumerEnvelopeStateMax;
			this->_osc1Angle = 0;
			this->_osc2Angle = 0;
			this->_lfoAngle = 0;
		}
		
		clampChannel(&sample, 1.0);
		
		((float *)audio->mBuffers[0].mData)[i] = sample;
		((float *)audio->mBuffers[1].mData)[i] = sample;
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
		oscillator1Detune = 0;
		oscillator1Amplitude = 0.5;
		oscillator1Octave = 0;
		oscillator2Waveform = ConsumerSynthWaveformSine;
		oscillator2Detune = 0;
		oscillator2Amplitude = 0.5;
		oscillator2Octave = 0;
		amplitudeEnvelope = (ConsumerADSREnvelope){ .attack = 0.5, .decay = 0.5, .sustain = 0.5, .release = 0.5 };
		filterEnvelope = (ConsumerADSREnvelope){ .attack = 0.5, .decay = 0.5, .sustain = 0.5, .release = 0.5 };
		glide = 0;
		filterCutoff = 1.0;
		filterResonance = 0;
		filterPeak = 1.0;
		lfoRate = 0;
		lfoDepth = 0;
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
			_osc1StartFrequency = _osc1CurrentFrequency;
			_osc1TargetFrequency = noteFrequency(_currentNote);

			_osc2StartFrequency = _osc2CurrentFrequency;
			_osc2TargetFrequency = noteFrequency(_currentNote);
			
			_note = _currentNote;
		}
	}
}

@end
