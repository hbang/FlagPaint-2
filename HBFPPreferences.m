#import "HBFPPreferences.h"
#import <Cephei/HBPreferences.h>

static NSString *const kHBFPWinterBoardThemesKey = @"Themes";
static NSString *const kHBFPWinterBoardThemeActiveKey = @"Active";
static NSString *const kHBFPWinterBoardThemeNameKey = @"Name";
static NSString *const kHBFPWinterBoardPlistName = @"FlagPaint.plist";
static NSString *const kHBFPWinterBoardTintsKey = @"Tints";

@implementation HBFPPreferences {
	HBPreferences *_preferences;
	BOOL _hadFirstRun;
}

- (instancetype)init {
	self = [super init];

	if (self) {
		_preferences = [[HBPreferences alloc] initWithIdentifier:@"ws.hbang.flagpaint"];

		[_preferences registerBool:&_hadFirstRun default:NO forKey:@"HadFirstRun"];

		[_preferences registerBool:&_tintBanners default:YES forKey:@"Tint"];
		[_preferences registerBool:&_tintLockScreen default:YES forKey:@"TintLockScreen"];
		[_preferences registerBool:&_tintNotificationCenter default:YES forKey:@"TintNotificationCenter"];

		[_preferences registerBool:&_biggerIcon default:YES forKey:@"BiggerIcon"];
		[_preferences registerBool:&_albumArtIcon default:YES forKey:@"AlbumArt"];

		[_preferences registerBool:&_bannerGradient default:NO forKey:@"Gradient"];
		[_preferences registerBool:&_bannerBorderRadius default:NO forKey:@"BorderRadius"];
		[_preferences registerBool:&_bannerTextShadow default:NO forKey:@"TextShadow"];
		[_preferences registerBool:&_bannerRemoveGrabber default:YES forKey:@"RemoveGrabber"];

		[_preferences registerBool:&_lockGradient default:YES forKey:@"LockGradient"];
		[_preferences registerBool:&_lockFade default:YES forKey:@"LockFade"];
		[_preferences registerBool:&_lockDisableDimming default:YES forKey:@"LockDisableDimming"];
		[_preferences registerBool:&_lockRemoveAction default:NO forKey:@"RemoveLockAction"];

		[_preferences registerBool:&_notificationCenterFade default:YES forKey:@"NotificationCenterFade"];

		[_preferences registerFloat:&_tintVibrancy default:65.f forKey:@"TintVibrancy"];
		[_preferences registerFloat:&_bannerColorIntensity default:_UIAccessibilityEnhanceBackgroundContrast() ? 80.f : 40.f forKey:@"BannerColorIntensity"];
		[_preferences registerFloat:&_bannerGrayscaleIntensity default:40.f forKey:@"BannerGrayscaleIntensity"];
		[_preferences registerFloat:&_bannerOpacity default:100.f forKey:@"BannerOpacity"];
		[_preferences registerFloat:&_lockOpacity default:50.f forKey:@"LockOpacity"];
		[_preferences registerFloat:&_notificationCenterOpacity default:_UIAccessibilityEnhanceBackgroundContrast() ? 77.f : 15.f forKey:@"NotificationCenterOpacity"];

		[_preferences registerBool:&_removeIcon default:NO forKey:@"RemoveIcon"];
		[_preferences registerBool:&_removeDateLabel default:YES forKey:@"RemoveDateLabel"];

		[_preferences registerBool:&_fonz default:NO forKey:@"Fonz"];

		[self _reloadThemeTints];
	}

	return self;
}

- (BOOL)hadFirstRun {
	return _hadFirstRun;
}

- (void)setHadFirstRun:(BOOL)hadFirstRun {
	_hadFirstRun = YES;

	[_preferences setBool:YES forKey:@"HadFirstRun"];
	[_preferences synchronize];
}

#pragma mark - Custom/theme tints

- (void)_reloadThemeTints {
	NSDictionary *wbPreferences = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:@"file:///var/mobile/Library/Preferences/com.saurik.WinterBoard.plist"]];

	if (wbPreferences && wbPreferences[kHBFPWinterBoardThemesKey]) {
		_themeTints = nil;

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

		_themeTints = [newThemeTints copy];
	}
}

- (id)customTintForKey:(NSString *)key {
	id value = [_preferences objectForKey:[@"CustomTint-" stringByAppendingString:key]];
	HBLogDebug(@"%@: trying preferences (%@)", key, value);

	if (value) {
		return [self _tintForValue:value];
	}

	value = [_themeTints objectForKey:key];
	HBLogDebug(@"%@: trying theme (%@)", key, value);

	return [self _tintForValue:value];
}

- (UIColor *)_tintForValue:(id)value {
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

@end
