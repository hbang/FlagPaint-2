NSBundle *bundle;

%ctor {
	bundle = [[NSBundle bundleWithPath:@"/Library/PreferenceBundles/FlagPaint7.bundle"] retain];
}
