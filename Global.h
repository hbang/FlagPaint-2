@class BBBulletin;

extern BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

extern BOOL tintBanners, tintLockScreen, tintNotificationCenter;
extern BOOL biggerIcon, albumArtIcon;
extern BOOL bannerGradient, semiTransparent, borderRadius, textShadow;
extern BOOL lockGradient, lockFade, lockDisableDimming;
extern BOOL notificationCenterFade;
extern BOOL removeIcon, removeGrabber, removeDateLabel, removeAction;
extern CGFloat bannerColorIntensity, bannerGrayscaleIntensity, bannerOpacity;
extern CGFloat lockOpacity, notificationCenterOpacity;

extern BOOL hasBlurredClock;

extern NSMutableDictionary *tintCache;
extern NSMutableDictionary *iconCache;

extern UIColor *HBFPGetDominantColor(UIImage *image);
extern BOOL HBFPIsMusic(NSString *sectionID);
extern NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic);
extern void HBFPGetIconIfNeeded(NSString *key, BBBulletin *bulletin, BOOL isMusic);

static NSString *const HBFPPreferencesChangedNotification = @"HBFPPreferencesChangedNotification";
