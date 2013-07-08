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
		
		[_audioController addFilter:lowpassFilter toChannel:(id<AEAudioPlayable>)_synthChannel];
		
		_synthChannel->filterUnit = lowpassFilter.audioUnit;
		
		NSError *error = nil;
		if ( ! [_audioController start:&error])
		{
			NSLog(@"%@", error);
			return nil;
		}
	}
	
	return self;
}

- (void)setNote:(NSInteger)note
{
	self.synthChannel.currentNote = note;
}

- (void)setWaveform:(ConsumerSynthWaveform)waveform
{
	self.synthChannel->oscillator1Waveform = waveform;
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

@end
