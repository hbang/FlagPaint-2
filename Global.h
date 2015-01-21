#import <Cephei/HBPreferences.h>

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

static NSString *const kHBFPWinterBoardThemesKey = @"Themes";
static NSString *const kHBFPWinterBoardThemeActiveKey = @"Active";
static NSString *const kHBFPWinterBoardThemeNameKey = @"Name";
static NSString *const kHBFPWinterBoardPlistName = @"FlagPaint.plist";
static NSString *const kHBFPWinterBoardTintsKey = @"Tints";

#pragma mark - Other

#ifndef _FLAGPAINT_TWEAK_XM
extern BOOL (*_UIAccessibilityEnhanceBackgroundContrast)();

extern HBPreferences *preferences;
extern BOOL hasBlurredClock, hasMessagesAvatarTweak;

extern NSCache *tintCache, *iconCache;

extern BOOL HBFPIsMusic(NSString *key);
extern NSString *HBFPGetKey(BBBulletin *bulletin, NSString *sectionID);
extern UIImage *HBFPIconForKey(NSString *key);
extern UIColor *HBFPTintForKey(NSString *key);
#endif

static NSString *const HBFPPreferencesChangedNotification = @"HBFPPreferencesChangedNotification";
