%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)arg1 {
	%orig;
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle: @"Announcement"
			message: @"It turns out that you are playing Addicus!"
			delegate: nil
			cancelButtonTitle:@"OK"
			otherButtonTitles:nil];
[alert show];
[alert release];
}

%end