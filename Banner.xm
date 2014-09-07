#import "Global.h"
#import "HBFPGradientView.h"
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
		_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");
		backdropView.alpha = bannerOpacity;

		if (tintBanners) {
			_UIBackdropView *backdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = bannerColorIntensity;
			[backdropView transitionToSettings:settings];

			objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			UIView *grayView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
			grayView.backgroundColor = [UIColor colorWithWhite:(100.f - bannerGrayscaleIntensity) / 255.f alpha:bannerGrayscaleIntensity / 200.f];
			grayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[backdropView.superview insertSubview:grayView aboveSubview:backdropView];

			if (bannerGradient) {
				HBFPGradientView *gradientView = [[[HBFPGradientView alloc] initWithFrame:CGRectZero] autorelease];
				gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				gradientView.layer.locations = @[ @0, @0.5f, @1 ];
				gradientView.layer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:0.25f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.125f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.00001f].CGColor
				];
				[backdropView.superview insertSubview:gradientView aboveSubview:backdropView];
			}
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

	BOOL isMusic = HBFPIsMusic(bulletin.sectionID);
	NSString *key = HBFPGetKey(bulletin.sectionID, isMusic);

	if (biggerIcon || isMusic) {
		HBFPGetIconIfNeeded(key, bulletin, isMusic);
		iconImageView.image = iconCache[key];
	}

	if (isMusic) {
		iconImageView.layer.minificationFilter = kCAFilterTrilinear;
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
	if (removeGrabber && !hasStatusBarTweak && !IS_IPAD) {
		SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");

		if (!contentView || ![contentView isKindOfClass:%c(SBDefaultBannerView)]) {
			return;
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

		CGRect frame = self.frame;
		frame.size.height = bannerHeight - lessHeight;
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
	} else if (biggerIcon && !hasStatusBarTweak) {
		iconImageView.frame = IS_IPAD ? CGRectMake(-4.f, iconImageView.frame.origin.y, 29.f, 29.f) : CGRectMake(8.f, 7.5f, 29.f, 29.f);
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

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		hasStatusBarTweak = YES;
		dlopen("/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib", RTLD_NOW);
		// %init(TinyBarHax);
	}

	%init;
}
