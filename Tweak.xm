#define _FLAGPAINT_TWEAK_XM
#import "Global.h"
#import "NSCache+Subscripting.h"
#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
#import <Cephei/HBPreferences.h>
#import <MediaRemote/MediaRemote.h>
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
BOOL hasMessagesAvatarTweak;

NSCache *tintCache = [[NSCache alloc] init];
NSCache *iconCache = [[NSCache alloc] init];
NSDictionary *themeTints;

BOOL isPlaying;
NSString *nowPlayingBundleIdentifier;
NSString *cachedMusicKey;

#pragma mark - Debug

extern "C" NSArray *HBFPDebugPlz() {
	return @[ tintCache, iconCache ];
}

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

SBApplication *HBFPGetApplicationWithBundleIdentifier(NSString *bundleIdentifier) {
	SBApplicationController *appController = [%c(SBApplicationController) sharedInstance];
	return [appController respondsToSelector:@selector(applicationWithBundleIdentifier:)] ? [appController applicationWithBundleIdentifier:bundleIdentifier] : [appController applicationWithDisplayIdentifier:bundleIdentifier];
}

NSString *HBFPGetBundleIdentifier(BBBulletin *bulletin, NSString *sectionID) {
	SBApplication *app = [HBFPGetApplicationWithBundleIdentifier(bulletin ? bulletin.sectionID : sectionID) autorelease];

	if (!app && bulletin) {
		app = [HBFPGetApplicationWithBundleIdentifier(bulletin.section) autorelease];
	}

	if (!app && bulletin && bulletin.defaultAction) {
		app = [HBFPGetApplicationWithBundleIdentifier(bulletin.defaultAction.bundleID) autorelease];
	}

	if (!app) {
		NSLog(@"flagpaint: couldn't get application (%@, %@)", bulletin, sectionID);
		return nil;
	}

	return app.bundleIdentifier;
}

BOOL HBFPIsMusic(NSString *key) {
	return isPlaying && [key isEqualToString:cachedMusicKey];
}

NSString *HBFPGetKey(BBBulletin *bulletin, NSString *sectionID) {
	NSString *key = HBFPGetBundleIdentifier(bulletin, sectionID);

	if (isPlaying && [key isEqualToString:nowPlayingBundleIdentifier]) {
		key = cachedMusicKey;
	} else if ([key isEqualToString:@"com.apple.MobileSMS"] && hasMessagesAvatarTweak) {
		key = [NSString stringWithFormat:@"_FPMessagesAvatar_%@_%d", key, bulletin.addressBookRecordID];
	}

	if (!key) {
		NSLog(@"flagpaint: nil section identifier (%@, %@)", bulletin, sectionID);
		return [NSString stringWithFormat:@"_FPUnknown_%f", [NSDate date].timeIntervalSince1970];
	}

	return key;
}

UIColor *HBFPColorFromArray(NSArray *array) {
	return [UIColor colorWithRed:((NSNumber *)array[0]).integerValue / 255.f green:((NSNumber *)array[0]).integerValue / 255.f blue:((NSNumber *)array[0]).integerValue / 255.f alpha:1];
}

UIImage *HBFPIconForKey(NSString *key) {
	if (iconCache[key]) {
		return iconCache[key];
	}

	SBApplication *app = [HBFPGetApplicationWithBundleIdentifier(key) autorelease];

	if (app) {
		SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
		UIImage *icon = [appIcon getIconImage:[key isEqualToString:@"com.apple.mobilecal"] ? SBApplicationIconFormatSpotlight : SBApplicationIconFormatDefault];

		if (icon) {
			iconCache[key] = [icon retain];
		}
	}

	return iconCache[key];
}

UIColor *HBFPTintForKey(NSString *key) {
	NSString *prefsKey = [@"CustomTint-" stringByAppendingString:key];

	if (tintCache[key]) {
		return tintCache[key];
	} else if (preferences[prefsKey] && [preferences[prefsKey] isKindOfClass:NSArray.class] && ((NSArray *)preferences[prefsKey]).count == 3) {
		return HBFPColorFromArray(preferences[prefsKey]);
	} else if (themeTints[key] && [themeTints[key] isKindOfClass:NSArray.class] && ((NSArray *)themeTints[key]).count == 3) {
		return HBFPColorFromArray(themeTints[key]);
	}

	UIImage *icon = HBFPIconForKey(key);

	if (!icon) {
		return [UIColor whiteColor];
	}

	tintCache[key] = [HBFPGetDominantColor(icon) retain];
	return tintCache[key];
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

	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/PrettierBanners.dylib"]) {
		hasMessagesAvatarTweak = YES;
		dlopen("/Library/MobileSubstrate/DynamicLibraries/PrettierBanners.dylib", RTLD_NOW);
	}

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
	}];

	if (![preferences boolForKey:kHBFPPreferencesHadFirstRunKey]) {
		%init(FirstRun);
		[preferences setBool:YES forKey:kHBFPPreferencesHadFirstRunKey];
	}

	[[NSNotificationCenter defaultCenter] addObserverForName:(NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
		MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(CFDictionaryRef information) {
			NSDictionary *info = (NSDictionary *)information;
			SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithPid:((NSNumber *)info[(NSString *)kMRMediaRemoteNowPlayingApplicationPIDUserInfoKey]).integerValue];

			isPlaying = ((NSNumber *)info[(NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey]).boolValue;

			[cachedMusicKey release];

			if (isPlaying) {
				cachedMusicKey = [[NSString alloc] initWithFormat:@"_FPMusic_%@_%@_%@_%@", app.bundleIdentifier, info[(NSString *)kMRMediaRemoteNowPlayingInfoTitle], info[(NSString *)kMRMediaRemoteNowPlayingInfoAlbum], info[(NSString *)kMRMediaRemoteNowPlayingInfoArtist]];

				if (!iconCache[cachedMusicKey]) {
					iconCache[cachedMusicKey] = [HBFPResizeImage([UIImage imageWithData:info[(NSString *)kMRMediaRemoteNowPlayingInfoArtworkData]], CGSizeMake(120.f, 120.f)) retain];
				}
			} else {
				cachedMusicKey = nil;
			}
		});
	}];

	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("com.michaelpoole.subtlelock.settingsChanged"), NULL, kNilOptions);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPRespring, CFSTR("ws.hbang.flagpaint/Respring"), NULL, kNilOptions);
}
