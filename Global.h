#import <Cephei/HBPreferences.h>

@class BBBulletin;

#pragma mark - Other

#ifndef _FLAGPAINT_TWEAK_XM
extern BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

extern HBPreferences *preferences;
extern BOOL hasBlurredClock, hasMessagesAvatarTweak;

extern NSCache *tintCache, *iconCache;

extern BOOL HBFPIsMusic(NSString *key);
extern NSString *HBFPGetKey(BBBulletin *bulletin, NSString *sectionID);
extern UIImage *HBFPIconForKey(NSString *key, UIImage *fallbackImage);
extern UIColor *HBFPTintForKey(NSString *key, UIImage *fallbackImage);
#endif

#ifndef _FLAGPAINT_DOMINANTCOLOR_XM
UIColor *HBFPGetDominantColor(UIImage *image);
#endif

static NSString *const HBFPPreferencesChangedNotification = @"HBFPPreferencesChangedNotification";
