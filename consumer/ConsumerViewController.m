//
//  ConsumerViewController.m
//  consumer
//
//  Created by Johan Halin on 1.7.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerViewController.h"
#import "ConsumerSynthController.h"

@class ConsumerKeyboardView;

@protocol ConsumerKeyboardViewDelegate <NSObject>

- (void)consumerKeyboard:(ConsumerKeyboardView *)keyboard updatedWithNote:(NSInteger)note;
- (void)consumerKeyboardEndedTouch:(ConsumerKeyboardView *)keyboard;

@end

@interface ConsumerKeyboardView : UIView
@property (nonatomic, weak) NSObject<ConsumerKeyboardViewDelegate> *delegate;
@end

@implementation ConsumerKeyboardView

#pragma mark - Private

- (void)_updateDelegateWithTouches:(NSSet *)touches
{
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];
	UIView *key = [self hitTest:location withEvent:nil];
	if (key != nil)
	{
		[self.delegate consumerKeyboard:self updatedWithNote:key.tag];
	}
}

#pragma mark - UIView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];

	[self _updateDelegateWithTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	
	[self _updateDelegateWithTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];

	[self.delegate consumerKeyboardEndedTouch:self];
}

@end

@interface ConsumerViewController () <ConsumerKeyboardViewDelegate>
@property (nonatomic) ConsumerKeyboardView *keyboardView;
@property (nonatomic, assign) NSInteger activeNote;
@property (nonatomic) ConsumerSynthController *synthController;
@end

@implementation ConsumerViewController

#pragma mark - Private

- (void)_createKeyboardLayout
{
	CGFloat keyWidth = CGRectGetWidth(self.keyboardView.bounds) / 8.0;
	
	for (NSInteger i = 0; i < 8; i++)
	{
		CGRect rect = CGRectMake(i * keyWidth,
								 CGRectGetHeight(self.keyboardView.bounds) / 2.0,
								 keyWidth,
								 CGRectGetHeight(self.keyboardView.bounds) / 2.0);
		UIView *keyView = [[UIView alloc] initWithFrame:rect];
		keyView.backgroundColor = (i % 2 == 0) ? [UIColor colorWithWhite:0.7 alpha:1.0] : [UIColor colorWithWhite:0.8 alpha:1.0];
		switch (i)
		{
			case 0:
				keyView.tag = 1;
				break;
			case 1:
				keyView.tag = 3;
				break;
			case 2:
				keyView.tag = 5;
				break;
			case 3:
				keyView.tag = 6;
				break;
			case 4:
				keyView.tag = 8;
				break;
			case 5:
				keyView.tag = 10;
				break;
			case 6:
				keyView.tag = 12;
				break;
			case 7:
				keyView.tag = 13;
				break;
			default:
				break;
		}
		[self.keyboardView addSubview:keyView];
	}
	
	for (NSInteger i = 0; i < 5; i++)
	{
		CGFloat offset = (i < 2) ? 0 : keyWidth;
		CGRect rect = CGRectMake((keyWidth / 2.0) + (i * keyWidth) + offset,
								 0,
								 keyWidth,
								 CGRectGetHeight(self.keyboardView.bounds) / 2.0);
		UIView *keyView = [[UIView alloc] initWithFrame:rect];
		keyView.backgroundColor = (i % 2 == 0) ? [UIColor colorWithWhite:0.4 alpha:1.0] : [UIColor colorWithWhite:0.3 alpha:1.0];
		switch (i)
		{
			case 0:
				keyView.tag = 2;
				break;
			case 1:
				keyView.tag = 4;
				break;
			case 2:
				keyView.tag = 7;
				break;
			case 3:
				keyView.tag = 9;
				break;
			case 4:
				keyView.tag = 11;
				break;
			default:
				break;
		}
		[self.keyboardView addSubview:keyView];
	}
}

#pragma mark - ConsumerKeyboardViewDelegate

- (void)consumerKeyboard:(ConsumerKeyboardView *)keyboard updatedWithNote:(NSInteger)note
{
	if (note == 0)
	{
		self.synthController.note = note;
	}
	else if (self.activeNote != note)
	{
		self.activeNote = note;
		self.synthController.note = note + 51;
		NSLog(@"%d", note);
	}
}

- (void)consumerKeyboardEndedTouch:(ConsumerKeyboardView *)keyboard
{
	self.activeNote = 0;
	self.synthController.note = 0;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.synthController = [[ConsumerSynthController alloc] init];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	CGFloat width = MAX(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
	CGFloat height = MIN(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
	
	self.keyboardView = [[ConsumerKeyboardView alloc] initWithFrame:CGRectMake(0, height / 2.0, width, height / 2.0)];
	self.keyboardView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.keyboardView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
	self.keyboardView.delegate = self;
	[self.view addSubview:self.keyboardView];
	
	[self _createKeyboardLayout];
}

@end
