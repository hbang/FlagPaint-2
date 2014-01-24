#import <UIKit/UIImage+Private.h>

UIWindow *window;

%hook SBLockScreenManager

- (void)_finishUIUnlockFromSource:(NSInteger)source withOptions:(id)options {
	%orig;

	window = [[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
	window.windowLevel = UIWindowLevelStatusBar + 1.f;
	window.hidden = NO;

	UIImageView *imageView = [[[UIImageView alloc] initWithFrame:window.frame] autorelease];
    imageView.image = [UIImage imageNamed:@"welcome_screen" inBundle:[NSBundle bundleWithPath:@"/Library/PreferenceBundles/FlagPaint7.bundle"]];
    [window addSubview:imageView];

    UITapGestureRecognizer *tapGestureRecognize = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(flagpaint_dismissWindow)];
    tapGestureRecognize.numberOfTapsRequired = 1;
    [imageView addGestureRecognizer:tapGestureRecognize];
}

%new - (void)flagpaint_dismissWindow {
	window.hidden = YES;
	[window release];
}

%end
