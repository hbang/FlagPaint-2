%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)arg1 {
	%orig;
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle: @"FlagPaint"
			message: @"First Launch"
			delegate: nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
[alert show];
[alert release];
}

%end