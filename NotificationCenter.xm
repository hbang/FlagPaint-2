#import "Global.h"
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

static CGFloat const kHBFPNotificationHeaderBackgroundAlphaNormal = 0.35f;
static CGFloat const kHBFPNotificationHeaderBackgroundAlphaNormalHighContrast = 0.77f;
static CGFloat const kHBFPNotificationHeaderBackgroundAlphaFloating = 0.15f;
static CGFloat const kHBFPNotificationHeaderBackgroundAlphaFloatingHighContrast = 0.78f;

static CGFloat const kHBFPNotificationCellBackgroundAlphaNormal = 0.15f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaNormalHighContrast = 0.85f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaHighlighted = 0.3f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaHighlightedHighContrast = 0.8f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaSelected = 0.4f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaSelectedHighContrast = 0.8f;

static CGFloat const kHBFPNotificaitonCenterIPadPadding = 1024.f; // lazy

#pragma mark - Fade effect

%hook SBNotificationsModeViewController

- (void)loadView {
	%orig;

	if (YES) { // TODO
		CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
		gradientLayer.locations = IS_IPAD ? @[ @0, @0.02f, @0.98f, @1 ] : @[ @0, @0.96f, @1 ];
		gradientLayer.colors = IS_IPAD ? @[
			(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor
		] : @[
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor whiteColor].CGColor,
			(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor
		];
		self.view.layer.mask = gradientLayer;

		objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

- (void)viewWillLayoutSubviews {
	%orig;

	if (YES) { // TODO
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
				backgroundView.alpha = _UIAccessibilityEnhanceBackgroundContrast() ? kHBFPNotificationHeaderBackgroundAlphaNormalHighContrast : kHBFPNotificationHeaderBackgroundAlphaNormal;
				[self.contentView insertSubview:backgroundView atIndex:0];

				objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			} else {
				_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdrop");

				_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
				settings.colorTint = [UIColor blackColor];
				settings.colorTintAlpha = _UIAccessibilityEnhanceBackgroundContrast() ? kHBFPNotificationHeaderBackgroundAlphaNormalHighContrast : kHBFPNotificationHeaderBackgroundAlphaNormal;
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
		frame.origin.x = -kHBFPNotificaitonCenterIPadPadding;
		frame.size.width = backdropView.superview.frame.size.width + kHBFPNotificaitonCenterIPadPadding * 2;
		backdropView.frame = frame;
	}
}

- (void)setFloating:(BOOL)floating {
	if (tintNotificationCenter) {

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
			backgroundView.alpha = floating ? kHBFPNotificationHeaderBackgroundAlphaFloatingHighContrast : kHBFPNotificationHeaderBackgroundAlphaNormalHighContrast;
		} else {
			_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);
			settings.grayscaleTintAlpha = floating ? kHBFPNotificationHeaderBackgroundAlphaFloating : kHBFPNotificationHeaderBackgroundAlphaNormal;
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
		UIScrollView *wrapperView = MSHookIvar<UIScrollView *>(self, "_wrapperView");;

		self.clipsToBounds = NO;
		wrapperView.clipsToBounds = NO;

		UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(IS_IPAD ? -kHBFPNotificaitonCenterIPadPadding : 0, 0, self.realContentView.frame.size.width + (IS_IPAD ? kHBFPNotificaitonCenterIPadPadding * 2 : 0), self.realContentView.frame.size.height)];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		backgroundView.alpha = _UIAccessibilityEnhanceBackgroundContrast() ? kHBFPNotificationCellBackgroundAlphaNormalHighContrast : kHBFPNotificationCellBackgroundAlphaNormal;
		backgroundView.hidden = !tintNotificationCenter;
		[self.realContentView insertSubview:backgroundView atIndex:0];

		objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		[[NSNotificationCenter defaultCenter] addObserverForName:HBFPNotificationCenterSettingsChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			backgroundView.hidden = !tintNotificationCenter;
		}];
	}

	return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			backgroundView.alpha = highlighted ? kHBFPNotificationCellBackgroundAlphaHighlightedHighContrast : kHBFPNotificationCellBackgroundAlphaNormalHighContrast;
		} else {
			backgroundView.alpha = highlighted ? kHBFPNotificationCellBackgroundAlphaHighlighted : kHBFPNotificationCellBackgroundAlphaNormal;
		}
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);

		if (_UIAccessibilityEnhanceBackgroundContrast()) {
			backgroundView.alpha = selected ? kHBFPNotificationCellBackgroundAlphaSelectedHighContrast : kHBFPNotificationCellBackgroundAlphaNormalHighContrast;
		} else {
			backgroundView.alpha = selected ? kHBFPNotificationCellBackgroundAlphaSelected : kHBFPNotificationCellBackgroundAlphaNormal;
		}
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

	[[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:HBFPNotificationCenterSettingsChangedNotification object:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = %orig;

	if (tintNotificationCenter) {
		NSMutableArray *orderedSections = MSHookIvar<NSMutableArray *>(self, "_orderedSections");
		SBBBSectionInfo *sectionInfo = orderedSections[indexPath.section];

		if (sectionInfo && [sectionInfo respondsToSelector:@selector(identifier)] && sectionInfo.identifier) {
			NSString *key = sectionInfo.identifier;
			HBFPGetIconIfNeeded(key, key, NO);

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
		HBFPGetIconIfNeeded(key, key, NO);

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
	[[NSNotificationCenter defaultCenter] removeObserver:self name:HBFPNotificationCenterSettingsChangedNotification object:nil];
	%orig;
}

%end
