//
//  ConsumerViewController.m
//  consumer
//
//  Created by Johan Halin on 1.7.2013.
//  Copyright (c) 2013 Aero Deko. All rights reserved.
//

#import "ConsumerViewController.h"
#import "ConsumerSynthController.h"
#import "ConsumerSynthChannel.h"
#import <MessageUI/MessageUI.h>

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

@interface ConsumerViewController () <ConsumerKeyboardViewDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic) ConsumerKeyboardView *keyboardView;
@property (nonatomic, assign) NSInteger activeNote;
@property (nonatomic) ConsumerSynthController *synthController;
@property (nonatomic) IBOutlet UILabel *octaveLabel;
@property (nonatomic, assign) NSInteger octave;
@property (nonatomic) IBOutlet UILabel *osc1OctaveLabel;
@property (nonatomic) IBOutlet UILabel *osc2OctaveLabel;
@end

@implementation ConsumerViewController

#pragma mark - Private

- (void)_emailSettings:(UISwipeGestureRecognizer *)recognizer
{
	if ( ! [MFMailComposeViewController canSendMail])
	{
		return;
	}
	
	NSData *settings = [self.synthController serializeParametersToJSON];
	MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
	mailController.mailComposeDelegate = self;
	[mailController setSubject:@"Consumer synth settings"];
	[mailController setCcRecipients:@[@"johan@halin.me"]];
	[mailController addAttachmentData:settings mimeType:@"application/json" fileName:@"consumer_synth_settings.json"];
	[self presentViewController:mailController animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

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
		note += 3; // jeeeesus christ
		self.activeNote = note;
		self.synthController.note = note + (self.octave * 12);
	}
}

- (void)consumerKeyboardEndedTouch:(ConsumerKeyboardView *)keyboard
{
	self.activeNote = 0;
	self.synthController.note = -1;
}

#pragma mark - IBActions

- (IBAction)updatedOsc1Waveform:(id)sender
{
	if ([sender isKindOfClass:[UISegmentedControl class]])
	{
		UISegmentedControl *segControl = (UISegmentedControl *)sender;
		NSInteger value = segControl.selectedSegmentIndex;
		self.synthController.osc1Waveform = value;
	}
}

- (IBAction)osc1DetuneSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.osc1Detune = slider.value;
	}
}

- (IBAction)osc1AmplitudeSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.osc1Amplitude = slider.value;
	}
}

- (IBAction)osc1OctaveStepperValueChanged:(id)sender
{
	if ([sender isKindOfClass:[UIStepper class]])
	{
		UIStepper *stepper = (UIStepper *)sender;
		self.synthController.osc1Octave = (NSInteger)stepper.value;
		self.osc1OctaveLabel.text = [NSString stringWithFormat:@"%d", self.synthController.osc1Octave];
	}
}

- (IBAction)updatedOsc2Waveform:(id)sender
{
	if ([sender isKindOfClass:[UISegmentedControl class]])
	{
		UISegmentedControl *segControl = (UISegmentedControl *)sender;
		NSInteger value = segControl.selectedSegmentIndex;
		self.synthController.osc2Waveform = value;
	}
}

- (IBAction)osc2DetuneSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.osc2Detune = slider.value;
	}
}

- (IBAction)osc2AmplitudeSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.osc2Amplitude = slider.value;
	}
}

- (IBAction)osc2OctaveStepperValueChanged:(id)sender
{
	if ([sender isKindOfClass:[UIStepper class]])
	{
		UIStepper *stepper = (UIStepper *)sender;
		self.synthController.osc2Octave = (NSInteger)stepper.value;
		self.osc2OctaveLabel.text = [NSString stringWithFormat:@"%d", self.synthController.osc2Octave];
	}
}

- (IBAction)amplitudeAttackSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.amplitudeAttack = slider.value / 100.0;
	}
}

- (IBAction)amplitudeDecaySliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.amplitudeDecay = slider.value / 100.0;
	}
}

- (IBAction)amplitudeSustainSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.amplitudeSustain = slider.value / 100.0;
	}
}

- (IBAction)amplitudeReleaseSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.amplitudeRelease = slider.value / 100.0;
	}
}

- (IBAction)glideSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.glide = slider.value / 100.0;
	}
}

- (IBAction)filterCutoffSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterCutoff = slider.value;
	}
}

- (IBAction)filterResonanceSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterResonance = slider.value;
	}
}

- (IBAction)octaveStepperValueChanged:(id)sender
{
	if ([sender isKindOfClass:[UIStepper class]])
	{
		UIStepper *stepper = (UIStepper *)sender;
		self.octave = (NSInteger)stepper.value;
		self.octaveLabel.text = [NSString stringWithFormat:@"%d", self.octave];
	}
}

- (IBAction)keyboardToggleTouched:(id)sender
{
	self.keyboardView.hidden = !self.keyboardView.hidden;
}

- (IBAction)filterAttackSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterAttack = slider.value;
	}
}

- (IBAction)filterDecaySliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterDecay = slider.value;
	}
}

- (IBAction)filterSustainSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterSustain = slider.value;
	}
}

- (IBAction)filterReleaseSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterRelease = slider.value;
	}
}

- (IBAction)filterPeakSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.filterPeak = slider.value;
	}
}

- (IBAction)reverbSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.reverbDryWetMix = slider.value;
	}
}

- (IBAction)delaySliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.delayDryWetMix = slider.value;
	}
}

- (IBAction)lfoRateSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.lfoRate = slider.value;
	}
}

- (IBAction)lfoDepthSliderChanged:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider *slider = (UISlider *)sender;
		self.synthController.lfoDepth = slider.value;
	}
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(_emailSettings:)];
	[self.view addGestureRecognizer:swipeRecognizer];
	
	self.synthController = [[ConsumerSynthController alloc] init];
	self.octave = 4;
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
