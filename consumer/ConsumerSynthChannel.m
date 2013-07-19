//
//  ConformSynthChannel.m
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerSynthChannel.h"
#import "ConsumerHelperFunctions.h"

#define PI2 6.28318530717958623200
#define TR2 1.05946309436
#define TR2I 0.94387431268

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
	float _osc1StartFrequency;
	float _osc1CurrentFrequency;
	float _osc1TargetFrequency;
	float _osc2StartFrequency;
	float _osc2CurrentFrequency;
	float _osc2TargetFrequency;
	float _osc1Angle;
	float _osc2Angle;
	float _lfoAngle;
	BOOL _angleReset;
	BOOL _noteChanged;
	BOOL _amplitudeEnvelopeActive;
	BOOL _filterEnvelopeActive;
	// filter params
	float _lastCutoff;
	float _a0;
	float _a1;
	float _a2;
	float _x1;
	float _x2;
	float _b1;
	float _b2;
	float _y1;
	float _y2;
	float _y3;
	float _y4;
	float _oldx;
	float _oldy1;
	float _oldy2;
	float _oldy3;
}

const NSInteger ConsumerMinStateLength = 100;
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
	
	if (input < (PI2 * width))
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
	float value = (input * 2.0) / PI2;
	return value - 1.0;
}

float applyVolumeEnvelope(ConsumerSynthChannel *this)
{
	float amplitude = 0;
	
	if ( ! this->_amplitudeEnvelopeActive)
	{
		this->_amplitudeEnvelopeState = ConsumerEnvelopeStateAttack;
		this->_amplitudeEnvelopePosition = 0;
		this->_amplitudeEnvelopeActive = YES;
	}

	if (this->_amplitudeEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->amplitudeEnvelope.attack * ConsumerMaxStateLength;
		if (attackLength < ConsumerMinStateLength)
		{
			attackLength = ConsumerMinStateLength;
		}
		
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
		if (decayLength < ConsumerMinStateLength)
		{
			decayLength = ConsumerMinStateLength;
		}

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
		if (releaseLength < ConsumerMinStateLength)
		{
			releaseLength = ConsumerMinStateLength;
		}

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
			this->_amplitudeEnvelopeActive = NO;
		}
	}
	
	return amplitude;
}

void applyFilterEnvelope(ConsumerSynthChannel *this, float *sample)
{
	if ( ! this->_filterEnvelopeActive)
	{
		this->_filterEnvelopeState = ConsumerEnvelopeStateAttack;
		this->_filterEnvelopeActive = YES;
	}
	
	float envelopeValue = 0;

	if (this->_filterEnvelopeState == ConsumerEnvelopeStateAttack)
	{
		float attackLength = this->filterEnvelope.attack * ConsumerMaxStateLength;
		if (attackLength < ConsumerMinStateLength)
		{
			attackLength = ConsumerMinStateLength;
		}

		if (this->_filterEnvelopePosition < attackLength)
		{
			envelopeValue = (this->_filterEnvelopePosition / attackLength) * this->filterPeak;
			this->_filterEnvelopePosition++;
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
		if (decayLength < ConsumerMinStateLength)
		{
			decayLength = ConsumerMinStateLength;
		}

		if (this->_filterEnvelopePosition < decayLength)
		{
			envelopeValue = this->filterPeak - ((this->_filterEnvelopePosition / decayLength) * (this->filterPeak - this->filterEnvelope.sustain));
			this->_filterEnvelopePosition++;
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
		if (releaseLength < ConsumerMinStateLength)
		{
			releaseLength = ConsumerMinStateLength;
		}
		
		if (this->_filterEnvelopePosition < releaseLength)
		{
			envelopeValue = this->filterEnvelope.sustain - ((this->_filterEnvelopePosition / releaseLength) * this->filterEnvelope.sustain);
			this->_filterEnvelopePosition++;
		}
		else
		{
			this->_amplitudeEnvelopeState = ConsumerEnvelopeStateMax;
			this->_filterEnvelopeActive = NO;
		}
	}
		
	float cutoffRange = 1.0 - this->filterCutoff;
	float cutoff = this->filterCutoff + (cutoffRange * envelopeValue);
	convertLinearValue(&cutoff);
	convertLinearValue(&cutoff);
	float resonance = this->filterResonance * envelopeValue;
	applyFilter(this, cutoff, resonance, &*sample);
}

void applyLowpassFilter(ConsumerSynthChannel *this, float cutoff, float resonance, float *sample)
{
	float x = *sample;
	cutoff *= 10000.0;
	
	if (fabs(cutoff - this->_lastCutoff) > 0.001)
	{
		float n = 1;
		float f0 = cutoff;
		float fs = this->_sampleRate;
		float c = powf(powf(2, 1.0f / n) - 1, -0.25);
		float g = 1;
		float p = sqrtf(2);
		float fp = c * (f0 / fs);
		float w0 = tanf(M_PI * fp);
		float k1 = p * w0;
		float k2 = g * w0 * w0;
		
		this->_a0 = k2 / (1 + k1 + k2);
		this->_a1 = 2 * this->_a0;
		this->_a2 = this->_a0;
		this->_b1 = 2 * this->_a0 * (1 / k2 - 1);
		this->_b2 = 1 - (this->_a0 + this->_a1 + this->_a2 + this->_b1);
		this->_lastCutoff = cutoff;
	}
	
	float y = this->_a0 * x + this->_a1 * this->_x1 + this->_a2 * this->_x2 + this->_b1 * this->_y1 + this->_b2 * this->_y2;
	this->_x1 = x;
	this->_x2 = this->_x1;
	this->_y2 = this->_y1;
	this->_y1 = y;

	*sample = y;
}

void applyResonantFilter(ConsumerSynthChannel *this, float cutoff, float resonance, float *sample)
{
	float x = *sample;
	cutoff *= 10000.0;
	
	float f = 2.0f * cutoff / this->_sampleRate;
	float k = 3.6f * f - 1.6f * f * f - 1;
	float p = (k + 1.0f) * 0.5f;
	float scale = powf(M_E, (1.0f - p) * 1.386249);
	float r = resonance * scale;
	
	float sampleOut = x - r * this->_y4;
	this->_y1 = sampleOut * p + this->_oldx * p - k * this->_y1;
	this->_y2 = this->_y1 * p + this->_oldy1 * p - k * this->_y2;
	this->_y3 = this->_y2 * p + this->_oldy2 * p - k * this->_y3;
	this->_y4 = this->_y3 * p + this->_oldy3 * p - k * this->_y4;
	this->_y4 = this->_y4 - (this->_y4 * this->_y4 * this->_y4) * 0.1666666667;
	this->_oldx = sampleOut;
	this->_oldy1 = this->_y1;
	this->_oldy2 = this->_y2;
	this->_oldy3 = this->_y3;
	
	*sample = sampleOut;
}

void applyFilter(ConsumerSynthChannel *this, float cutoff, float resonance, float *sample)
{
	applyLowpassFilter(this, cutoff, resonance, &*sample);
	applyResonantFilter(this, cutoff, resonance, &*sample);
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

void convertLinearValue(float *value)
{
	// FIXME: should be logarithmic
	float v = *value;
	*value = v * v;
}

void calculateSample(ConsumerSynthChannel *this, float *sample, float amplitude, float frequency, float originalFrequency, float *angle, ConsumerSynthWaveform waveform, float *currentFrequency, BOOL hardSync)
{
	float angle1 = *angle + (PI2 * frequency / this->_sampleRate);
	if (angle1 > PI2)
	{
		angle1 = fmodf(angle1, PI2);
	}
	
	if ( ! hardSync)
	{
		this->_angleReset = (angle1 < *angle);
	}
	
	if (hardSync && this->_angleReset)
	{
		angle1 = PI2 * frequency / this->_sampleRate;
	}
	
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
		*frequency = f * TR2I;
	}
	else if (detune > 0)
	{
		*frequency = f * TR2;
	}
}

void applyOctave(NSInteger octave, float *frequency)
{
	if (octave == 0)
	{
		return;
	}
	
	float freq = *frequency;
	if (octave < 0)
	{
		for (NSInteger i = 0; i < (-octave * 12); i++)
		{
			freq *= TR2I;
		}
	}
	else
	{
		for (NSInteger i = 0; i < (-octave * 12); i++)
		{
			freq *= TR2;
		}
	}
	
	*frequency = freq;
}

void applyLFO(float rate, float depth, float *angle, float *frequency, float sampleRate)
{
	float angle1 = *angle + (PI2 * rate / sampleRate);
	if (angle1 > PI2)
	{
		angle1 = fmodf(angle1, PI2);
	}
	
	float value = sinf(angle1);
	float range = *frequency * TR2I;
	*frequency += value * ((depth * 0.1) * range); // FIXME: fix depth range instead of multiplying by 0.1
	*angle = angle1;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
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
			calculateSample(this, &osc1, amplitude, detunedOsc1, osc1Freq, &this->_osc1Angle, this->oscillator1Waveform, &this->_osc1CurrentFrequency, NO);
			osc1 *= this->oscillator1Amplitude;
			
			float osc2 = 0;
			float osc2Freq = applyFrequencyGlide(this->glide, this->_osc2StartFrequency, this->_osc2CurrentFrequency, this->_osc2TargetFrequency, this->_note);
			float detunedOsc2 = osc2Freq;
			applyDetune(this->oscillator2Detune, &detunedOsc2);
			applyOctave(this->oscillator2Octave, &detunedOsc2);
			applyLFO(this->lfoRate, this->lfoDepth, &this->_lfoAngle, &detunedOsc2, this->_sampleRate);
			calculateSample(this, &osc2, amplitude, detunedOsc2, osc2Freq, &this->_osc2Angle, this->oscillator2Waveform, &this->_osc2CurrentFrequency, this->hardSync);
			osc2 *= this->oscillator2Amplitude;
			
			sample = osc1 + osc2;
			
			applyFilterEnvelope(this, &sample);
		}
		else
		{
			this->_amplitudeEnvelopeActive = NO;
			this->_filterEnvelopeActive = NO;
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
			_amplitudeEnvelopeActive = NO;
			_filterEnvelopeActive = NO;
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
