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

static CGFloat const kHBFPNotificationHeaderBackgroundAlphaFloating = 0.43f;

static CGFloat const kHBFPNotificationCellBackgroundAlphaNormal = 0.43f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaHighlighted = 0.86f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaSelected = 1.15f;

@interface SBNotificationsModeViewController ()

- (void)_flagpaint_updateMask;
- (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height;

@property (nonatomic, retain) CAGradientLayer *_flagpaint_gradientLayer;
@property (nonatomic) BOOL _flagpaint_preferencesChanged;

@end

@interface SBNotificationsSectionHeaderView ()

@property (nonatomic, retain) UIView *_flagpaint_backgroundView;
@property (nonatomic, retain) _UIBackdropViewSettings *_flagpaint_backdropViewSettings;

@end

@interface SBNotificationsBulletinCell ()

@property (nonatomic, retain) UIView *_flagpaint_backgroundView;

@end

#pragma mark - Fade effect

%hook SBNotificationsModeViewController

%property (nonatomic, retain) CAGradientLayer *_flagpaint_gradientLayer;
%property (nonatomic, assign) BOOL _flagpaint_preferencesChanged;

- (void)loadView {
	%orig;

	[self _flagpaint_updateMask];

	[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
		self._flagpaint_preferencesChanged = YES;
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;

	if (self._flagpaint_preferencesChanged) {
		self._flagpaint_preferencesChanged = NO;

		[(UITableView *)self.view.subviews[0] reloadData];
		[self _flagpaint_updateMask];
	}
}

%new - (void)_flagpaint_updateMask {
	if (preferences.notificationCenterFade) {
		CAGradientLayer *gradientLayer = [CAGradientLayer layer];
		self.view.layer.mask = gradientLayer;
		self._flagpaint_gradientLayer = gradientLayer;

		gradientLayer.colors = @[
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.1f].CGColor
		];

		[self _flagpaint_updateMaskWithOffset:0.f height:self.view.frame.size.height];
	} else {
		self.view.layer.mask = nil;
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

	self._flagpaint_gradientLayer.locations = @[ @0, @(bottom), @1 ];
}

- (void)viewWillLayoutSubviews {
	%orig;

	if (preferences.notificationCenterFade) {
		CAGradientLayer *gradientLayer = self._flagpaint_gradientLayer;

		if (!CGRectEqualToRect(gradientLayer.frame, self.view.bounds)) {
			gradientLayer.frame = self.view.bounds;
		}
	}
}

%end

#pragma mark - Header

%hook SBNotificationsSectionHeaderView

%property (nonatomic, retain) UIView *_flagpaint_backgroundView;
%property (nonatomic, retain) _UIBackdropViewSettings *_flagpaint_backdropViewSettings;

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (preferences.tintNotificationCenter) {
			self.clipsToBounds = NO;

			CGFloat notificationCenterOpacity = preferences.notificationCenterOpacity / 100.f;

			if (_UIAccessibilityEnhanceBackgroundContrast()) {
				UIView *backgroundView = [[UIView alloc] initWithFrame:((SBNotificationsSectionHeaderView *)self).contentView.bounds];
				backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				backgroundView.alpha = notificationCenterOpacity;
				[self.contentView insertSubview:backgroundView atIndex:0];

				self._flagpaint_backgroundView = backgroundView;
			} else {
				_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdrop");

				_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
				settings.colorTint = [UIColor blackColor];
				settings.colorTintAlpha = notificationCenterOpacity;
				[backdropView transitionToSettings:settings];

				self._flagpaint_backdropViewSettings = settings;
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
		frame.origin.x = -self.superview.frame.origin.x;
		frame.size.width = backdropView.superview.frame.size.width + self.superview.frame.origin.x * 2;
		backdropView.frame = frame;
	}
}

- (void)setFloating:(BOOL)floating {
	if (preferences.tintNotificationCenter) {
		CGFloat alpha = (preferences.notificationCenterOpacity / 100.f) * (floating ? kHBFPNotificationHeaderBackgroundAlphaFloating : 1.f);

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			self._flagpaint_backgroundView.alpha = alpha;
		} else {
			self._flagpaint_backdropViewSettings.grayscaleTintAlpha = alpha;
		}
	} else {
		%orig;
	}
}

%end

#pragma mark - Cell

%hook SBNotificationsBulletinCell

%property (nonatomic, retain) UIView *_flagpaint_backgroundView;

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

		self._flagpaint_backgroundView = backgroundView;

		[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			backgroundView.hidden = !preferences.tintNotificationCenter;
		}];
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	CGFloat padding = IS_IPAD ? self.superview.superview.frame.origin.x : 0;
	self._flagpaint_backgroundView.frame = CGRectMake(-padding, 0, self.frame.size.width + padding * 2, self.frame.size.height);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	if (preferences.tintNotificationCenter) {
		self._flagpaint_backgroundView.alpha = (preferences.notificationCenterOpacity / 100.f) * (highlighted ? kHBFPNotificationCellBackgroundAlphaHighlighted : 1.f);
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (preferences.tintNotificationCenter) {
		self._flagpaint_backgroundView.alpha = (preferences.notificationCenterOpacity / 100.f) * (selected ? kHBFPNotificationCellBackgroundAlphaSelected : 1.f);
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

- (void)populateReusableView:(SBNotificationsBulletinCell *)cell {
	%orig;

	cell._flagpaint_backgroundView.backgroundColor = HBFPTintForKey([(id)self.representedBulletin performSelector:@selector(sectionID)], nil);
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
	SBNotificationsSectionHeaderView *header = (SBNotificationsSectionHeaderView *)%orig;

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
			header._flagpaint_backgroundView.backgroundColor = HBFPTintForKey(key, iconImageView.image);
		} else {
			header._flagpaint_backdropViewSettings.colorTint = HBFPTintForKey(key, iconImageView.image);
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
