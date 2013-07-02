//
//  SAMHUDView.m
//  SAMHUDView
//
//  Created by Sam Soffes on 9/29/09.
//  Copyright 2009-2013 Sam Soffes. All rights reserved.
//

#import "SAMHUDView.h"
#import "SAMHUDWindow.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat kIndicatorSize = 40.0;

@interface SAMHUDView ()
@property (nonatomic, strong) SAMHUDWindow *hudWindow;
@property (nonatomic, strong) UIWindow *keyWindow;

- (void)setTransformForCurrentOrientation:(BOOL)animated;
- (void)deviceOrientationChanged:(NSNotification *)notification;
- (void)removeWindow;
@end

@implementation SAMHUDView

#pragma mark - Accessors

@synthesize activityIndicator = _activityIndicator;
@synthesize textLabel = _textLabel;

- (void)setLoading:(BOOL)isLoading {
	_loading = isLoading;
	self.activityIndicator.alpha = _loading ? 1.0 : 0.0;
	[self setNeedsDisplay];
}


- (BOOL)hidesVignette {
	return self.hudWindow.hidesVignette;
}


- (void)setHidesVignette:(BOOL)hide {
	self.hudWindow.hidesVignette = hide;
}


- (UIActivityIndicatorView *)activityIndicator {
	if (!_activityIndicator) {
		_activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		_activityIndicator.alpha = 0.0;
	}
	return _activityIndicator;
}


- (UILabel *)textLabel {
	if (!_textLabel) {
		_textLabel = [[UILabel alloc] init];
		_textLabel.font = [UIFont boldSystemFontOfSize:14];
		_textLabel.backgroundColor = [UIColor clearColor];
		_textLabel.textColor = [UIColor whiteColor];
		_textLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.7f];
		_textLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		_textLabel.textAlignment = NSTextAlignmentCenter;
		_textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	}
	return _textLabel;
}


- (SAMHUDWindow *)hudWindow {
	if (!_hudWindow) {
		_hudWindow = [SAMHUDWindow defaultWindow];
	}
	return _hudWindow;
}


#pragma mark - NSObject

- (id)init {
	return (self = [self initWithTitle:nil loading:YES]);
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	[self removeWindow];
}


#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame {
	return (self = [self initWithTitle:nil loading:YES]);
}


- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();

	// Draw rounded rectangle
	CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 0.5f);
	CGRect rrect = CGRectMake(0.0f, 0.0f, self.hudSize.width, self.hudSize.height);
	[[UIBezierPath bezierPathWithRoundedRect:rrect cornerRadius:14.0f] fill];

	// Image
	if (self.loading == NO) {
		[[UIColor whiteColor] set];

		UIImage *image = self.successful ? self.completeImage : self.failImage;

		if (image) {
			CGSize imageSize = image.size;
			CGRect imageRect = CGRectMake(roundf((self.hudSize.width - imageSize.width) / 2.0f),
										  roundf((self.hudSize.height - imageSize.height) / 2.0f),
										  imageSize.width, imageSize.height);
			[image drawInRect:imageRect];
			return;
		}

		NSString *dingbat = self.successful ? @"✔" : @"✘";
		UIFont *dingbatFont = [UIFont systemFontOfSize:60.0f];
		CGSize dingbatSize = [dingbat sizeWithFont:dingbatFont];
		CGRect dingbatRect = CGRectMake(roundf((self.hudSize.width - dingbatSize.width) / 2.0f),
										roundf((self.hudSize.height - dingbatSize.height) / 2.0f),
										dingbatSize.width, dingbatSize.height);
		[dingbat drawInRect:dingbatRect withFont:dingbatFont lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
	}
}


- (void)layoutSubviews {
	self.activityIndicator.frame = CGRectMake(roundf((self.hudSize.width - kIndicatorSize) / 2.0f),
										  roundf((self.hudSize.height - kIndicatorSize) / 2.0f),
										  kIndicatorSize, kIndicatorSize);

	if (self.textLabel.hidden) {
		self.textLabel.frame = CGRectZero;
	} else {
		CGSize textSize = [self.textLabel.text sizeWithFont:self.textLabel.font constrainedToSize:CGSizeMake(self.bounds.size.width, CGFLOAT_MAX) lineBreakMode:self.textLabel.lineBreakMode];
		self.textLabel.frame = CGRectMake(0.0f, roundf(self.hudSize.height - textSize.height - 10.0f), self.hudSize.width, textSize.height);
	}
}


#pragma mark - HUD

- (id)initWithTitle:(NSString *)aTitle {
	return [self initWithTitle:aTitle loading:YES];
}


- (id)initWithTitle:(NSString *)aTitle loading:(BOOL)isLoading {
	if ((self = [super initWithFrame:CGRectZero])) {
		self.backgroundColor = [UIColor clearColor];

		self.hudSize = CGSizeMake(172.0f, 172.0f);

		// Activity indicator
		[self.activityIndicator startAnimating];
		[self addSubview:self.activityIndicator];

		// Text Label
		self.textLabel.text = aTitle ? aTitle : NSLocalizedString(@"Loading…", nil);
		[self addSubview:self.textLabel];

		// Loading
		self.loading = isLoading;

		// Images
		self.completeImage = [UIImage imageNamed:@"SAMHUDView-Check"];
		self.failImage = [UIImage imageNamed:@"SAMHUDView-X"];

        // Orientation
        [self setTransformForCurrentOrientation:NO];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
	}
	return self;
}


- (void)show {
	id<UIApplicationDelegate> delegate = [[UIApplication sharedApplication] delegate];
	if ([delegate respondsToSelector:@selector(window)]) {
        self.keyWindow = [delegate performSelector:@selector(window)];
	} else {
		// Unable to get main window from app delegate
		self.keyWindow = [[UIApplication sharedApplication] keyWindow];
	}

	self.hudWindow.alpha = 0.0f;
	self.alpha = 0.0f;
	[self.hudWindow addSubview:self];
	[self.hudWindow makeKeyAndVisible];

	[UIView beginAnimations:@"SAMHUDViewFadeInWindow" context:nil];
	self.hudWindow.alpha = 1.0f;
	[UIView commitAnimations];

	CGSize windowSize = self.hudWindow.frame.size;
	CGRect contentFrame = CGRectMake(roundf((windowSize.width - self.hudSize.width) / 2.0f),
									 roundf((windowSize.height - self.hudSize.height) / 2.0f) + 10.0f,
									 self.hudSize.width, self.hudSize.height);


    static CGFloat const offset = 20.0f;
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
		contentFrame.origin.y += offset;
    } else {
        contentFrame.origin.x += offset;
    }
	self.frame = contentFrame;

	[UIView beginAnimations:@"SAMHUDViewFadeInContentAlpha" context:nil];
	[UIView setAnimationDelay:0.1];
	[UIView setAnimationDuration:0.2];
	self.alpha = 1.0f;
	[UIView commitAnimations];

	[UIView beginAnimations:@"SAMHUDViewFadeInContentFrame" context:nil];
	[UIView setAnimationDelay:0.1];
	[UIView setAnimationDuration:0.3];
	self.frame = contentFrame;
	[UIView commitAnimations];
}


- (void)completeWithTitle:(NSString *)aTitle {
	self.successful = YES;
	self.loading = NO;
	self.textLabel.text = aTitle;
}


- (void)completeAndDismissWithTitle:(NSString *)aTitle {
	[self completeWithTitle:aTitle];
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self dismiss];
	});
}


- (void)completeQuicklyWithTitle:(NSString *)aTitle {
	[self completeWithTitle:aTitle];
	[self show];
	double delayInSeconds = 1.05;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self dismiss];
	});
}


- (void)failWithTitle:(NSString *)aTitle {
	self.successful = NO;
	self.loading = NO;
	self.textLabel.text = aTitle;
}


- (void)failAndDismissWithTitle:(NSString *)aTitle {
	[self failWithTitle:aTitle];
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self dismiss];
	});
}


- (void)failQuicklyWithTitle:(NSString *)aTitle {
	[self failWithTitle:aTitle];
	[self show];
	double delayInSeconds = 1.05;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self dismiss];
	});
}


- (void)dismiss {
	[self dismissAnimated:YES];
}


- (void)dismissAnimated:(BOOL)animated {
	[UIView beginAnimations:@"SAMHUDViewFadeOutContentFrame" context:nil];
	[UIView setAnimationDuration:0.2];
	CGRect contentFrame = self.frame;
    CGFloat offset = 20.0f;
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
		contentFrame.origin.y += offset;
    } else {
		contentFrame.origin.x += offset;
    }
	self.frame = contentFrame;
	[UIView commitAnimations];

	[UIView beginAnimations:@"SAMHUDViewFadeOutContentAlpha" context:nil];
	[UIView setAnimationDelay:0.1];
	[UIView setAnimationDuration:0.2];
	self.alpha = 0.0f;
	[UIView commitAnimations];

	[UIView beginAnimations:@"SAMHUDViewFadeOutWindow" context:nil];
	self.hudWindow.alpha = 0.0f;
	[UIView commitAnimations];

	if (animated) {
		double delayInSeconds = 0.3;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			[self removeWindow];
		});
	} else {
		[self removeWindow];
	}
}


#pragma mark - Private

- (void)setTransformForCurrentOrientation:(BOOL)animated {
	NSInteger degrees = 0;
	switch ([UIApplication sharedApplication].statusBarOrientation) {
		case UIInterfaceOrientationPortrait: {
			degrees = 0;
			break;
		}

		case UIInterfaceOrientationLandscapeLeft: {
			degrees = -M_PI_2;
			break;
		}

		case UIInterfaceOrientationLandscapeRight: {
			degrees = M_PI_2;
			break;
		}

		case UIInterfaceOrientationPortraitUpsideDown: {
			degrees = M_PI;
			break;
		}
	}

    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(degrees);

	if (animated) {
		[UIView beginAnimations:@"SAMHUDViewRotationTransform" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.3];
	}

	[self setTransform:rotationTransform];

    if (animated) {
		[UIView commitAnimations];
	}
}


- (void)deviceOrientationChanged:(NSNotification *)notification {
    [self setTransformForCurrentOrientation:YES];
	[self setNeedsDisplay];
}


- (void)removeWindow {
	[self.hudWindow resignKeyWindow];
	self.hudWindow = nil;

	// Return focus to the main window
	[self.keyWindow makeKeyWindow];
	self.keyWindow = nil;
}

@end