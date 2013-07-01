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
		
		_synthChannel = [[ConsumerSynthChannel alloc] init];
		_synthChannel->sampleRate = _audioController.audioDescription.mSampleRate;
		
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
	self.synthChannel->currentNote = note;
}

@end
