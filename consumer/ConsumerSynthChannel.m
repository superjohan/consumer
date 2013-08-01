//
//  ConformSynthChannel.m
//  conform
//
//  Created by Johan Halin on 14.6.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerSynthChannel.h"
#import "ConsumerHelperFunctions.h"

#define EF         2.718281828459 // e
#define PI         3.141592653589 // pi
#define PI2        6.28318530717f // pi * 2
#define TR2        1.05946309436f // twelfth root of 2
#define TR2_I      0.94387431268f // 1 / TR2
#define SR_I       0.00002267573f // 1 / 44100
#define PI_I       0.31830988618f // 1 / pi
#define PI2_I      0.15915494309f // 1 / (pi * 2)
#define TABLE_SIZE 16384

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
	NSInteger _targetNote;
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
	float _noteChangeFadeoutTimer;
	float _sinTable[TABLE_SIZE];
	float _lastSample;
	BOOL _angleReset;
	BOOL _noteNeedsRestart;
	BOOL _amplitudeEnvelopeActive;
	BOOL _filterEnvelopeActive;
	BOOL _subOscFlipped;
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
const float ConsumerLFOMaxFrequency = 10.0f;

float noteFrequency(float note)
{
	return powf(2.0f, ((note - 49.0f) / 12.0f)) * 440.0f;
}

float noteFromFrequency(float frequency)
{
	return 12.0f * log2f(frequency / 440.0f) + 49.0f;
}

float square(float input, float width)
{
	if (width < 0.0f)
	{
		width = 0.0f;
	}
	else if (width > 1.0f)
	{
		width = 1.0f;
	}
		
	if (input < (PI2 * width))
	{
		return 1.0f;
	}
	else
	{
		return -1.0f;
	}
}

float triangle(float input)
{
	if (input < PI)
	{
		float value = (input * 2.0f) * PI_I;
		return value - 1.0f;
	}
	else
	{
		float value = ((input - PI) * 2.0f) * PI_I;
		return 1.0f - value;
	}
}

float saw(float input)
{
	float value = (input * 2.0f) * PI2_I;
	return value - 1.0f;
}

float applyVolumeEnvelope(ConsumerSynthChannel *this)
{
	float amplitude = 0.0f;
	
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
			amplitude = 1.0f - ((this->_amplitudeEnvelopePosition / decayLength) * (1.0f - this->amplitudeEnvelope.sustain));
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
			this->_filterEnvelopeState = ConsumerEnvelopeStateMax;
			this->_filterEnvelopeActive = NO;
		}
	}
		
	float cutoffRange = 1.0f - this->filterCutoff;
	float cutoff = this->filterCutoff + (cutoffRange * envelopeValue);
	convertLinearValue(&cutoff);
	convertLinearValue(&cutoff);
	float resonance = this->filterResonance * envelopeValue;
	applyFilter(this, cutoff, resonance, &*sample);
}

void applyLowpassFilter(ConsumerSynthChannel *this, float cutoff, float resonance, float *sample)
{
	float x = *sample;
	cutoff *= 10000.0f;
	
	if (fabs(cutoff - this->_lastCutoff) > 0.001f)
	{
		float f0 = cutoff;
		float fs = SR_I;
		float p = 1.414213562f;
		float fp = f0 * fs;
		float w0 = tanf(PI * fp);
		float k1 = p * w0;
		float k2 = w0 * w0;
		
		this->_a0 = k2 / (1.0f + k1 + k2);
		this->_a1 = 2.0f * this->_a0;
		this->_a2 = this->_a0;
		this->_b1 = 2.0f * this->_a0 * (1.0f / k2 - 1.0f);
		this->_b2 = 1.0f - (this->_a0 + this->_a1 + this->_a2 + this->_b1);
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
	cutoff *= 10000.0f;
	
	float f = 2.0f * cutoff * SR_I;
	float k = 3.6f * f - 1.6f * f * f - 1.0f;
	float p = (k + 1.0f) * 0.5f;
	float scale = powf(EF, (1.0f - p) * 1.386249f);
	float r = resonance * scale;
	
	float sampleOut = x - r * this->_y4;
	this->_y1 = sampleOut * p + this->_oldx * p - k * this->_y1;
	this->_y2 = this->_y1 * p + this->_oldy1 * p - k * this->_y2;
	this->_y3 = this->_y2 * p + this->_oldy2 * p - k * this->_y3;
	this->_y4 = this->_y3 * p + this->_oldy3 * p - k * this->_y4;
	this->_y4 = this->_y4 - (this->_y4 * this->_y4 * this->_y4) * 0.1666666667f;
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
	
	float frequency = 0.0f;
	
	if ( ! floatsAreEqual(currentFrequency, targetFrequency))
	{
		if (glide > 0.0f)
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
		frequency = targetFrequency;
	}
	
	return frequency;
}

void convertLinearValue(float *value)
{
	// FIXME: should be logarithmic
	float v = *value;
	*value = v * v;
}

void calculateSample(ConsumerSynthChannel *this, float *sample, float frequency, float originalFrequency, float *angle, ConsumerSynthWaveform waveform, float *currentFrequency, BOOL hardSync)
{
	float angle1 = *angle + (PI2 * frequency * SR_I);
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
		angle1 = PI2 * frequency * SR_I;
	}
	
	float value = 0.0f;
	
	if (waveform == ConsumerSynthWaveformSine)
	{
		NSInteger index = (int)(TABLE_SIZE * (angle1 * PI2_I));
		value = this->_sinTable[index];
	}
	else if (waveform == ConsumerSynthWaveformSquare)
	{
		value = square(angle1, 0.5f);
	}
	else if (waveform == ConsumerSynthWaveformTriangle)
	{
		value = triangle(angle1);
	}
	else if (waveform == ConsumerSynthWaveformSaw)
	{
		value = saw(angle1);
	}
		
	*sample = value;
	*currentFrequency = originalFrequency;
	*angle = angle1;
}

void applyDetune(float detune, float *frequency)
{
	if (detune < 0.0f)
	{
		*frequency *= -detune * TR2_I;
	}
	else if (detune > 0.0f)
	{
		*frequency *= detune * TR2;
	}
}

void applyOctave(NSInteger octave, float *frequency)
{
	if (octave == 0)
	{
		return;
	}
	
	if (octave < 0)
	{
		for (NSInteger i = 0; i < (-octave * 12); i++)
		{
			*frequency *= TR2_I;
		}
	}
	else if (octave > 0)
	{
		for (NSInteger i = 0; i < (octave * 12); i++)
		{
			*frequency *= TR2;
		}
	}
}

void applyLFO(float *sinTable, float rate, float depth, float *angle, float *frequency)
{
	float angle1 = *angle + (PI2 * rate * SR_I);
	if (angle1 > PI2)
	{
		angle1 = fmodf(angle1, PI2);
	}
	
	NSInteger index = (int)(TABLE_SIZE * (angle1 * PI2_I));
	float value = sinTable[index];
	float range = *frequency * TR2_I;
	*frequency += value * ((depth * 0.1f) * range); // FIXME: fix depth range instead of multiplying by 0.1
	*angle = angle1;
}

void resetFrequencies(ConsumerSynthChannel *this)
{
	this->_osc1StartFrequency = this->_osc1CurrentFrequency;
	this->_osc1TargetFrequency = noteFrequency(this->_currentNote);
	
	this->_osc2StartFrequency = this->_osc2CurrentFrequency;
	this->_osc2TargetFrequency = noteFrequency(this->_currentNote);
}

void applyFadeout(ConsumerSynthChannel *this, float *amplitude)
{
	this->_noteChangeFadeoutTimer += .005f;
	*amplitude *= (1.0f - this->_noteChangeFadeoutTimer);
	
	if (this->_noteChangeFadeoutTimer >= 1.0f)
	{
		*amplitude = 0;
		resetFrequencies(this);
		this->_noteChangeFadeoutTimer = 0;
		this->_note = this->_targetNote;
		this->_amplitudeEnvelopeActive = NO;
		this->_filterEnvelopeActive = NO;
		this->_noteNeedsRestart = NO;
	}
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	for (NSInteger i = 0; i < frames; i++)
	{
		float sample = 0;
		
		if (this->_note > 0)
		{
			float amplitude = applyVolumeEnvelope(this);
			if (this->_noteNeedsRestart || this->_note != this->_targetNote)
			{
				applyFadeout(this, &amplitude);
			}
			
			float osc1 = 0;
			float osc1Freq = applyFrequencyGlide(this->glide, this->_osc1StartFrequency, this->_osc1CurrentFrequency, this->_osc1TargetFrequency, this->_note);
			float detunedOsc1 = osc1Freq;
			applyDetune(this->oscillator1Detune, &detunedOsc1);
			applyOctave(this->oscillator1Octave, &detunedOsc1);
			applyLFO(this->_sinTable, this->lfoRate, this->lfoDepth, &this->_lfoAngle, &detunedOsc1);
			calculateSample(this, &osc1, detunedOsc1, osc1Freq, &this->_osc1Angle, this->oscillator1Waveform, &this->_osc1CurrentFrequency, NO);
			float osc1amp = this->oscillator1Amplitude;
			convertLinearValue(&osc1amp);
			osc1 *= osc1amp;
	
			float osc2 = 0;
			float osc2Freq = applyFrequencyGlide(this->glide, this->_osc2StartFrequency, this->_osc2CurrentFrequency, this->_osc2TargetFrequency, this->_note);
			float detunedOsc2 = osc2Freq;
			applyDetune(this->oscillator2Detune, &detunedOsc2);
			applyOctave(this->oscillator2Octave, &detunedOsc2);
			applyLFO(this->_sinTable, this->lfoRate, this->lfoDepth, &this->_lfoAngle, &detunedOsc2);
			calculateSample(this, &osc2, detunedOsc2, osc2Freq, &this->_osc2Angle, this->oscillator2Waveform, &this->_osc2CurrentFrequency, this->hardSync);
			float osc2amp = this->oscillator2Amplitude;
			convertLinearValue(&osc2amp);
			osc2 *= osc2amp;
			
			sample = osc1 + osc2;
			float lastSample = this->_lastSample;
			this->_lastSample = sample;
			
			if (this->subOsc)
			{
				if (lastSample < -.0000001 && sample >= -.0000001)
				{
					this->_subOscFlipped = !this->_subOscFlipped;
				}
				
				if (this->_subOscFlipped)
				{
					sample += this->subOscAmplitude;
				}
				else
				{
					sample -= this->subOscAmplitude;
				}
			}
			
			// apply amplitude envelope
			convertLinearValue(&amplitude);
			sample *= amplitude;
			
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
			this->_noteChangeFadeoutTimer = 0;
		}
		
		clampChannel(&sample, 1.0f);
		float volume = this->volume;
		convertLinearValue(&volume);
		sample *= volume;
		
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
		oscillator1Amplitude = 0.5f;
		oscillator1Octave = 0;
		oscillator2Waveform = ConsumerSynthWaveformSine;
		oscillator2Detune = 0;
		oscillator2Amplitude = 0.5f;
		oscillator2Octave = 0;
		amplitudeEnvelope = (ConsumerADSREnvelope){ .attack = 0.5f, .decay = 0.5f, .sustain = 0.5f, .release = 0.5f };
		filterEnvelope = (ConsumerADSREnvelope){ .attack = 0.5f, .decay = 0.5f, .sustain = 0.5f, .release = 0.5f };
		glide = 0;
		filterCutoff = 1.0f;
		filterResonance = 0;
		filterPeak = 1.0f;
		lfoRate = 0;
		lfoDepth = 0;
		subOscAmplitude = 0.2;
		volume = 1.0f;
		_sampleRate = sampleRate;
		_currentNote = 0;
		_note = 0;
		_amplitudeEnvelopePosition = 0;
		_filterEnvelopePosition = 0;
		
		// generate wavetables
		for (NSInteger i = 0; i < TABLE_SIZE; i++)
		{
			_sinTable[i] = sinf((i / (float)TABLE_SIZE) * (PI * 2.0f));
		}
	}
	
	return self;
}

- (void)setCurrentNote:(NSInteger)currentNote
{
	@synchronized (self)
	{
		NSInteger previousNote = _currentNote;
		_currentNote = currentNote;

		if (_currentNote != ConsumerNoteOff)
		{
			_targetNote = _currentNote;
			
			if (_targetNote == _note)
			{
				_noteNeedsRestart = YES;
			}
			
			if (_note <= 0 || previousNote > 0)
			{
				resetFrequencies(self);
				_note = _currentNote;
			}
		}
	}
}

@end
