#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBLockScreenManager.h>
#import <SpringBoard/SBLockScreenNotificationListController.h>
#import <SpringBoard/SBMediaController.h>
#import <SpringBoard/SBNotificationCenterController.h>
#import <SpringBoard/SBNotificationCenterViewController.h>
#import <version.h>
#import "HBFPShadowedLabel.h"
#include <dlfcn.h>

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Variables

BOOL tintBanners, tintLockScreen, tintNotificationCenter;
BOOL biggerIcon, albumArtIcon;
BOOL bannerGradient, semiTransparent, borderRadius, textShadow;
BOOL lockGradient, lockFade;
BOOL removeIcon, removeGrabber, removeDateLabel, removeAction;
CGFloat bannerColorIntensity, bannerGrayscaleIntensity, lockOpacity;

NSMutableDictionary *tintCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];

static NSString *const HBFPNotificationCenterSettingsChangedNotification = @"HBFPNotificationCenterSettingsChangedNotification";

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

	red /= numberOfPixels;
	green /= numberOfPixels;
	blue /= numberOfPixels;

	CGContextRelease(context);
	free(pixels);

	return [UIColor colorWithRed:red / 255.f green:green / 255.f blue:blue / 255.f alpha:1];
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

	return albumArtIcon && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([sectionID isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [sectionID isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[@"artworkData"];
}

NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return isMusic ? [NSString stringWithFormat:@"_FPMusic_%@_%@_%@_%@", mediaController.nowPlayingApplication.bundleIdentifier, mediaController.nowPlayingTitle, mediaController.nowPlayingArtist, mediaController.nowPlayingAlbum] : sectionID;
}

void HBFPGetIconIfNeeded(NSString *key, NSString *sectionID, BOOL isMusic) {
	if (!iconCache[key]) {
		if (isMusic) {
			iconCache[key] = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[@"artworkData"]], CGSizeMake(120.f, 120.f));
		} else {
			SBApplication *app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:sectionID] autorelease];

			if (app) {
				SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
				UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

				if (icon) {
					iconCache[key] = icon;
				}
			}
		}
	}
}

#pragma mark - The Guts(tm)

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

			if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer2.dylib"]) {
				url = [NSURL URLWithString:@"prefs:root=Cydia&path=FlagPaint7"];
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

static NSString *const kHBFPPrefsLockGradientKey = @"LockGradient";
static NSString *const kHBFPPrefsLockFadeKey = @"LockFade";
static NSString *const kHBFPPrefsLockOpacityKey = @"LockOpacity";

static NSString *const kHBFPPrefsRemoveIconKey = @"RemoveIcon";
static NSString *const kHBFPPrefsRemoveGrabberKey = @"RemoveGrabber";
static NSString *const kHBFPPrefsRemoveDateLabelKey = @"RemoveDateLabel";
static NSString *const kHBFPPrefsRemoveLockActionKey = @"RemoveLockAction";

static NSString *const kHBFPPrefsNotFirstRunKey = @"NotFirstRun";

void HBFPLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kHBFPPrefsPath];

	if (prefs.allKeys.count == 0) {
		[@{ kHBFPPrefsNotFirstRunKey: @YES } writeToFile:kHBFPPrefsPath atomically:YES];
		%init(FirstRun);
	}

	BOOL oldTintNC = tintNotificationCenter;

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
	
	bannerColorIntensity = GET_FLOAT(kHBFPPrefsBannerColorIntensityKey, 40.f);
	bannerGrayscaleIntensity = GET_FLOAT(kHBFPPrefsBannerGrayscaleIntensityKey, 40.f);
	lockOpacity = GET_FLOAT(kHBFPPrefsLockOpacityKey, 50.f);

	removeIcon = GET_BOOL(kHBFPPrefsRemoveIconKey, NO);
	removeGrabber = GET_BOOL(kHBFPPrefsRemoveGrabberKey, YES);
	removeDateLabel = GET_BOOL(kHBFPPrefsRemoveDateLabelKey, YES);
	removeAction = GET_BOOL(kHBFPPrefsRemoveLockActionKey, NO);

	if (oldTintNC && !tintNotificationCenter) {
		[[NSNotificationCenter defaultCenter] postNotificationName:HBFPNotificationCenterSettingsChangedNotification object:nil];
	}
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
	[(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:HBFPGetTestBulletin(NO) forFeed:2];
}

void HBFPShowLockScreenBulletin(BBBulletin *bulletin) {
	UIViewController *viewController = ((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController;
	SBLockScreenNotificationListController *notificationController = MSHookIvar<SBLockScreenNotificationListController *>(viewController, "_notificationController");

	[notificationController observer:nil addBulletin:bulletin forFeed:2];
}

void HBFPShowTestLockScreenNotification() {
	[(SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		HBFPShowLockScreenBulletin(HBFPGetTestBulletin(YES));
	});
}

void HBFPShowTestNotificationCenterBulletin() {
	[(SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance] presentAnimated:YES completion:^{
		[[((SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance]).viewController _allModeViewControllerCreateIfNecessary:YES] observer:nil addBulletin:HBFPGetTestBulletin(NO) forFeed:2];
	}];
}

#pragma mark - Constructor

%ctor {
	%init;

	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestNotificationCenterBulletin, CFSTR("ws.hbang.flagpaint/TestNotificationCenterBulletin"), NULL, kNilOptions);
}
