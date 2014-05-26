#import "Global.h"
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <SpringBoard/SBBBSectionInfo.h>
#import <SpringBoard/SBBulletinViewController.h>
#import <SpringBoard/SBNotificationsBulletinCell.h>
#import <SpringBoard/SBNotificationsSectionHeaderView.h>

static const char *kHBFPBackdropViewSettingsIdentifier;
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

%hook SBNotificationsSectionHeaderView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (tintNotificationCenter) {
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

%hook SBNotificationsBulletinCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		UIView *backgroundView = [[UIView alloc] initWithFrame:self.frame];
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

%hook SBBulletinViewController

- (void)loadView {
	%orig;
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
