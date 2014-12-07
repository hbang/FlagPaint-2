@class BBBulletin;

#pragma mark - Preferences

static NSString *const kHBFPPreferencesSuiteName = @"ws.hbang.flagpaint";

static NSString *const kHBFPPreferencesTintBannersKey = @"Tint";
static NSString *const kHBFPPreferencesTintLockScreenKey = @"TintLockScreen";
static NSString *const kHBFPPreferencesTintNotificationCenterKey = @"TintNotificationCenter";

static NSString *const kHBFPPreferencesBiggerIconKey = @"BigIcon";
static NSString *const kHBFPPreferencesAlbumArtIconKey = @"AlbumArt";

static NSString *const kHBFPPreferencesBannerGradientKey = @"Gradient";
static NSString *const kHBFPPreferencesBannerBorderRadiusKey = @"BorderRadius";
static NSString *const kHBFPPreferencesBannerTextShadowKey = @"TextShadow";
static NSString *const kHBFPPreferencesBannerColorIntensityKey = @"BannerColorIntensity";
static NSString *const kHBFPPreferencesBannerGrayscaleIntensityKey = @"BannerGrayscaleIntensity";
static NSString *const kHBFPPreferencesBannerOpacityKey = @"BannerOpacity";

static NSString *const kHBFPPreferencesLockGradientKey = @"LockGradient";
static NSString *const kHBFPPreferencesLockFadeKey = @"LockFade";
static NSString *const kHBFPPreferencesLockOpacityKey = @"LockOpacity";
static NSString *const kHBFPPreferencesLockDisableDimmingKey = @"LockDisableDimming";

static NSString *const kHBFPPreferencesNotificationCenterFadeKey = @"NotificationCenterFade";
static NSString *const kHBFPPreferencesNotificationCenterOpacityKey = @"NotificationCenterOpacity";

static NSString *const kHBFPPreferencesRemoveIconKey = @"RemoveIcon";
static NSString *const kHBFPPreferencesRemoveGrabberKey = @"RemoveGrabber";
static NSString *const kHBFPPreferencesRemoveDateLabelKey = @"RemoveDateLabel";
static NSString *const kHBFPPreferencesRemoveLockActionKey = @"RemoveLockAction";

static NSString *const kHBFPPreferencesFonzKey = @"Fonz";
static NSString *const kHBFPPreferencesHadFirstRunKey = @"HadFirstRun";

static NSString *const kHBFPSubtleLockPreferencesSuiteName = @"com.michaelpoole.subtlelock";
static NSString *const kHBFPSubtleLockPreferencesBlurredClockBGKey = @"BlurredClockBG";

#pragma mark - Other

#ifndef _FLAGPAINT_TWEAK_XM
extern BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

extern NSUserDefaults *userDefaults;
extern BOOL hasBlurredClock;

extern NSCache *tintCache;
extern NSCache *iconCache;

extern UIColor *HBFPGetDominantColor(UIImage *image);
extern BOOL HBFPIsMusic(NSString *sectionID);
extern NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic);
extern void HBFPGetIconIfNeeded(NSString *key, BBBulletin *bulletin, BOOL isMusic);
#endif

static NSString *const HBFPPreferencesChangedNotification = @"HBFPPreferencesChangedNotification";
