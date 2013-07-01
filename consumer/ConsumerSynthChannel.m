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

@interface ConsumerSynthChannel () <AEAudioPlayable>
@property (nonatomic, assign) NSUInteger position;
@property (nonatomic, assign) NSUInteger step;
@property (nonatomic, assign) NSInteger previousNote;
@property (nonatomic, assign) NSInteger notePosition;
@end

@implementation ConsumerSynthChannel

float noteFrequency(NSInteger note)
{
	return powf(2.0, ((note - 49.0) / 12.0)) * 440.0;
}

static OSStatus renderCallback(ConsumerSynthChannel *this, AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio)
{
	for (NSInteger i = 0; i < frames; i++)
	{
		float l = 0;
		float r = 0;
		
		if (this->currentNote > 0)
		{
			NSInteger note = this->currentNote;
			float value = 0;
			if (note > 0)
			{
				float frequency = noteFrequency(note);
				value = sinf((M_PI * 2.0) * ((this->_notePosition / this->sampleRate) * frequency));
				
				l = value;
				r = l;
				this->_notePosition++;
			}
		}
		
		clampStereo(&l, &r, 1.0);
		
		((float *)audio->mBuffers[0].mData)[i] = l;
		((float *)audio->mBuffers[1].mData)[i] = r;
		
		this->_position++;
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
		_position = NSUIntegerMax;
		_step = NSUIntegerMax;
		currentNote = 0;
	}
	
	return self;
}

@end
