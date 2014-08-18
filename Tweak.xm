#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
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

BOOL tintBanners, tintLockScreen, tintNotificationCenter;
BOOL biggerIcon, albumArtIcon;
BOOL bannerGradient, semiTransparent, borderRadius, textShadow;
BOOL lockGradient, lockFade, lockDisableDimming;
BOOL notificationCenterFade;
BOOL removeIcon, removeGrabber, removeDateLabel, removeAction;
CGFloat bannerColorIntensity, bannerGrayscaleIntensity, bannerOpacity;
CGFloat lockOpacity, notificationCenterOpacity;

BOOL hasBlurredClock;

NSMutableDictionary *tintCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];

static NSString *const HBFPPreferencesChangedNotification = @"HBFPPreferencesChangedNotification";

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
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return albumArtIcon && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([sectionID isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [sectionID isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[kSBNowPlayingInfoArtworkDataKey];
}

NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return isMusic ? [NSString stringWithFormat:@"_FPMusic_%@_%@_%@_%@", mediaController.nowPlayingApplication.bundleIdentifier, mediaController.nowPlayingTitle, mediaController.nowPlayingArtist, mediaController.nowPlayingAlbum] : sectionID;
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
			SBApplication *app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:bulletin ? bulletin.sectionID : key] autorelease];

			if (!app && bulletin) {
				app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:bulletin.section] autorelease];
			}

			if (!app && bulletin && bulletin.defaultAction) {
				app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:bulletin.defaultAction.bundleID] autorelease];
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
	return [key isEqualToString:@"RELATIVE_DATE_NOW"] && [table isEqualToString:@"SpringBoard"] && removeDateLabel ? @"" : %orig;
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
			bulletin.title = @"Thanks for purchasing FlagPaint!";
			bulletin.unlockActionLabelOverride = @"configure";

			NSURL *url;

			if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer7.dylib"]) {
				url = [NSURL URLWithString:@"prefs:root=Tweaks&path=FlagPaint7"];
			} else {
				url = [NSURL URLWithString:@"prefs:root=FlagPaint7"];
			}

			bulletin.defaultAction = [BBAction actionWithLaunchURL:url callblock:nil];

			HBFPShowLockScreenBulletin(bulletin);
		});
	}
}

%end

%end

#pragma mark - Preferences

static NSString *const kHBFPPrefsPath = @"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist";

static NSString *const kHBFPPrefsTintBannersKey = @"Tint";
static NSString *const kHBFPPrefsTintLockScreenKey = @"TintLockScreen";
static NSString *const kHBFPPrefsTintNotificationCenterKey = @"TintNotificationCenter";

static NSString *const kHBFPPrefsBiggerIconKey = @"BigIcon";
static NSString *const kHBFPPrefsAlbumArtIconKey = @"AlbumArt";

static NSString *const kHBFPPrefsBannerGradientKey = @"Gradient";
static NSString *const kHBFPPrefsSemiTransparentKey = @"Semitransparent";
static NSString *const kHBFPPrefsBorderRadiusKey = @"BorderRadius";
static NSString *const kHBFPPrefsTextShadowKey = @"TextShadow";
static NSString *const kHBFPPrefsBannerColorIntensityKey = @"BannerColorIntensity";
static NSString *const kHBFPPrefsBannerGrayscaleIntensityKey = @"BannerGrayscaleIntensity";
static NSString *const kHBFPPrefsBannerOpacityKey = @"BannerOpacity";

static NSString *const kHBFPPrefsLockGradientKey = @"LockGradient";
static NSString *const kHBFPPrefsLockFadeKey = @"LockFade";
static NSString *const kHBFPPrefsLockOpacityKey = @"LockOpacity";
static NSString *const kHBFPPrefsLockDisableDimmingKey = @"LockDisableDimming";

static NSString *const kHBFPPrefsNotificationCenterFadeKey = @"NotificationCenterFade";
static NSString *const kHBFPPrefsNotificationCenterOpacityKey = @"NotificationCenterOpacity";

static NSString *const kHBFPPrefsRemoveIconKey = @"RemoveIcon";
static NSString *const kHBFPPrefsRemoveGrabberKey = @"RemoveGrabber";
static NSString *const kHBFPPrefsRemoveDateLabelKey = @"RemoveDateLabel";
static NSString *const kHBFPPrefsRemoveLockActionKey = @"RemoveLockAction";

static NSString *const kHBFPPrefsHadFirstRunKey = @"HadFirstRun";

static NSString *const kHBFPSubtleLockPrefsPath = @"/var/mobile/Library/Preferences/com.michaelpoole.subtlelock.plist";
static NSString *const kHBFPSubtleLockBlurredClockBGKey = @"BlurredClockBG";

void HBFPLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kHBFPPrefsPath];

	if (prefs.allKeys.count == 0) {
		[@{ kHBFPPrefsHadFirstRunKey: @YES } writeToFile:kHBFPPrefsPath atomically:YES];
		%init(FirstRun);
	}

	tintBanners = GET_BOOL(kHBFPPrefsTintBannersKey, YES);
	tintLockScreen = GET_BOOL(kHBFPPrefsTintLockScreenKey, YES);
	tintNotificationCenter = GET_BOOL(kHBFPPrefsTintNotificationCenterKey, YES);

	biggerIcon = GET_BOOL(kHBFPPrefsBiggerIconKey, YES);
	albumArtIcon = GET_BOOL(kHBFPPrefsAlbumArtIconKey, YES);

	bannerGradient = GET_BOOL(kHBFPPrefsBannerGradientKey, NO);
	semiTransparent = GET_BOOL(kHBFPPrefsSemiTransparentKey, YES);
	borderRadius = GET_BOOL(kHBFPPrefsBorderRadiusKey, NO);
	textShadow = GET_BOOL(kHBFPPrefsTextShadowKey, NO);

	lockGradient = GET_BOOL(kHBFPPrefsLockGradientKey, YES);
	lockFade = GET_BOOL(kHBFPPrefsLockFadeKey, YES);
	lockDisableDimming = GET_BOOL(kHBFPPrefsLockDisableDimmingKey, YES);

	notificationCenterFade = GET_BOOL(kHBFPPrefsNotificationCenterFadeKey, YES);

	bannerColorIntensity = GET_FLOAT(kHBFPPrefsBannerColorIntensityKey, _UIAccessibilityEnhanceBackgroundContrast() ? 80.f : 40.f) / 100.f;
	bannerGrayscaleIntensity = GET_FLOAT(kHBFPPrefsBannerGrayscaleIntensityKey, 40.f) / 100.f;
	bannerOpacity = GET_FLOAT(kHBFPPrefsBannerOpacityKey, 100.f) / 100.f;
	lockOpacity = GET_FLOAT(kHBFPPrefsLockOpacityKey, 50.f) / 100.f;
	notificationCenterOpacity = GET_FLOAT(kHBFPPrefsNotificationCenterOpacityKey, _UIAccessibilityEnhanceBackgroundContrast() ? 77.f : 15.f) / 100.f;

	removeIcon = GET_BOOL(kHBFPPrefsRemoveIconKey, NO);
	removeGrabber = GET_BOOL(kHBFPPrefsRemoveGrabberKey, YES);
	removeDateLabel = GET_BOOL(kHBFPPrefsRemoveDateLabelKey, YES);
	removeAction = GET_BOOL(kHBFPPrefsRemoveLockActionKey, NO);

	[[NSNotificationCenter defaultCenter] postNotificationName:HBFPPreferencesChangedNotification object:nil];

	NSDictionary *subtlelockPrefs = [NSDictionary dictionaryWithContentsOfFile:kHBFPSubtleLockPrefsPath];
	hasBlurredClock = subtlelockPrefs && subtlelockPrefs[kHBFPSubtleLockBlurredClockBGKey] ? ((NSNumber *)subtlelockPrefs[kHBFPSubtleLockBlurredClockBGKey]).boolValue : NO;
}

#pragma mark - Show test bulletin

NSUInteger testIndex = 0;

BBBulletin *HBFPGetTestBulletin(BOOL isLockScreen) {
	static NSArray *TestApps;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		TestApps = [@[
			@"com.apple.MobileSMS", @"com.apple.mobilecal", @"com.apple.mobileslideshow", @"com.apple.camera",
			@"com.apple.weather", @"com.apple.mobiletimer", @"com.apple.Maps", @"com.apple.videos",
			@"com.apple.mobilenotes", @"com.apple.reminders", @"com.apple.stocks", @"com.apple.gamecenter",
			@"com.apple.Passbook", @"com.apple.MobileStore", @"com.apple.AppStore", @"com.apple.Preferences",
			@"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", @"com.apple.Music",
			@"com.apple.MobileAddressBook", @"com.apple.calculator", @"com.apple.compass", @"com.apple.VoiceMemos",
			@"com.apple.facetime", @"com.apple.nike"
		] retain];
	});

	do {
		testIndex = arc4random_uniform(TestApps.count);
	} while (![(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:TestApps[testIndex]]);

	BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint";
	bulletin.sectionID = TestApps[testIndex];
	bulletin.title = @"FlagPaint";

	if (isLockScreen) {
		bulletin.subtitle = @"Test notification";
	} else {
		bulletin.message = @"Test notification";
		bulletin.accessoryStyle = BBBulletinAccessoryStyleVIP;
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

	[notificationController observer:observer addBulletin:bulletin forFeed:2];
}

void HBFPShowTestLockScreenNotification() {
	[(SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		HBFPShowLockScreenBulletin(HBFPGetTestBulletin(YES));
	});
}

#pragma mark - Constructor

%ctor {
	%init;

	_UIAccessibilityEnhanceBackgroundContrast = (BOOL (*)())dlsym(RTLD_DEFAULT, "_UIAccessibilityEnhanceBackgroundContrast");

	HBFPLoadPrefs();

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("com.michaelpoole.subtlelock.settingsChanged"), NULL, kNilOptions);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
}
