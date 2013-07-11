//
//  ConsumerSynthController.m
//  consumer
//
//  Created by Johan Halin on 1.7.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerSynthController.h"
#import "ConsumerSynthChannel.h"
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

@interface ConsumerSynthController ()
@property (nonatomic) AEAudioController *audioController;
@property (nonatomic) ConsumerSynthChannel *synthChannel;
@property (nonatomic) AEAudioUnitFilter *reverbFilter;
@property (nonatomic) AEAudioUnitFilter *delayFilter;
@end

@implementation ConsumerSynthController

- (instancetype)init
{
	if ((self = [super init]))
	{
		_audioController = [[AEAudioController alloc] initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]];
		_synthChannel = [[ConsumerSynthChannel alloc] initWithSampleRate:_audioController.audioDescription.mSampleRate];
		[_audioController addChannels:[NSArray arrayWithObject:_synthChannel]];

		AudioComponentDescription filterComponent = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Effect, kAudioUnitSubType_LowPassFilter);
		NSError *filterError = nil;
		AEAudioUnitFilter *lowpassFilter = [[AEAudioUnitFilter alloc] initWithComponentDescription:filterComponent audioController:_audioController error:&filterError];
		if (lowpassFilter == nil)
		{
			NSLog(@"Error creating filter: %@", filterError);
			return nil;
		}
	
		AudioUnitSetParameter(lowpassFilter.audioUnit, kLowPassParam_CutoffFrequency, kAudioUnitScope_Global, 0, _audioController.audioDescription.mSampleRate / 2, 0);
		AudioUnitSetParameter(lowpassFilter.audioUnit, kLowPassParam_Resonance, kAudioUnitScope_Global, 0, 0.0, 0);
		
		_synthChannel->filterUnit = lowpassFilter.audioUnit;
		
		AudioComponentDescription delayComponent = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Effect, kAudioUnitSubType_Delay);
		NSError *delayError = nil;
		_delayFilter = [[AEAudioUnitFilter alloc] initWithComponentDescription:delayComponent audioController:_audioController error:&delayError];
		if (_delayFilter == nil)
		{
			NSLog(@"Error creating delay: %@", delayError);
		}
		
		AudioUnitSetParameter(_delayFilter.audioUnit, kDelayParam_WetDryMix, kAudioUnitScope_Global, 0, 0, 0);
		AudioUnitSetParameter(_delayFilter.audioUnit, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, 0.3, 0);
		
		AudioComponentDescription reverbComponent = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Effect, kAudioUnitSubType_Reverb2);
		NSError *reverbError = nil;
		_reverbFilter = [[AEAudioUnitFilter alloc] initWithComponentDescription:reverbComponent audioController:_audioController error:&reverbError];
		if (_reverbFilter == nil)
		{
			NSLog(@"Error creating reverb: %@", reverbError);
		}
		
		AudioUnitSetParameter(_reverbFilter.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 0, 0);
		AudioUnitSetParameter(_reverbFilter.audioUnit, kReverb2Param_DecayTimeAt0Hz, kAudioUnitScope_Global, 0, 3.0, 0);
		AudioUnitSetParameter(_reverbFilter.audioUnit, kReverb2Param_DecayTimeAtNyquist, kAudioUnitScope_Global, 0, 3.0, 0);

		[_audioController addFilter:_reverbFilter toChannel:(id<AEAudioPlayable>)_synthChannel];
		[_audioController addFilter:_delayFilter toChannel:(id<AEAudioPlayable>)_synthChannel];
		[_audioController addFilter:lowpassFilter toChannel:(id<AEAudioPlayable>)_synthChannel];

		NSError *error = nil;
		if ( ! [_audioController start:&error])
		{
			NSLog(@"%@", error);
			return nil;
		}
	}
	
	return self;
}

#pragma mark - Properties

- (void)setNote:(NSInteger)note
{
	_note = note;
	self.synthChannel.currentNote = note;
}

- (void)setOsc1Waveform:(ConsumerSynthWaveform)waveform
{
	_osc1Waveform = waveform;
	self.synthChannel->oscillator1Waveform = waveform;
}

- (void)setOsc1Detune:(float)osc1Detune
{
	if (osc1Detune < -1.0 || osc1Detune > 1.0)
	{
		return;
	}
	
	_osc1Detune = osc1Detune;
	self.synthChannel->oscillator1Detune = osc1Detune;
}

- (void)setOsc1Amplitude:(float)osc1Amplitude
{
	if (osc1Amplitude < 0 || osc1Amplitude > 1.0)
	{
		return;
	}
	
	_osc1Amplitude = osc1Amplitude;
	self.synthChannel->oscillator1Amplitude = osc1Amplitude;
}

- (void)setOsc1Octave:(NSInteger)osc1Octave
{
	if (osc1Octave < -2 || osc1Octave > 2)
	{
		return;
	}
	
	_osc1Octave = osc1Octave;
	self.synthChannel->oscillator1Octave = osc1Octave;
}

- (void)setOsc2Waveform:(ConsumerSynthWaveform)waveform
{
	_osc2Waveform = waveform;
	self.synthChannel->oscillator2Waveform = waveform;
}

- (void)setOsc2Detune:(float)osc2Detune
{
	if (osc2Detune < -1.0 || osc2Detune > 1.0)
	{
		return;
	}
	
	_osc2Detune = osc2Detune;
	self.synthChannel->oscillator2Detune = osc2Detune;
}

- (void)setOsc2Amplitude:(float)osc2Amplitude
{
	if (osc2Amplitude < 0 || osc2Amplitude > 1.0)
	{
		return;
	}
	
	_osc2Amplitude = osc2Amplitude;
	self.synthChannel->oscillator2Amplitude = osc2Amplitude;
}

- (void)setOsc2Octave:(NSInteger)osc2Octave
{
	if (osc2Octave < -2 || osc2Octave > 2)
	{
		return;
	}
	
	_osc2Octave = osc2Octave;
	self.synthChannel->oscillator2Octave = osc2Octave;
}

- (void)setAmplitudeAttack:(float)amplitudeAttack
{
	if (amplitudeAttack < 0 || amplitudeAttack > 1.0)
	{
		return;
	}
	
	_amplitudeAttack = amplitudeAttack;
	self.synthChannel->amplitudeEnvelope.attack = amplitudeAttack;
}

- (void)setAmplitudeDecay:(float)amplitudeDecay
{
	if (amplitudeDecay < 0 || amplitudeDecay > 1.0)
	{
		return;
	}
	
	_amplitudeDecay = amplitudeDecay;
	self.synthChannel->amplitudeEnvelope.decay = amplitudeDecay;
}

- (void)setAmplitudeSustain:(float)amplitudeSustain
{
	if (amplitudeSustain < 0 || amplitudeSustain > 1.0)
	{
		return;
	}
	
	_amplitudeSustain = amplitudeSustain;
	self.synthChannel->amplitudeEnvelope.sustain = amplitudeSustain;
}

- (void)setAmplitudeRelease:(float)amplitudeRelease
{
	if (amplitudeRelease < 0 || amplitudeRelease > 1.0)
	{
		return;
	}
	
	_amplitudeRelease = amplitudeRelease;
	self.synthChannel->amplitudeEnvelope.release = amplitudeRelease;
}

- (void)setGlide:(float)glide
{
	if (glide < 0 || glide > 1.0)
	{
		return;
	}
	
	_glide = glide;
	self.synthChannel->glide = glide;
}

- (void)setFilterCutoff:(float)filterCutoff
{
	if (filterCutoff < 0 || filterCutoff > 1.0)
	{
		return;
	}
	
	_filterCutoff = filterCutoff;
	self.synthChannel->filterCutoff = filterCutoff;
}

- (void)setFilterResonance:(float)filterResonance
{
	if (filterResonance < -0.5 || filterResonance > 1.0)
	{
		return;
	}
	
	_filterResonance = filterResonance;
	self.synthChannel->filterResonance = filterResonance;
}

- (void)setFilterAttack:(float)filterAttack
{
	if (filterAttack < 0 || filterAttack > 1.0)
	{
		return;
	}
	
	_filterAttack = filterAttack;
	self.synthChannel->filterEnvelope.attack = filterAttack;
}

- (void)setFilterDecay:(float)filterDecay
{
	if (filterDecay < 0 || filterDecay > 1.0)
	{
		return;
	}
	
	_filterDecay = filterDecay;
	self.synthChannel->filterEnvelope.decay = filterDecay;
}

- (void)setFilterSustain:(float)filterSustain
{
	if (filterSustain < 0 || filterSustain > 1.0)
	{
		return;
	}
	
	_filterSustain = filterSustain;
	self.synthChannel->filterEnvelope.sustain = filterSustain;
}

- (void)setFilterRelease:(float)filterRelease
{
	if (filterRelease < 0 || filterRelease > 1.0)
	{
		return;
	}
	
	_filterRelease = filterRelease;
	self.synthChannel->filterEnvelope.release = filterRelease;
}

- (void)setFilterPeak:(float)filterPeak
{
	if (filterPeak < 0 || filterPeak > 1.0)
	{
		return;
	}
	
	_filterPeak = filterPeak;
	self.synthChannel->filterPeak = filterPeak;
}

- (void)setReverbDryWetMix:(float)reverbDryWetMix
{
	if (reverbDryWetMix < 0 || reverbDryWetMix > 1.0)
	{
		return;
	}
	
	_reverbDryWetMix = reverbDryWetMix;

	AudioUnitSetParameter(self.reverbFilter.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, reverbDryWetMix * 100.0, 0);
}

- (void)setDelayDryWetMix:(float)delayDryWetMix
{
	if (delayDryWetMix < 0 || delayDryWetMix > 1.0)
	{
		return;
	}
	
	_delayDryWetMix = delayDryWetMix;
	
	AudioUnitSetParameter(self.delayFilter.audioUnit, kDelayParam_WetDryMix, kAudioUnitScope_Global, 0, delayDryWetMix * 100.0, 0);
}

#pragma mark - Public

- (void)configure
{
	// TODO?
}

@end
