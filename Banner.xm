#import "Global.h"
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBBannerContextView.h>
#import <SpringBoard/SBDefaultBannerTextView.h>
#import <SpringBoard/SBDefaultBannerView.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <version.h>

static const char *kHBFPBackdropViewSettingsIdentifier;
static const char *kHBFPBackgroundGradientIdentifier;

BOOL hasStatusBarTweak;
CGFloat bannerHeight = 64.f;

@interface SBBannerContextView (FlagPaint)

- (void)_flagpaint_setHeightIfNeeded;

@end

%hook SBBannerContextView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (tintBanners) {
			_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = 0.4f;
			settings.grayscaleTintLevel = 0;
			settings.grayscaleTintAlpha = 0.2f;
			[backdropView transitionToSettings:settings];

			objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			if (bannerGradient) {
				UIView *gradientView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
				gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				[backdropView.superview insertSubview:gradientView aboveSubview:backdropView];

				CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
				gradientLayer.locations = @[ @0, @0.5f, @1 ];
				gradientLayer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:0.25f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.125f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.00001f].CGColor
				];
				[gradientView.layer addSublayer:gradientLayer];

				objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		}

		if (semiTransparent) {
			self.alpha = 0.9f;
		}

		if (borderRadius) {
			_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			self.layer.cornerRadius = 8.f;
			backdropView.layer.cornerRadius = self.layer.cornerRadius;

			for (CALayer *layer in backdropView.layer.sublayers) {
				layer.cornerRadius = self.layer.cornerRadius;
			}
		}

		if (removeGrabber && !hasStatusBarTweak) {
			self.clipsToBounds = YES;
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	[self _flagpaint_setHeightIfNeeded];

	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);

	if (gradientLayer) {
		_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");
		gradientLayer.frame = CGRectMake(0, 0, backdropView.frame.size.width, backdropView.frame.size.height);
	}
}

- (void)setBannerContext:(id)bannerContext withReplaceReason:(NSInteger)replaceReason {
	%orig;

	[self _flagpaint_setHeightIfNeeded];

	SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");
	UIImageView *iconImageView = MSHookIvar<UIImageView *>(contentView, "_iconImageView");

	NSObject *viewSource = MSHookIvar<NSObject *>(contentView, "_viewSource");
	BBBulletin *bulletin = MSHookIvar<BBBulletin *>(viewSource, "_seedBulletin");

	BOOL isMusic = HBFPIsMusic(bulletin.sectionID);
	NSString *key = HBFPGetKey(bulletin.sectionID, isMusic);

	if (biggerIcon) {
		HBFPGetIconIfNeeded(key, bulletin.sectionID, isMusic);
		iconImageView.image = iconCache[key];

		if (isMusic) {
			iconImageView.layer.minificationFilter = kCAFilterTrilinear;
		}
	}

	if (tintBanners) {
		_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);

		if (!tintCache[key]) {
			tintCache[key] = HBFPGetDominantColor(iconImageView.image);
		}

		settings.colorTint = tintCache[key];
	}
}

- (void)setBackgroundImage:(UIImage *)backgroundImage {}

%new - (void)_flagpaint_setHeightIfNeeded {
	if (removeGrabber && !hasStatusBarTweak) {
		SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");
		SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView *>(contentView, "_textView");
		[textView layoutSubviews];

		CGRect frame = self.frame;
		frame.size.height = bannerHeight - ([textView textWillWrapForWidth:textView.frame.size.width] || [textView.secondaryText rangeOfString:@"\n"].location != NSNotFound ? 5.f : 18.f);
		self.frame = frame;
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier) release];
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];

	%orig;
}

%end

%hook SBBannerController

- (CGRect)_bannerFrameForOrientation:(UIInterfaceOrientation)orientation {
	CGRect bannerFrame = %orig;
	bannerHeight = bannerFrame.size.height;
	return bannerFrame;
}

%end

%hook SBDefaultBannerView

- (void)layoutSubviews {
	%orig;

	UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");
	SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView *>(self, "_textView");

	if (removeIcon) {
		CGRect textFrame = textView.frame;
		textFrame.origin.x = iconImageView.frame.origin.x;
		textFrame.size.width += iconImageView.frame.size.width + (textView.frame.origin.x - iconImageView.frame.origin.x - iconImageView.frame.size.width);
		textView.frame = textFrame;

		iconImageView.hidden = YES;
		iconImageView.frame = CGRectZero;
	} else if (biggerIcon) {
		iconImageView.frame = CGRectMake(8.f, 7.5f, 30.f, 30.f);
	}

	if (removeGrabber) {
		UIView *grabberView = MSHookIvar<UIImageView *>(self, IS_IOS_OR_NEWER(iOS_7_0_3) ? "_grabberView" : "_grabberImageView");
		grabberView.hidden = YES;
	}
}

%end

%hook SBDefaultBannerTextView

- (void)drawRect:(CGRect)rect {
	if (textShadow) {
		// http://stackoverflow.com/a/1537079/709376

		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, CGSizeMake(1.f, 1.f), 2.f, [UIColor colorWithWhite:0 alpha:0.8f].CGColor);

		%orig;

		CGContextRestoreGState(context);
	} else {
		%orig;
	}
}

%end

/*
%group TinyBarHax
@interface SBDefaultBannerTextView (TinyBar)

- (UILabel *)tb_titleLabel;
- (UILabel *)tb_secondaryLabel;

@end

@interface MarqueeLabel : UILabel
@end

%hook SBDefaultBannerTextView

- (void)layoutSubviews {
	%orig;

	if (!textShadow || ![self respondsToSelector:@selector(tb_titleLabel)]) {
		NSLog(@"!");
		return;
	}

	NSLog(@"%@",self.tb_titleLabel);

	object_setClass(self.tb_titleLabel, HBFPShadowedLabel.class);
}

%end

%hook MarqueeLabel

- (void)drawTextInRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, CGSizeMake(1.f, 1.f), 2.f, [UIColor colorWithWhite:0 alpha:0.8f].CGColor);

	%orig;

	CGContextRestoreGState(context);
}

%end
%end
*/

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		hasStatusBarTweak = YES;
		dlopen("/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib", RTLD_NOW);
		// %init(TinyBarHax);
	}

	%init;
}
