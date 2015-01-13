#define _FLAGPAINT_TWEAK_XM
#import "Global.h"
#import "NSCache+Subscripting.h"
#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
#import <Cephei/HBPreferences.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBBannerController.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBLockScreenManager.h>
#import <SpringBoard/SBLockScreenNotificationListController.h>
#import <SpringBoard/SBMediaController.h>
#import <SpringBoard/SBNotificationCenterController.h>
#import <SpringBoard/SBNotificationCenterViewController.h>
#import <version.h>
#include <dlfcn.h>

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Variables

BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

HBPreferences *preferences;
NSBundle *bundle;

BOOL hasBlurredClock;

NSCache *tintCache = [[NSCache alloc] init];
NSCache *iconCache = [[NSCache alloc] init];

#pragma mark - Get dominant color

UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;
	NSUInteger numberOfPixels = image.size.width * image.size.height;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (!pixels) {
		return [UIColor whiteColor];
	}

	CGContextRef context = CGBitmapContextCreate(pixels, image.size.width, image.size.height, BitsPerComponent, image.size.width * BytesPerPixel, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

	if (!context) {
		free(pixels);
		return [UIColor whiteColor];
	}

	CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

	for (NSUInteger i = 0; i < numberOfPixels; i++) {
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
	}

	CGContextRelease(context);
	free(pixels);

	UIColor *color = [UIColor colorWithRed:red / numberOfPixels / 255.f green:green / numberOfPixels / 255.f blue:blue / numberOfPixels / 255.f alpha:1];

	if (_UIAccessibilityEnhanceBackgroundContrast()) {
		CGFloat hue, saturation, brightness;
		[color getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];
		color = [UIColor colorWithHue:hue saturation:MIN(1.f, saturation + 0.2f) brightness:MAX(0, brightness - 0.15f) alpha:1];
	}

	return color;
}

#pragma mark - Resize image

// http://stackoverflow.com/a/10099016/709376

UIImage *HBFPResizeImage(UIImage *oldImage, CGSize newSize) {
	if (!oldImage) {
		return nil;
	}

	UIImage *newImage = nil;

	CGImageRef cgImage = oldImage.CGImage;
	NSUInteger oldWidth = CGImageGetWidth(cgImage);
	NSUInteger oldHeight = CGImageGetHeight(cgImage);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	pixel *oldData = (pixel *)calloc(oldHeight * oldWidth * BytesPerPixel, sizeof(pixel));
	NSUInteger oldBytesPerRow = BytesPerPixel * oldWidth;

	CGContextRef context = CGBitmapContextCreate(oldData, oldWidth, oldHeight, BitsPerComponent, oldBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGContextDrawImage(context, CGRectMake(0, 0, oldWidth, oldHeight), cgImage);
	CGContextRelease(context);

	NSUInteger newWidth = (NSUInteger)newSize.width;
	NSUInteger newHeight = (NSUInteger)newSize.height;
	NSUInteger newBytesPerRow = BytesPerPixel * newWidth;
	pixel *newData = (pixel *)calloc(newHeight * newWidth * BytesPerPixel, sizeof(pixel));

	vImage_Buffer oldBuffer = {
		.data = oldData,
		.height = oldHeight,
		.width = oldWidth,
		.rowBytes = oldBytesPerRow
	};

	vImage_Buffer newBuffer = {
		.data = newData,
		.height = newHeight,
		.width = newWidth,
		.rowBytes = newBytesPerRow
	};

	vImage_Error error = vImageScale_ARGB8888(&oldBuffer, &newBuffer, NULL, kvImageHighQualityResampling);

	free(oldData);

	CGContextRef newContext = CGBitmapContextCreate(newData, newWidth, newHeight, BitsPerComponent, newBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGImageRef cgImageNew = CGBitmapContextCreateImage(newContext);

	newImage = [UIImage imageWithCGImage:cgImageNew];

	CGImageRelease(cgImageNew);
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(newContext);

	free(newData);

	if (error != kvImageNoError) {
		NSLog(@"warning: failed to scale image: error %ld", error);
		return oldImage;
	}

	return newImage;
}

#pragma mark - Various helper functions

BOOL HBFPIsMusic(NSString *sectionID) {
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		return NO; // TODO: support ios 8's changes
	}

	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return [preferences boolForKey:kHBFPPreferencesAlbumArtIconKey] && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([sectionID isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [sectionID isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[kSBNowPlayingInfoArtworkDataKey];
}

NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	if (isMusic) {
		return [NSString stringWithFormat:@"_FPMusic_%@_%@_%@_%@", mediaController.nowPlayingApplication.bundleIdentifier, mediaController.nowPlayingTitle, mediaController.nowPlayingArtist, mediaController.nowPlayingAlbum];
	} else if (sectionID) {
		return sectionID;
	} else {
		NSLog(@"flagpaint: nil section identifier (%@, %i)", sectionID, isMusic);
		return [NSString stringWithFormat:@"_FPUnknown_%f", [NSDate date].timeIntervalSince1970];
	}
}

SBApplication *HBFPGetApplicationWithBundleIdentifier(NSString *bundleIdentifier) {
	SBApplicationController *appController = [%c(SBApplicationController) sharedInstance];
	return [appController respondsToSelector:@selector(applicationWithBundleIdentifier:)] ? [appController applicationWithBundleIdentifier:bundleIdentifier] : [appController applicationWithDisplayIdentifier:bundleIdentifier];
}

void HBFPGetIconIfNeeded(NSString *key, BBBulletin *bulletin, BOOL isMusic) {
	if (!iconCache[key]) {
		BOOL hasIcon = NO;

		if (isMusic) {
			UIImage *icon = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[kSBNowPlayingInfoArtworkDataKey]], CGSizeMake(120.f, 120.f));

			if (icon) {
				iconCache[key] = icon;
				hasIcon = YES;
			}
		}

		if (!hasIcon) {
			SBApplication *app = [HBFPGetApplicationWithBundleIdentifier(bulletin ? bulletin.sectionID : key) autorelease];

			if (!app && bulletin) {
				app = [HBFPGetApplicationWithBundleIdentifier(bulletin.section) autorelease];
			}

			if (!app && bulletin && bulletin.defaultAction) {
				app = [HBFPGetApplicationWithBundleIdentifier(bulletin.defaultAction.bundleID) autorelease];
			}

			if (!app) {
				NSLog(@"flagpaint: couldn't get icon for key %@, bulletin %@", key, bulletin);
				return;
			}

			if (app) {
				SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
				UIImage *icon = [appIcon getIconImage:[key isEqualToString:@"com.apple.mobilecal"] ? SBApplicationIconFormatSpotlight : SBApplicationIconFormatDefault];

				if (icon) {
					iconCache[key] = icon;
				}
			}
		}
	}
}

#pragma mark - Hide now label

%hook NSBundle

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table {
	// broad hook, yes i know. sue me.
	return [key isEqualToString:@"RELATIVE_DATE_NOW"] && [table isEqualToString:@"SpringBoard"] && [preferences boolForKey:kHBFPPreferencesRemoveDateLabelKey] ? @"" : %orig;
}

%end

#pragma mark - First run

void HBFPShowLockScreenBulletin(BBBulletin *bulletin);

%group FirstRun

BOOL firstRun = YES;

%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;

	if (firstRun) {
		firstRun = NO;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
			BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
			bulletin.bulletinID = @"ws.hbang.flagpaint";
			bulletin.sectionID = @"com.apple.Preferences";
			bulletin.title = [bundle localizedStringForKey:@"Thanks for purchasing FlagPaint!" value:@"Thanks for purchasing FlagPaint!" table:@"Localizable"];
			bulletin.unlockActionLabelOverride = [bundle localizedStringForKey:@"configure" value:@"configure" table:@"Localizable"];

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

%end

#pragma mark - Show test bulletin

BBBulletin *HBFPGetTestBulletin(BOOL isLockScreen) {
	static NSArray *TestApps;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSArray *apps = [%c(SBApplicationController) sharedInstance].allApplications;
		NSMutableArray *mutableApps = [NSMutableArray array];

		for (SBApplication *app in apps) {
			if (app.tags && [app.tags containsObject:kSBAppTagsHidden]) {
				continue;
			}

			[mutableApps addObject:app];
		}

		TestApps = [mutableApps copy];
	});

	SBApplication *app = TestApps[arc4random_uniform(TestApps.count)];

	BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint";
	bulletin.sectionID = [app respondsToSelector:@selector(bundleIdentifier)] ? app.bundleIdentifier : app.displayIdentifier;
	bulletin.title = app.displayName;

	NSString *message = [bundle localizedStringForKey:@"Test notification" value:@"Test notification" table:@"Localizable"];

	if (isLockScreen) {
		bulletin.subtitle = message;
	} else {
		bulletin.message = message;
	}

	return bulletin;
}

void HBFPShowTestBanner() {
	[(SBBannerController *)[%c(SBBannerController) sharedInstance] dismissBannerWithAnimation:YES reason:0 forceEvenIfBusy:YES];
	[(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:HBFPGetTestBulletin(NO) forFeed:2];
}

void HBFPShowLockScreenBulletin(BBBulletin *bulletin) {
	SBLockScreenViewController *viewController = ((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController;
	SBLockScreenNotificationListController *notificationController = MSHookIvar<SBLockScreenNotificationListController *>(viewController, "_notificationController");
	BBObserver *observer = MSHookIvar<BBObserver *>(notificationController, "_observer");

	if ([notificationController respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)]) {
		[notificationController observer:observer addBulletin:bulletin forFeed:2 playLightsAndSirens:NO withReply:nil];
	} else {
		[notificationController observer:observer addBulletin:bulletin forFeed:2];
	}
}

void HBFPShowTestLockScreenNotification() {
	[(SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		HBFPShowLockScreenBulletin(HBFPGetTestBulletin(YES));
	});
}

void HBFPRespring() {
	[(SpringBoard *)[UIApplication sharedApplication] _relaunchSpringBoardNow];
}

#pragma mark - Constructor

%ctor {
	%init;

	_UIAccessibilityEnhanceBackgroundContrast = (BOOL (*)())dlsym(RTLD_DEFAULT, "_UIAccessibilityEnhanceBackgroundContrast");
	bundle = [[NSBundle bundleWithPath:@"/Library/PreferenceBundles/FlagPaint7.bundle"] retain];

	preferences = [[HBPreferences alloc] initWithIdentifier:kHBFPPreferencesSuiteName];
	[preferences registerDefaults:@{
		kHBFPPreferencesHadFirstRunKey: @NO,
		kHBFPPreferencesTintBannersKey: @YES,
		kHBFPPreferencesTintLockScreenKey: @YES,
		kHBFPPreferencesTintNotificationCenterKey: @YES,

		kHBFPPreferencesBiggerIconKey: @YES,
		kHBFPPreferencesAlbumArtIconKey: @YES,

		kHBFPPreferencesBannerGradientKey: @NO,
		kHBFPPreferencesBannerBorderRadiusKey: @NO,
		kHBFPPreferencesBannerTextShadowKey: @NO,

		kHBFPPreferencesLockGradientKey: @YES,
		kHBFPPreferencesLockFadeKey: @YES,
		kHBFPPreferencesLockDisableDimmingKey: @YES,

		kHBFPPreferencesNotificationCenterFadeKey: @YES,

		kHBFPPreferencesBannerColorIntensityKey: _UIAccessibilityEnhanceBackgroundContrast() ? @80.f : @40.f,
		kHBFPPreferencesBannerGrayscaleIntensityKey: @40.f,
		kHBFPPreferencesBannerOpacityKey: @100.f,
		kHBFPPreferencesLockOpacityKey: @50.f,
		kHBFPPreferencesNotificationCenterOpacityKey: _UIAccessibilityEnhanceBackgroundContrast() ? @77.f : @15.f,

		kHBFPPreferencesRemoveIconKey: @NO,
		kHBFPPreferencesRemoveGrabberKey: @YES,
		kHBFPPreferencesRemoveDateLabelKey: @YES,
		kHBFPPreferencesRemoveLockActionKey: @NO,

		kHBFPPreferencesFonzKey: @NO

		// [[NSNotificationCenter defaultCenter] postNotificationName:HBFPPreferencesChangedNotification object:nil];
	}];

	if (![preferences boolForKey:kHBFPPreferencesHadFirstRunKey]) {
		%init(FirstRun);
		[preferences setBool:YES forKey:kHBFPPreferencesHadFirstRunKey];
	}

	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("com.michaelpoole.subtlelock.settingsChanged"), NULL, kNilOptions);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPRespring, CFSTR("ws.hbang.flagpaint/Respring"), NULL, kNilOptions);
}
