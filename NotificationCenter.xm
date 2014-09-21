#import "Global.h"
#import "NSCache+Subscripting.h"
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <SpringBoard/SBBBSectionInfo.h>
#import <SpringBoard/SBBulletinViewController.h>
#import <SpringBoard/SBNotificationsBulletinCell.h>
#import <SpringBoard/SBNotificationsModeViewController.h>
#import <SpringBoard/SBNotificationsSectionHeaderView.h>

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

	self.view.layer.mask = nil;

	if (notificationCenterFade) {
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
		self.view.layer.mask = nil;
	}
}

%new - (void)_flagpaint_updateMaskWithOffset:(CGFloat)offset height:(CGFloat)height {
	if (!notificationCenterFade) {
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

	if (notificationCenterFade) {
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
		if (tintNotificationCenter) {
			self.clipsToBounds = NO;

			if (_UIAccessibilityEnhanceBackgroundContrast()) {
				UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.contentView.frame.size.width, self.contentView.frame.size.height)];
				backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				backgroundView.alpha = notificationCenterOpacity;
				[self.contentView insertSubview:backgroundView atIndex:0];

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
		frame.origin.x = -self.superview.frame.origin.x;
		frame.size.width = backdropView.superview.frame.size.width + self.superview.frame.origin.x * 2;
		backdropView.frame = frame;
	}
}

- (void)setFloating:(BOOL)floating {
	if (tintNotificationCenter) {
		CGFloat alpha = notificationCenterOpacity * (floating ? kHBFPNotificationHeaderBackgroundAlphaFloating : 1.f);

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
		UIScrollView *wrapperView = MSHookIvar<UIScrollView *>(self, "_wrapperView");

		self.clipsToBounds = NO;
		wrapperView.clipsToBounds = NO;

		UIView *backgroundView = [[UIView alloc] init];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		backgroundView.alpha = notificationCenterOpacity * kHBFPNotificationCellBackgroundAlphaNormal;
		backgroundView.hidden = !tintNotificationCenter;
		[self.realContentView insertSubview:backgroundView atIndex:0];

		objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		[[NSNotificationCenter defaultCenter] addObserverForName:HBFPPreferencesChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			backgroundView.hidden = !tintNotificationCenter;
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
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = notificationCenterOpacity * (highlighted ? kHBFPNotificationCellBackgroundAlphaHighlighted : 1.f);
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = notificationCenterOpacity * (selected ? kHBFPNotificationCellBackgroundAlphaSelected : 1.f);
	} else {
		%orig;
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
}

%end

#pragma mark - View controller hooks

%hook SBBulletinViewController

- (void)loadView {
	%orig;
	self.view.clipsToBounds = NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = %orig;

	if (tintNotificationCenter) {
		NSMutableArray *orderedSections = MSHookIvar<NSMutableArray *>(self, "_orderedSections");
		SBBBSectionInfo *sectionInfo = orderedSections[indexPath.section];

		if (sectionInfo && [sectionInfo respondsToSelector:@selector(identifier)] && sectionInfo.identifier) {
			NSString *key = sectionInfo.identifier;
			HBFPGetIconIfNeeded(key, nil, NO);

			if (!tintCache[key]) {
				tintCache[key] = HBFPGetDominantColor(iconCache[key]);
			}

			UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = tintCache[key];
		}
	}

	return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *header = %orig;

	if (!header || !tintNotificationCenter) {
		return header;
	}

	NSMutableArray *orderedSections = MSHookIvar<NSMutableArray *>(self, "_orderedSections");
	SBBBSectionInfo *sectionInfo = orderedSections[section];

	if (sectionInfo && [sectionInfo respondsToSelector:@selector(identifier)] && sectionInfo.identifier) {
		NSString *key = sectionInfo.identifier;
		HBFPGetIconIfNeeded(key, nil, NO);

		if (!tintCache[key]) {
			tintCache[key] = HBFPGetDominantColor(iconCache[key]);
		}

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			UIView *backgroundView = objc_getAssociatedObject(header, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = tintCache[key];
		} else {
			_UIBackdropViewSettings *settings = objc_getAssociatedObject(header, &kHBFPBackdropViewSettingsIdentifier);
			settings.colorTint = tintCache[key];
		}
	}

	return header;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:HBFPPreferencesChangedNotification object:nil];
	%orig;
}

%end

%group NotAukiHax
%hook SBBulletinViewController

%new - (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	SBNotificationsModeViewController *parentViewController = (SBNotificationsModeViewController *)self.parentViewController;

	if (parentViewController && [parentViewController isKindOfClass:%c(SBNotificationsModeViewController)]) {
		[parentViewController _flagpaint_updateMaskWithOffset:scrollView.contentOffset.y height:scrollView.contentSize.height];
	}
}

%end
%end

%ctor {
	if (![%c(SBBulletinViewController) instancesRespondToSelector:@selector(scrollViewDidScroll:)] && ![[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/auki.dylib"]) {
		%init(NotAukiHax);
	}

	%init;
}
