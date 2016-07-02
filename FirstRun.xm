#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>

void HBFPShowLockScreenBulletin(BBBulletin *bulletin);

BOOL firstRun = YES;

%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;

	if (firstRun) {
		firstRun = NO;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
			BBBulletin *bulletin = [[BBBulletin alloc] init];
			bulletin.bulletinID = @"ws.hbang.flagpaint";
			bulletin.sectionID = @"com.apple.Preferences";
			bulletin.title = [bundle localizedStringForKey:@"THANKS_MESSAGE_TITLE" value:nil table:@"Localizable"];
			bulletin.unlockActionLabelOverride = [bundle localizedStringForKey:@"THANKS_MESSAGE_ACTION" value:nil table:@"Localizable"];

			NSURL *url;

			if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer7.dylib"]) {
				url = [NSURL URLWithString:@"prefs:root=Tweaks&path=FlagPaint"];
			} else {
				url = [NSURL URLWithString:@"prefs:root=FlagPaint"];
			}

			bulletin.defaultAction = [BBAction actionWithLaunchURL:url callblock:nil];

			HBFPShowLockScreenBulletin(bulletin);
		});
	}
}

%end

%ctor {
	if (!preferences.hadFirstRun) {
		%init;
		preferences.hadFirstRun = YES;
	}
}
