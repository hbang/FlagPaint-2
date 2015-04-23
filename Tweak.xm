#define _FLAGPAINT_TWEAK_XM
#import "Global.h"
#import "NSCache+Subscripting.h"
#import <Accelerate/Accelerate.h>
#import <AppList/AppList.h>
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
NSCache *appsCache = [[NSCache alloc] init];
NSDictionary *themeTints;

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
	NSString *sectionID_ = bulletin ? bulletin.sectionID : sectionID;

	if (appsCache[sectionID_]) {
		return appsCache[sectionID_];
	}

	SBApplication *app = [HBFPGetApplicationWithBundleIdentifier(sectionID_) autorelease];

	if (app) {
		appsCache[sectionID_] = app.bundleIdentifier;
	} else if (bulletin) {
		app = [HBFPGetApplicationWithBundleIdentifier(bulletin.section) autorelease];

		if (app) {
			appsCache[sectionID_] = app.bundleIdentifier;
		} else if (bulletin.defaultAction) {
			app = [HBFPGetApplicationWithBundleIdentifier(bulletin.defaultAction.bundleID) autorelease];

			if (app) {
				appsCache[sectionID_] = app.bundleIdentifier;
			}
		}
	}

	if (!app) {
		NSLog(@"flagpaint: couldn't get application (%@, %@)", bulletin, sectionID);
		return nil;
	}

	return app.bundleIdentifier;
}

BOOL HBFPIsMusic(NSString *key) {
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		return NO; // TODO: support ios 8's changes
	}

	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];
	return [preferences boolForKey:kHBFPPreferencesAlbumArtIconKey] && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([key isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [key isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[kSBNowPlayingInfoArtworkDataKey];
}

NSString *HBFPGetKey(BBBulletin *bulletin, NSString *sectionID) {
	NSString *key = HBFPGetBundleIdentifier(bulletin, sectionID);

	if ([key isEqualToString:@"com.apple.MobileSMS"] && hasMessagesAvatarTweak) {
		key = [NSString stringWithFormat:@"_FPMessagesAvatar_%@_%d", key, bulletin.addressBookRecordID];
	}

	if (!key) {
		NSLog(@"flagpaint: nil section identifier (%@, %@)", bulletin, sectionID);
		return [NSString stringWithFormat:@"_FPUnknown_%f", [NSDate date].timeIntervalSince1970];
	}

	return key;
}

UIColor *HBFPColorFromDictionaryValue(id value) {
	if ([value isKindOfClass:NSArray.class] && ((NSArray *)value).count == 3) {
		NSArray *array = value;
		return [UIColor colorWithRed:((NSNumber *)array[0]).integerValue / 255.f green:((NSNumber *)array[1]).integerValue / 255.f blue:((NSNumber *)array[2]).integerValue / 255.f alpha:1];
	} else if ([value isKindOfClass:NSString.class] && [((NSString *)value) hasPrefix:@"#"] && ((NSString *)value).length == 7) {
		unsigned int hexInteger = 0;
		NSScanner *scanner = [NSScanner scannerWithString:value];
		scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@"#"];
		[scanner scanHexInt:&hexInteger];

		return [UIColor colorWithRed:((hexInteger & 0xFF0000) >> 16) / 255.f green:((hexInteger & 0xFF00) >> 8) / 255.f blue:(hexInteger & 0xFF) / 255.f alpha:1];
	} else {
		return nil;
	}
}

UIImage *HBFPIconForKey(NSString *key, UIImage *fallbackImage) {
	if (iconCache[key]) {
		return iconCache[key];
	}

	UIImage *icon = nil;

	if (HBFPIsMusic(key)) {
		CGFloat size = 60.f * [UIScreen mainScreen].scale;
		icon = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[kSBNowPlayingInfoArtworkDataKey]], CGSizeMake(size, size));
	}

	if (!icon) {
		iconCache[key] = [[[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeLarge forDisplayIdentifier:key] copy];
	}

	if (!icon) {
		iconCache[key] = [fallbackImage copy];
	}

	return iconCache[key];
}

UIColor *HBFPTintForKey(NSString *key, UIImage *fallbackImage) {
	UIColor *tint = nil;

	if (tintCache[key]) {
		tint = tintCache[key];
	} else {
		NSString *prefsKey = [@"CustomTint-" stringByAppendingString:key];

		if (preferences[prefsKey]) {
			tint = HBFPColorFromDictionaryValue(preferences[prefsKey]);
		}

		if (!tint && themeTints[key]) {
			tint = HBFPColorFromDictionaryValue(themeTints[key]);
		}

		if (!tint) {
			UIImage *icon = HBFPIconForKey(key, nil);

			if (!icon) {
				return [UIColor whiteColor];
			}

			tint = HBFPGetDominantColor(icon);
		}

		if (!tintCache[key]) {
			tintCache[key] = [tint retain];
		}

		if (!tint) {
			tint = [UIColor whiteColor];
		}
	}

	CGFloat vibrancy = [preferences floatForKey:kHBFPPreferencesTintVibrancyKey] / 100.f - 0.5f;

	CGFloat hue, saturation, brightness;
	[tint getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];

	return [UIColor colorWithHue:hue saturation:MIN(1.f, saturation + vibrancy) brightness:MAX(0, brightness - vibrancy) alpha:1];;
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
	NSDictionary *testApps = [ALApplicationList sharedApplicationList].applications;
	NSString *bundleIdentifier = testApps.allKeys[arc4random_uniform(testApps.allKeys.count)];
	NSString *displayName = testApps[bundleIdentifier];

	BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint";
	bulletin.sectionID = bundleIdentifier;
	bulletin.title = displayName;
	bulletin.defaultAction = [BBAction action];

	NSString *message = [bundle localizedStringForKey:@"Test notification" value:@"Test notification" table:@"Localizable"];

	if (isLockScreen) {
		bulletin.subtitle = message;
	} else {
		bulletin.message = message;
	}

	return bulletin;
}

void HBFPShowTestBanner() {
	SBBannerController *bannerController = (SBBannerController *)[%c(SBBannerController) sharedInstance];
	[bannerController _replaceIntervalElapsed];
	[bannerController _dismissIntervalElapsed];

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
	// TODO: maybe clean this up someday...

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
		kHBFPPreferencesTintVibrancyKey: @65.f,

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

	NSDictionary *wbPreferences = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:@"file:///var/mobile/Library/Preferences/com.saurik.WinterBoard.plist"]];

	if (wbPreferences && wbPreferences[kHBFPWinterBoardThemesKey]) {
		NSMutableDictionary *newThemeTints = [NSMutableDictionary dictionary];

		for (NSDictionary *theme in wbPreferences[kHBFPWinterBoardThemesKey]) {
			if (!((NSNumber *)theme[kHBFPWinterBoardThemeActiveKey]).boolValue) {
				continue;
			}

			NSString *name = theme[kHBFPWinterBoardThemeNameKey];
			NSURL *themeURL = [NSURL URLWithString:[@"file:///Library/Themes/" stringByAppendingPathComponent:name]];
			NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:[themeURL URLByAppendingPathComponent:kHBFPWinterBoardPlistName]];

			if (!plist) {
				plist = [NSDictionary dictionaryWithContentsOfURL:[[themeURL URLByAppendingPathExtension:@"theme"] URLByAppendingPathComponent:kHBFPWinterBoardPlistName]];

				if (!plist) {
					continue;
				}
			}

			NSDictionary *tints = plist[kHBFPWinterBoardTintsKey];

			if (!tints) {
				continue;
			}

			for (NSString *key in tints.allKeys) {
				if (!newThemeTints[key]) {
					newThemeTints[key] = tints[key];
				}
			}
		}

		themeTints = [newThemeTints copy];
	}

	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("com.michaelpoole.subtlelock.settingsChanged"), NULL, kNilOptions);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPRespring, CFSTR("ws.hbang.flagpaint/Respring"), NULL, kNilOptions);
}
