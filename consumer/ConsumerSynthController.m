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

@end
