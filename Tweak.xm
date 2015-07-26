#define _FLAGPAINT_TWEAK_XM
#import "NSCache+Subscripting.h"
#import "HBFPPreferences.h"
#import <AppList/AppList.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
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
#import <UIKit/UIImage+Private.h>
#import <version.h>
#include <dlfcn.h>

#pragma mark - Variables

BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

HBFPPreferences *preferences;
NSBundle *bundle;

BOOL hasBlurredClock;
BOOL hasMessagesAvatarTweak;

NSCache *iconCache = [[NSCache alloc] init];
NSCache *appsCache = [[NSCache alloc] init];

#pragma mark - Debug

extern "C" NSArray *HBFPDebugPlz() {
	return @[ tintCache, iconCache ];
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

	SBApplication *app = HBFPGetApplicationWithBundleIdentifier(sectionID_);

	if (app) {
		appsCache[sectionID_] = app.bundleIdentifier;
	} else if (bulletin) {
		app = HBFPGetApplicationWithBundleIdentifier(bulletin.section);

		if (app) {
			appsCache[sectionID_] = app.bundleIdentifier;
		} else if (bulletin.defaultAction) {
			app = HBFPGetApplicationWithBundleIdentifier(bulletin.defaultAction.bundleID);

			if (app) {
				appsCache[sectionID_] = app.bundleIdentifier;
			}
		}
	}

	if (!app) {
		HBLogError(@"flagpaint: couldn't get application (%@, %@)", bulletin, sectionID);
		return nil;
	}

	return app.bundleIdentifier;
}

BOOL HBFPIsMusic(NSString *key) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];
	return preferences.albumArtIcon && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([key isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [key isEqualToString:@"com.apple.Music"]);
}

NSString *HBFPGetKey(BBBulletin *bulletin, NSString *sectionID) {
	NSString *key = HBFPGetBundleIdentifier(bulletin, sectionID);

	if ([key isEqualToString:@"com.apple.MobileSMS"] && hasMessagesAvatarTweak) {
		key = [NSString stringWithFormat:@"_FPMessagesAvatar_%@_%d", key, bulletin.addressBookRecordID];
	}

	if (!key) {
		HBLogError(@"flagpaint: nil section identifier (%@, %@)", bulletin, sectionID);
		return [NSString stringWithFormat:@"_FPUnknown_%f", [NSDate date].timeIntervalSince1970];
	}

	return key;
}

UIImage *HBFPIconForKey(NSString *key, UIImage *fallbackImage) {
	if (iconCache[key]) {
		HBLogDebug(@"%@: icon was cached", key);
		return [iconCache[key] isKindOfClass:UIImage.class] ? iconCache[key] : nil;
	}

	UIImage *icon = nil;
	BOOL cacheIcon = YES;

	if (HBFPIsMusic(key)) {
		HBLogDebug(@"%@: trying music", key);

		// ugh. what a kludge.
		// TODO: really, there has to be a better way than this

		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		__block UIImage *artwork = nil;

		MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(CFDictionaryRef information) {
			NSData *data = ((NSDictionary *)information)[(NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];

			if (data) {
				artwork = [[UIImage alloc] initWithData:data];
			}

			dispatch_semaphore_signal(semaphore);
		});

		dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));

		icon = artwork;

		if (icon) {
			cacheIcon = NO;
		}
	}

	if (!icon) {
		HBLogDebug(@"%@: trying app icon", key);
		icon = [[UIImage _applicationIconImageForBundleIdentifier:key format:[key isEqualToString:@"com.apple.mobilecal"] ? SBApplicationIconFormatSpotlight : SBApplicationIconFormatDefault scale:[UIScreen mainScreen].scale] retain];
	}

	if (!icon) {
		HBLogDebug(@"%@: failed - using fallback %@", key, fallbackImage);
		icon = [fallbackImage copy];
	}

	if (cacheIcon) {
		iconCache[key] = icon ?: [[NSNull alloc] init];
	}

	return icon;
}

#pragma mark - Hide now label

%hook NSBundle

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table {
	// broad hook, yes i know. sue me.
	return [key isEqualToString:@"RELATIVE_DATE_NOW"] && [table isEqualToString:@"SpringBoard"] && preferences.removeDateLabel ? @"" : %orig;
}

%end

#pragma mark - Show test bulletin

BBBulletin *HBFPGetTestBulletin(BOOL isLockScreen) {
	NSDictionary *testApps = [[ALApplicationList sharedApplicationList] applicationsFilteredUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (SBApplication *app, NSDictionary *bindings) {
		return !app.tags || ![app.tags containsObject:kSBAppTagsHidden];
	}]];

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

	BBBulletin *bulletin = HBFPGetTestBulletin(NO);
	SBBulletinBannerController *bulletinBannerController = (SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance];

	if ([bulletinBannerController respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)]) {
		[bulletinBannerController observer:nil addBulletin:bulletin forFeed:2 playLightsAndSirens:YES withReply:nil];
	} else {
		[bulletinBannerController observer:nil addBulletin:bulletin forFeed:2];
	}
}

void HBFPShowLockScreenBulletin(BBBulletin *bulletin) {
	SBLockScreenViewController *viewController = ((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController;
	SBLockScreenNotificationListController *notificationController = MSHookIvar<SBLockScreenNotificationListController *>(viewController, "_notificationController");
	BBObserver *observer = MSHookIvar<BBObserver *>(notificationController, "_observer");

	if ([notificationController respondsToSelector:@selector(observer:addBulletin:forFeed:playLightsAndSirens:withReply:)]) {
		[notificationController observer:observer addBulletin:bulletin forFeed:2 playLightsAndSirens:YES withReply:nil];
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

	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/AnemoneCore.dylib"]) {
		dlopen("/Library/MobileSubstrate/DynamicLibraries/AnemoneCore.dylib", RTLD_NOW);
	}

	preferences = [[HBFPPreferences alloc] init];

	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	// CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("com.michaelpoole.subtlelock.settingsChanged"), NULL, kNilOptions);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPRespring, CFSTR("ws.hbang.flagpaint/Respring"), NULL, kNilOptions);
}
