#import "NSCache+Subscripting.h"
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <SpringBoard/SBBBSectionInfo.h>
#import <SpringBoard/SBBulletinViewController.h>
#import <SpringBoard/SBNotificationCenterWidgetController.h>
#import <SpringBoard/SBNotificationsAllModeBulletinInfo.h>
#import <SpringBoard/SBNotificationsBulletinCell.h>
#import <SpringBoard/SBNotificationsModeViewController.h>
#import <SpringBoard/SBNotificationsSectionHeaderView.h>
#import <version.h>

static const char *kHBFPBackdropViewSettingsIdentifier;
static const char *kHBFPBackgroundGradientIdentifier;
static const char *kHBFPBackgroundViewIdentifier;
static const char *kHBFPPreferencesChangedIdentifier;

static CGFloat const kHBFPNotificationHeaderBackgroundAlphaFloating = 0.43f;

static CGFloat const kHBFPNotificationCellBackgroundAlphaNormal = 0.43f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaHighlighted = 0.86f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaSelected = 1.15f;

@interface SBNotificationsModeViewController (FlagPaint)

- (void)_flagpaint_updateMask;
- (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height;

@end

#pragma mark - Fade effect

%hook SBNotificationsModeViewController

- (void)loadView {
	%orig;

	[self _flagpaint_updateMask];

	[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
		objc_setAssociatedObject(self, &kHBFPPreferencesChangedIdentifier, @YES, OBJC_ASSOCIATION_ASSIGN);
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;

	if (((NSNumber *)objc_getAssociatedObject(self, &kHBFPPreferencesChangedIdentifier)).boolValue) {
		objc_setAssociatedObject(self, &kHBFPPreferencesChangedIdentifier, @NO, OBJC_ASSOCIATION_ASSIGN);

		SBNotificationsModeViewController *me = self;
		[(UITableView *)me.view.subviews[0] reloadData];
		[self _flagpaint_updateMask];
	}
}

%new - (void)_flagpaint_updateMask {
	SBNotificationsModeViewController *me = self;

	if (preferences.notificationCenterFade) {
		CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
		me.view.layer.mask = gradientLayer;

		objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		gradientLayer.colors = @[
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.1f].CGColor
		];

		[self _flagpaint_updateMaskWithOffset:0.f height:me.view.frame.size.height];
	} else {
		me.view.layer.mask = nil;
	}
}

%new - (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height {
	if (!preferences.notificationCenterFade) {
		return;
	}

	CGFloat viewport = IS_IPAD ? 1000.f : 500.f, bottomMin = 0.9f;
	CGFloat bottom = MAX(bottomMin + ((offset - viewport) / height), bottomMin);

	if (bottom < 0) {
		bottom = bottomMin;
	}

	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
	gradientLayer.locations = @[ @0, @(bottom), @1 ];
}

- (void)viewWillLayoutSubviews {
	%orig;

	if (preferences.notificationCenterFade) {
		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);

		SBNotificationsModeViewController *me = self;
		if (!CGRectEqualToRect(gradientLayer.frame, me.view.bounds)) {
			gradientLayer.frame = me.view.bounds;
		}
	}
}

%end

#pragma mark - Header

%hook SBNotificationsSectionHeaderView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (preferences.tintNotificationCenter) {
			((SBNotificationsSectionHeaderView *)self).clipsToBounds = NO;

			CGFloat notificationCenterOpacity = preferences.notificationCenterOpacity / 100.f;

			if (_UIAccessibilityEnhanceBackgroundContrast()) {
				UIView *backgroundView = [[UIView alloc] initWithFrame:((SBNotificationsSectionHeaderView *)self).contentView.bounds];
				backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				backgroundView.alpha = notificationCenterOpacity;
				[((SBNotificationsSectionHeaderView *)self).contentView insertSubview:backgroundView atIndex:0];

				objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			} else {
				_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdrop");

				_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
				settings.colorTint = [UIColor blackColor];
				settings.colorTintAlpha = notificationCenterOpacity;
				[backdropView transitionToSettings:settings];

				objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if (IS_IPAD) {
		_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdrop");

		CGRect frame = backdropView.frame;
		frame.origin.x = -((SBNotificationsSectionHeaderView *)self).superview.frame.origin.x;
		frame.size.width = backdropView.superview.frame.size.width + ((SBNotificationsSectionHeaderView *)self).superview.frame.origin.x * 2;
		backdropView.frame = frame;
	}
}

- (void)setFloating:(BOOL)floating {
	if (preferences.tintNotificationCenter) {
		CGFloat alpha = (preferences.notificationCenterOpacity / 100.f) * (floating ? kHBFPNotificationHeaderBackgroundAlphaFloating : 1.f);

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
			backgroundView.alpha = alpha;
		} else {
			_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);
			settings.grayscaleTintAlpha = alpha;
		}
	} else {
		%orig;
	}
}

%end

#pragma mark - Cell

%hook SBNotificationsBulletinCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		self.clipsToBounds = NO;

		if (!IS_IOS_OR_NEWER(iOS_8_0)) {
			UIScrollView *wrapperView = MSHookIvar<UIScrollView *>(self, "_wrapperView");
			wrapperView.clipsToBounds = NO;
		}

		UIView *backgroundView = [[UIView alloc] init];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		backgroundView.alpha = (preferences.notificationCenterOpacity / 100.f) * kHBFPNotificationCellBackgroundAlphaNormal;
		backgroundView.hidden = !preferences.tintNotificationCenter;
		[self.contentView insertSubview:backgroundView atIndex:0];

		objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			backgroundView.hidden = !preferences.tintNotificationCenter;
		}];
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	CGFloat padding = IS_IPAD ? self.superview.superview.frame.origin.x : 0;
	UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
	backgroundView.frame = CGRectMake(-padding, 0, self.frame.size.width + padding * 2, self.frame.size.height);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	if (preferences.tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = (preferences.notificationCenterOpacity / 100.f) * (highlighted ? kHBFPNotificationCellBackgroundAlphaHighlighted : 1.f);
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (preferences.tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = (preferences.notificationCenterOpacity / 100.f) * (selected ? kHBFPNotificationCellBackgroundAlphaSelected : 1.f);
	} else {
		%orig;
	}
}

%end

#pragma mark - KVO hax

// TODO: move to own files

@interface HBFPBulletinViewControllerKVOObserver : NSObject

@end

@implementation HBFPBulletinViewControllerKVOObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (![keyPath isEqualToString:@"contentOffset"]) {
		return;
	}

	SBBulletinViewController *viewController = (__bridge id)context;
	UIScrollView *scrollView = object;

	SBNotificationsModeViewController *parentViewController = (SBNotificationsModeViewController *)viewController.parentViewController;

	if (parentViewController && [parentViewController isKindOfClass:%c(SBNotificationsModeViewController)]) {
		[parentViewController _flagpaint_updateMaskWithOffset:scrollView.contentOffset.y height:scrollView.contentSize.height];
	}
}

@end

#pragma mark - View controller hooks

%hook SBNotificationsAllModeBulletinInfo

- (void)populateReusableView:(UITableViewCell *)cell {
	%orig;

	//NSString *key = HBFPGetKey(self.representedBulletin, nil);

	SBNotificationsAllModeBulletinInfo *me = self;

	UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
	backgroundView.backgroundColor = HBFPTintForKey([(id)me.representedBulletin performSelector:@selector(sectionID)], nil);
}

%end

%hook SBBulletinViewController

- (void)loadView {
	%orig;

	self.view.clipsToBounds = NO;

	HBFPBulletinViewControllerKVOObserver *observer = [[HBFPBulletinViewControllerKVOObserver alloc] init];
	[self.view addObserver:observer forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:(__bridge void *)self];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *header = %orig;

	if (!header || !preferences.tintNotificationCenter) {
		return header;
	}

	NSMutableArray *orderedSections = MSHookIvar<NSMutableArray *>(self, "_orderedSections");
	SBBBSectionInfo *sectionInfo = orderedSections[section];

	if (sectionInfo && [sectionInfo respondsToSelector:@selector(identifier)] && sectionInfo.identifier) {
		NSString *identifier = sectionInfo.identifier;

		if ([sectionInfo respondsToSelector:@selector(widgetBulletinInfo)] && %c(SBNotificationCenterWidgetController)) {
			identifier = [%c(SBNotificationCenterWidgetController) containingBundleIdentifierForWidgetWithBundleIdentifer:identifier] ?: identifier;
		}

		NSString *key = HBFPGetKey(nil, identifier);
		UIImageView *iconImageView = MSHookIvar<UIImageView *>(header, "_iconImageView");

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			UIView *backgroundView = objc_getAssociatedObject(header, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = HBFPTintForKey(key, iconImageView.image);
		} else {
			_UIBackdropViewSettings *settings = objc_getAssociatedObject(header, &kHBFPBackdropViewSettingsIdentifier);
			settings.colorTint = HBFPTintForKey(key, iconImageView.image);
		}
	}

	return header;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:HBFPPreferencesChangedNotification object:nil];
	%orig;
}

%end

#pragma mark - Constructor

%ctor {
	Class headerClass = %c(SBNotificationCenterHeaderView) ?: %c(SBNotificationsSectionHeaderView);
	Class viewControllerClass = %c(SBNotificationsModeViewController) ?: %c(SBNotificationsViewController);
	Class infoClass = %c(SBNotificationsAllModeBulletinInfo) ?: %c(SBNotificationBulletinInfo);

	%init(_ungrouped,
		SBNotificationsSectionHeaderView = headerClass,
		SBNotificationsModeViewController = viewControllerClass,
		SBNotificationsAllModeBulletinInfo = infoClass);
}
