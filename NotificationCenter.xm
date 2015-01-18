#import "Global.h"
#import "NSCache+Subscripting.h"
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <SpringBoard/SBBBSectionInfo.h>
#import <SpringBoard/SBBulletinViewController.h>
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

		[(UITableView *)self.view.subviews[0] reloadData];
		[self _flagpaint_updateMask];
	}
}

%new - (void)_flagpaint_updateMask {
	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
	[gradientLayer release];

	if ([preferences boolForKey:kHBFPPreferencesNotificationCenterFadeKey]) {
		CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
		self.view.layer.mask = gradientLayer;

		objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		gradientLayer.colors = @[
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.1f].CGColor
		];

		[self _flagpaint_updateMaskWithOffset:0.f height:self.view.frame.size.height];
	} else {
		[self.view.layer.mask release];
		self.view.layer.mask = nil;
	}
}

%new - (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height {
	if (![preferences boolForKey:kHBFPPreferencesNotificationCenterFadeKey]) {
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

	if ([preferences boolForKey:kHBFPPreferencesNotificationCenterFadeKey]) {
		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);

		if (!CGRectEqualToRect(gradientLayer.frame, self.view.bounds)) {
			gradientLayer.frame = self.view.bounds;
		}
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	%orig;
}

%end

#pragma mark - Header

%hook SBNotificationsSectionHeaderView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if ([preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey]) {
			((SBNotificationsSectionHeaderView *)self).clipsToBounds = NO;

			CGFloat notificationCenterOpacity = [preferences floatForKey:kHBFPPreferencesNotificationCenterOpacityKey] / 100.f;

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
	if ([preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey]) {
		CGFloat alpha = ([preferences floatForKey:kHBFPPreferencesNotificationCenterOpacityKey] / 100.f) * (floating ? kHBFPNotificationHeaderBackgroundAlphaFloating : 1.f);

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

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier) release];
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
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
		backgroundView.alpha = ([preferences boolForKey:kHBFPPreferencesNotificationCenterOpacityKey] / 100.f) * kHBFPNotificationCellBackgroundAlphaNormal;
		backgroundView.hidden = ![preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey];
		[self.contentView insertSubview:backgroundView atIndex:0];

		objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			backgroundView.hidden = ![preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey];
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
	if ([preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey]) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = ([preferences floatForKey:kHBFPPreferencesNotificationCenterOpacityKey] / 100.f) * (highlighted ? kHBFPNotificationCellBackgroundAlphaHighlighted : 1.f);
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if ([preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey]) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = ([preferences floatForKey:kHBFPPreferencesNotificationCenterOpacityKey] / 100.f) * (selected ? kHBFPNotificationCellBackgroundAlphaSelected : 1.f);
	} else {
		%orig;
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
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

	SBBulletinViewController *viewController = (id)context;
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

	UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
	backgroundView.backgroundColor = HBFPTintForKey([(id)self.representedBulletin performSelector:@selector(sectionID)]);
}

%end

%hook SBBulletinViewController

- (void)loadView {
	%orig;

	self.view.clipsToBounds = NO;

	HBFPBulletinViewControllerKVOObserver *observer = [[HBFPBulletinViewControllerKVOObserver alloc] init];
	[self.view addObserver:observer forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:self];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *header = %orig;

	if (!header || ![preferences boolForKey:kHBFPPreferencesTintNotificationCenterKey]) {
		return header;
	}

	NSMutableArray *orderedSections = MSHookIvar<NSMutableArray *>(self, "_orderedSections");
	SBBBSectionInfo *sectionInfo = orderedSections[section];

	if (sectionInfo && [sectionInfo respondsToSelector:@selector(identifier)] && sectionInfo.identifier) {
		NSString *key = HBFPGetKey(nil, sectionInfo.identifier);

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			UIView *backgroundView = objc_getAssociatedObject(header, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = HBFPTintForKey(key);
		} else {
			_UIBackdropViewSettings *settings = objc_getAssociatedObject(header, &kHBFPBackdropViewSettingsIdentifier);
			settings.colorTint = HBFPTintForKey(key);
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
	%init(_ungrouped, SBNotificationsSectionHeaderView = headerClass);
}
