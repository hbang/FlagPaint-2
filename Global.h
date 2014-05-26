extern BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

extern BOOL tintBanners, tintLockScreen, tintNotificationCenter;
extern BOOL biggerIcon, albumArtIcon;
extern BOOL bannerGradient, semiTransparent, borderRadius, textShadow;
extern BOOL lockGradient, lockFade;
extern BOOL removeIcon, removeGrabber, removeDateLabel, removeAction;
extern CGFloat bannerColorIntensity, bannerGrayscaleIntensity, lockOpacity;

extern NSMutableDictionary *tintCache;
extern NSMutableDictionary *iconCache;

extern UIColor *HBFPGetDominantColor(UIImage *image);
extern BOOL HBFPIsMusic(NSString *sectionID);
extern NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic);
extern void HBFPGetIconIfNeeded(NSString *key, NSString *sectionID, BOOL isMusic);

static NSString *const HBFPNotificationCenterSettingsChangedNotification = @"HBFPNotificationCenterSettingsChangedNotification";
