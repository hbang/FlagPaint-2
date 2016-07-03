#import "HBFPGradientView.h"
#import "NSCache+Subscripting.h"
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBBannerContextView.h>
#import <SpringBoard/SBControlColorSettings.h>
#import <SpringBoard/SBDefaultBannerTextView.h>
#import <SpringBoard/SBDefaultBannerView.h>
#import <SpringBoard/SBNotificationControlColorSettings.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <version.h>

BOOL hasStatusBarTweak;
CGFloat bannerHeight = 64.f;

@interface SBBannerContextView ()

- (void)_flagpaint_setHeightIfNeeded;
- (CGFloat)_flagpaint_grabberHeightDifference;

@property (nonatomic, retain) _UIBackdropViewSettings *_flagpaint_backdropViewSettings;

@end

#pragma mark - Container view hooks

%hook SBBannerContextView

%property (nonatomic, retain) _UIBackdropViewSettings *_flagpaint_backdropViewSettings;

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");
		backdropView.alpha = preferences.bannerOpacity / 100.f;

		if (preferences.tintBanners) {
			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = preferences.bannerColorIntensity / 100.f;
			[backdropView transitionToSettings:settings];
			self._flagpaint_backdropViewSettings = settings;

			CGFloat grayscaleIntensity = preferences.bannerGrayscaleIntensity / 100.f;

			UIView *grayView = [[UIView alloc] initWithFrame:CGRectZero];
			grayView.backgroundColor = [UIColor colorWithWhite:(100.f - grayscaleIntensity) / 255.f alpha:grayscaleIntensity / 200.f];
			grayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[backdropView.superview insertSubview:grayView aboveSubview:backdropView];

			if (preferences.bannerGradient) {
				HBFPGradientView *gradientView = [[HBFPGradientView alloc] initWithFrame:CGRectZero];
				gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				gradientView.layer.locations = @[ @0, @0.5f, @1 ];
				gradientView.layer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:0.25f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.125f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.00001f].CGColor
				];
				[backdropView.superview insertSubview:gradientView aboveSubview:backdropView];
			} else if (preferences.fonz) {
				CGFloat division = 1.f / 6.f;

				HBFPGradientView *gradientView = [[HBFPGradientView alloc] initWithFrame:CGRectZero];
				gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				gradientView.layer.locations = @[ @(division), @(division * 2.f), @(division * 3.f), @(division * 4.f), @(division * 5.f), @(division * 6.f) ];
				gradientView.layer.colors = @[
					(id)[UIColor redColor].CGColor,
					(id)[UIColor orangeColor].CGColor,
					(id)[UIColor yellowColor].CGColor,
					(id)[UIColor greenColor].CGColor,
					(id)[UIColor colorWithRed:111.f / 255.f green:0 blue:1 alpha:1].CGColor,
					(id)[UIColor colorWithRed:238.f / 255.f green:130.f / 255.f blue:238.f / 255.f alpha:1].CGColor
				];
				[backdropView.superview insertSubview:gradientView aboveSubview:backdropView];
			}
		}

		if (preferences.bannerBorderRadius) {
			_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			self.layer.cornerRadius = hasStatusBarTweak ? 4.f : 8.f;
			backdropView.layer.cornerRadius = self.layer.cornerRadius;

			for (CALayer *layer in backdropView.layer.sublayers) {
				layer.cornerRadius = self.layer.cornerRadius;
			}
		}

		if (preferences.bannerRemoveGrabber && !hasStatusBarTweak) {
			self.clipsToBounds = YES;
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	[self _flagpaint_setHeightIfNeeded];
}

- (void)setBannerContext:(id)bannerContext withReplaceReason:(NSInteger)replaceReason {
	%orig;

	[self _flagpaint_setHeightIfNeeded];

	SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");

	if (!contentView || ![contentView isKindOfClass:%c(SBDefaultBannerView)]) {
		return;
	}

	UIImageView *iconImageView = MSHookIvar<UIImageView *>(contentView, "_iconImageView");

	NSObject *viewSource = MSHookIvar<NSObject *>(contentView, "_viewSource");
	BBBulletin *bulletin = MSHookIvar<BBBulletin *>(viewSource, "_seedBulletin");

	NSString *key = HBFPGetKey(bulletin, nil);
	BOOL isMusic = HBFPIsMusic(key);
	BOOL isAvatar = hasMessagesAvatarTweak && [bulletin.sectionID isEqualToString:@"com.apple.MobileSMS"];

	if (isAvatar) {
		iconCache[key] = iconImageView.image;
	}

	if ((preferences.biggerIcon || isMusic) && !isAvatar) {
		iconImageView.image = HBFPIconForKey(key, iconImageView.image);
	}

	if (isMusic) {
		iconImageView.layer.minificationFilter = kCAFilterTrilinear;
	}

	if (preferences.tintBanners) {
		self._flagpaint_backdropViewSettings.colorTint = HBFPTintForKey(key, iconImageView.image);
	}

	if (preferences.bannerRemoveGrabber && IS_IOS_OR_NEWER(iOS_8_0)) {
		UIImageView *grabberView = MSHookIvar<UIImageView *>(self, "_grabberView");
		grabberView.hidden = YES;
	}
}

- (void)setBackgroundImage:(UIImage *)backgroundImage {}

- (CGFloat)minimumHeight {
	return %orig - self._flagpaint_grabberHeightDifference;
}

%new - (void)_flagpaint_setHeightIfNeeded {
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		return;
	}

	CGRect frame = self.frame;
	frame.size.height = bannerHeight - self._flagpaint_grabberHeightDifference;
	self.frame = frame;
}

%new - (CGFloat)_flagpaint_grabberHeightDifference {
	if (preferences.bannerRemoveGrabber && !hasStatusBarTweak && !IS_IPAD) {
		SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");

		if (!contentView || ![contentView isKindOfClass:%c(SBDefaultBannerView)]) {
			return 0;
		}

		UIImageView *attachmentImageView = MSHookIvar<UIImageView *>(contentView, "_attachmentImageView");
		SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView *>(contentView, "_textView");

		CGFloat lessHeight = 18.f;

		if (attachmentImageView) {
			lessHeight = 5.f;
		} else {
			[contentView layoutSubviews];
			[textView layoutSubviews];

			if ([textView textWillWrapForWidth:textView.frame.size.width] || [textView.secondaryText rangeOfString:@"\n"].location != NSNotFound) {
				lessHeight = 5.f;
			}
		}

		return lessHeight;
	}

	return 0;
}

%end

#pragma mark - Set banner frame hack

%group JonyIve
%hook SBBannerController

- (CGRect)_bannerFrameForOrientation:(UIInterfaceOrientation)orientation {
	CGRect bannerFrame = %orig;
	bannerHeight = bannerFrame.size.height;
	return bannerFrame;
}

%end
%end

#pragma mark - Banner view hooks

%hook SBDefaultBannerView

- (void)layoutSubviews {
	%orig;

	UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");
	SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView *>(self, "_textView");

	if (preferences.removeIcon) {
		CGRect textFrame = textView.frame;
		textFrame.origin.x = iconImageView.frame.origin.x;
		textFrame.size.width += iconImageView.frame.size.width + (textView.frame.origin.x - iconImageView.frame.origin.x - iconImageView.frame.size.width);
		textView.frame = textFrame;

		iconImageView.hidden = YES;
		iconImageView.frame = CGRectZero;
	} else if (preferences.biggerIcon && !hasStatusBarTweak) {
		iconImageView.frame = IS_IPAD ? CGRectMake(-4.f, iconImageView.frame.origin.y, 29.f, 29.f) : CGRectMake(8.f, 7.5f, 29.f, 29.f);
	}

	NSObject *viewSource = MSHookIvar<NSObject *>(self, "_viewSource");
	BBBulletin *bulletin = MSHookIvar<BBBulletin *>(viewSource, "_seedBulletin");
	BOOL isAvatar = hasMessagesAvatarTweak && [bulletin.sectionID isEqualToString:@"com.apple.MobileSMS"];

	if (isAvatar) {
		iconImageView.layer.cornerRadius = iconImageView.frame.size.width / 2;
		iconImageView.clipsToBounds = YES;
	}

	if (preferences.bannerRemoveGrabber && !IS_IOS_OR_NEWER(iOS_8_0)) {
		UIView *grabberView = MSHookIvar<UIImageView *>(self, IS_IOS_OR_NEWER(iOS_7_0_3) ? "_grabberView" : "_grabberImageView");
		grabberView.hidden = YES;
	}
}

%end

#pragma mark - Text view hooks

%hook SBDefaultBannerTextView

- (id)initWithFrame:(CGRect)frame {
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		frame.origin.y -= 1.f;
	}

	self = %orig;

	if (self) {
		if (IS_IOS_OR_NEWER(iOS_7_1)) {
			// this fixes the weird anti-anti-aliased (pro-aliased?) date label for some reason
			UILabel *relevanceDateLabel = MSHookIvar<UILabel *>(self, "_relevanceDateLabel");
			relevanceDateLabel.layer.compositingFilter = nil;

			if (!IS_IOS_OR_NEWER(iOS_8_0)) {
				relevanceDateLabel.textColor = [UIColor whiteColor];
			}
		}
	}

	return self;
}

- (void)drawRect:(CGRect)rect {
	if (preferences.bannerTextShadow) {
		// https://stackoverflow.com/a/1537079/709376

		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, CGSizeMake(1.f, 1.f), 2.f, [UIColor colorWithWhite:0 alpha:0.6f].CGColor);

		%orig;

		CGContextRestoreGState(context);
	} else {
		%orig;
	}
}

%end

#pragma mark - Button hooks

%group CraigFederighi
%hook SBNotificationVibrantButton

- (id)initWithColorSettings:(SBNotificationControlColorSettings *)colorSettings {
	if (preferences.tintBanners) {
		SBControlColorSettings *vibrantSettings = colorSettings.vibrantSettings;
		SBControlColorSettings *overlaySettings = colorSettings.overlaySettings;

		colorSettings = [[%c(SBNotificationControlColorSettings) alloc] initWithVibrantSettings:vibrantSettings overlaySettings:overlaySettings];
	}

	return %orig;
}

%end
%end

#pragma mark - Constructor

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		hasStatusBarTweak = YES;
		dlopen("/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib", RTLD_NOW);
	}

	%init;

	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		%init(CraigFederighi);
	} else {
		%init(JonyIve);
	}
}
