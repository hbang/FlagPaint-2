static UIWindow *window;

%hook SBLockScreenManager

- (void)_finishUIUnlockFromSource:(int)arg1 withOptions:(id)arg2 {
	%orig;
	window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	[window makeKeyAndVisible];
	UIImageView *iv = [[UIImageView alloc] initWithFrame:window.frame];
    iv.image = [UIImage imageWithContentsOfFile:@"/Library/Application Support/FlagPaint7/welcome_screen.png"];
    [window addSubview:iv];

     UITapGestureRecognizer *tapGestureRecognize = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    tapGestureRecognize.numberOfTapsRequired = 1;
    [iv addGestureRecognizer:tapGestureRecognize];
}

%new
-(void)dismiss {
	[window release];
}

%end