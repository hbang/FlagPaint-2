#import "HBFPPreferences.h"

@implementation HBFPPreferences

- (instancetype)init {
	self = [super init];

	if (self) {
		_preferences = [[HBPreferences alloc] initWithIdentifier:kHBFPPreferencesSuiteName];
		[_preferences registerDefaults:@{
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
	}

	return self;
}

@end
