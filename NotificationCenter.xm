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

static CGFloat const kHBFPNotificationHeaderBackgroundAlphaFloating = 0.43f;

static CGFloat const kHBFPNotificationCellBackgroundAlphaNormal = 0.43f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaHighlighted = 0.86f;
static CGFloat const kHBFPNotificationCellBackgroundAlphaSelected = 1.15f;

static CGFloat const kHBFPNotificaitonCenterIPadPadding = 1024.f; // lazy

@interface SBNotificationsModeViewController (FlagPaint)

- (void)_flagpaint_updateMask;

@end

#pragma mark - Fade effect

%hook SBNotificationsModeViewController

- (void)loadView {
	%orig;

	[self _flagpaint_updateMask];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_flagpaint_updateMask) name:HBFPPreferencesChangedNotification object:nil];
}

%new - (void)_flagpaint_updateMask {
	if (!notificationCenterFade) {
		[self.view.layer.mask release];
		self.view.layer.mask = nil;
	} else {
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

	if (notificationCenterFade) {
		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);

		if (!CGRectEqualToRect(gradientLayer.frame, self.view.bounds)) {
			gradientLayer.frame = self.view.bounds;
		}
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:HBFPPreferencesChangedNotification object:nil];

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
		frame.origin.x = -kHBFPNotificaitonCenterIPadPadding;
		frame.size.width = backdropView.superview.frame.size.width + kHBFPNotificaitonCenterIPadPadding * 2;
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
		UIScrollView *wrapperView = MSHookIvar<UIScrollView *>(self, "_wrapperView");;

		self.clipsToBounds = NO;
		wrapperView.clipsToBounds = NO;

		UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(IS_IPAD ? -kHBFPNotificaitonCenterIPadPadding : 0, 0, self.realContentView.frame.size.width + (IS_IPAD ? kHBFPNotificaitonCenterIPadPadding * 2 : 0), self.realContentView.frame.size.height)];
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

	[[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:HBFPPreferencesChangedNotification object:nil];
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
