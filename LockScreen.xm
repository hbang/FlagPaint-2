#import "Global.h"
#import "HBFPGradientView.h"
#import "NSCache+Subscripting.h"
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBAwayBulletinListItem.h>
#import <SpringBoard/SBAwayNotificationListCell.h>
#import <SpringBoard/SBLockScreenActionContext.h>
#import <SpringBoard/SBLockScreenNotificationCell.h>
#import <SpringBoard/SBLockScreenNotificationListView.h>
#import <SpringBoard/SBLockScreenNotificationModel.h>
#import <version.h>

static const char *kHBFPBackgroundGradientIdentifier;
static const char *kHBFPBackgroundViewIdentifier;

@interface SBLockScreenNotificationListView (FlagPaint)

- (void)_flagpaint_updateMask;
- (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height;

@end

%hook SBLockScreenNotificationListView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		[self _flagpaint_updateMask];
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if ([preferences boolForKey:kHBFPPreferencesLockFadeKey]) {
		UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");
		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);

		if (!CGRectEqualToRect(gradientLayer.frame, containerView.bounds)) {
			gradientLayer.frame = containerView.bounds;
		}
	}
}

- (SBLockScreenNotificationCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBLockScreenNotificationCell *cell = %orig;
	SBAwayBulletinListItem *listItem = [self.model listItemAtIndexPath:indexPath];

	if (![listItem isKindOfClass:%c(SBAwayBulletinListItem)]) {
		return cell;
	}

	if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey] || [preferences boolForKey:kHBFPPreferencesBiggerIconKey]) {
		if (![listItem respondsToSelector:@selector(activeBulletin)] || !listItem.activeBulletin) {
			return cell;
		}

		BBBulletin *bulletin = listItem.activeBulletin;
		UIImageView *iconImageView = MSHookIvar<UIImageView *>(cell, "_iconImageView");

		NSString *key = HBFPGetKey(bulletin, nil);
		BOOL isMusic = HBFPIsMusic(key);
		BOOL isAvatar = hasMessagesAvatarTweak && [bulletin.sectionID isEqualToString:@"com.apple.MobileSMS"];

		if (isAvatar) {
			iconImageView.clipsToBounds = YES;
			iconCache[key] = iconImageView.image;
		}

		if ([preferences boolForKey:kHBFPPreferencesBiggerIconKey]) {
			iconImageView.image = HBFPIconForKey(key, iconImageView.image);
		}

		if (isMusic) {
			iconImageView.layer.minificationFilter = kCAFilterTrilinear;
		}

		if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey]) {
			UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = HBFPTintForKey(key, iconImageView.image);
		}
	}

	return cell;
}

%new - (void)_flagpaint_updateMask {
	UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");
	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
	[gradientLayer release];

	if ([preferences boolForKey:kHBFPPreferencesLockFadeKey]) {
		CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
		containerView.layer.mask = gradientLayer;

		objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		gradientLayer.colors = @[
			hasBlurredClock ? (id)[UIColor whiteColor].CGColor : (id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.1f].CGColor
		];

		[self _flagpaint_updateMaskWithOffset:0.f height:containerView.frame.size.height];
	}
}

%new - (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height {
	if (![preferences boolForKey:kHBFPPreferencesLockFadeKey]) {
		return;
	}

	CGFloat viewport = 50.f, topMax = IS_IPAD ? 0.2f : 0.05f, bottomMin = 0.9f;
	CGFloat top = MIN(offset / viewport * topMax, topMax), bottom = MAX(bottomMin + ((offset - viewport) / height), bottomMin);

	if (top < 0 || hasBlurredClock) {
		top = 0;
	}

	if (bottom < 0) {
		bottom = bottomMin;
	}

	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
	gradientLayer.locations = @[ @0, @(top), @(bottom), @1 ];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	%orig;

	if (scrollView.class == %c(SBLockScreenNotificationTableView)) {
		[self _flagpaint_updateMaskWithOffset:scrollView.contentOffset.y height:scrollView.contentSize.height];
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	%orig;
}

%end

%hook SBLockScreenBulletinCell

+ (BOOL)wantsUnlockActionText {
	return [preferences boolForKey:kHBFPPreferencesRemoveLockActionKey] ? NO : %orig;
}

%group LockScreenBulletinCellIve

+ (CGFloat)rowHeightForTitle:(NSString *)title subtitle:(NSString *)subtitle body:(NSString *)body maxLines:(NSUInteger)maxLines attachmentSize:(CGSize)attachmentSize datesVisible:(BOOL)datesVisible rowWidth:(CGFloat)rowWidth includeUnlockActionText:(BOOL)includeUnlockActionText {
	return %orig(title, subtitle, body, maxLines, attachmentSize, datesVisible, rowWidth, [preferences boolForKey:kHBFPPreferencesRemoveLockActionKey] ? NO : includeUnlockActionText);
}

%end

%group LockScreenBulletinCellFederighi

+ (CGFloat)rowHeightForTitle:(NSString *)title subtitle:(NSString *)subtitle body:(NSString *)body maxLines:(NSUInteger)maxLines attachmentSize:(CGSize)attachmentSize secondaryContentSize:(CGSize)secondaryContentSize datesVisible:(BOOL)datesVisible rowWidth:(CGFloat)rowWidth includeUnlockActionText:(BOOL)includeUnlockActionText {
	return %orig(title, subtitle, body, maxLines, attachmentSize, secondaryContentSize, datesVisible, rowWidth, [preferences boolForKey:kHBFPPreferencesRemoveLockActionKey] ? NO : includeUnlockActionText);
}

%end

%end

%hook SBLockScreenNotificationCell

+ (CGFloat)contentWidthWithRowWidth:(CGFloat)rowWidth andAttachmentSize:(CGSize)attachmentSize {
	return %orig([preferences boolForKey:kHBFPPreferencesBiggerIconKey] && IS_IPAD ? rowWidth - 16.f : rowWidth, attachmentSize);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey]) {
			UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			backgroundView.alpha = [preferences floatForKey:kHBFPPreferencesLockOpacityKey] / 100.f;
			[self.realContentView insertSubview:backgroundView atIndex:0];

			objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			if ([preferences boolForKey:kHBFPPreferencesLockGradientKey]) {
				static BOOL IsRTL;
				static dispatch_once_t onceToken;
				dispatch_once(&onceToken, ^{
					IsRTL = [NSLocale characterDirectionForLanguage:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]] == NSLocaleLanguageDirectionRightToLeft;
				});

				NSArray *locations = @[ @0, @0.2f, @0.4f, @1 ];

				CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
				gradientLayer.locations = IsRTL ? locations.reverseObjectEnumerator.allObjects : locations;
				gradientLayer.startPoint = CGPointMake(0, 0.5f);
				gradientLayer.endPoint = CGPointMake(1.f, 0.5f);
				gradientLayer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:1.f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.625f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.25f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.0625f].CGColor
				];
				backgroundView.layer.mask = gradientLayer;

				objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey] || [preferences boolForKey:kHBFPPreferencesBiggerIconKey]) {
		if ([preferences boolForKey:kHBFPPreferencesBiggerIconKey]) {
			UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");

			if (IS_IPAD) {
				iconImageView.frame = CGRectMake(9.f, 15.5f, 29.f, 29.f);

				UILabel *primaryLabel = MSHookIvar<UILabel *>(self, "_primaryLabel");
				CGRect primaryFrame = primaryLabel.frame;
				primaryFrame.origin.x += 16.f;
				primaryLabel.frame = primaryFrame;

				UILabel *subtitleLabel = MSHookIvar<UILabel *>(self, "_subtitleLabel");
				CGRect subtitleFrame = subtitleLabel.frame;
				subtitleFrame.origin.x += 16.f;
				subtitleLabel.frame = subtitleFrame;

				UILabel *secondaryLabel = MSHookIvar<UILabel *>(self, "_secondaryLabel");
				CGRect secondaryFrame = secondaryLabel.frame;
				secondaryFrame.origin.x += 16.f;
				secondaryLabel.frame = secondaryFrame;

				UILabel *relevanceDateLabel = MSHookIvar<UILabel *>(self, "_relevanceDateLabel");
				CGRect relevanceDateFrame = relevanceDateLabel.frame;
				relevanceDateFrame.origin.x += 16.f;
				relevanceDateLabel.frame = relevanceDateFrame;

				UILabel *unlockTextLabel = MSHookIvar<UILabel *>(self, "_unlockTextLabel");
				CGRect unlockTextFrame = unlockTextLabel.frame;
				unlockTextFrame.origin.x += 16.f;
				unlockTextLabel.frame = unlockTextFrame;
			} else {
				iconImageView.frame = CGRectMake(9.f, 12.5f, 29.f, 29.f);
			}

			if (hasMessagesAvatarTweak && self.lockScreenActionContext.bulletin && [self.lockScreenActionContext.bulletin.sectionID isEqualToString:@"com.apple.MobileSMS"]) {
				iconImageView.layer.cornerRadius = iconImageView.frame.size.width / 2;
			}
		}

		if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey] && [preferences boolForKey:kHBFPPreferencesLockGradientKey]) {
			CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
			gradientLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
		}
	}
}

- (void)setContentAlpha:(CGFloat)contentAlpha {
	%orig([preferences boolForKey:kHBFPPreferencesLockDisableDimmingKey] ? 1 : contentAlpha);
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
}

%end

%group ClassicLockScreen
%hook CSAwayNotificationController

- (SBAwayNotificationListCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBAwayNotificationListCell *cell = %orig;

	if ([preferences boolForKey:kHBFPPreferencesTintLockScreenKey]) {
		UIImageView *icon = MSHookIvar<UIImageView *>(cell, "_icon");
		NSString *key = HBFPGetKey(cell.bulletin, nil);
		cell.backgroundColor = HBFPTintForKey(key, icon.image);
	}

	return cell;
}

%end
%end

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib"]) {
		dlopen("/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib", RTLD_NOW);
	}

	%init;

	if (%c(CSAwayNotificationController)) {
		%init(ClassicLockScreen);
	}

	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		%init(LockScreenBulletinCellFederighi);
	} else {
		%init(LockScreenBulletinCellIve);
	}
}
