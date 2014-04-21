#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBAction.h>
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBAwayBulletinListItem.h>
#import <SpringBoard/SBBannerContextView.h>
#import <SpringBoard/SBBBSectionInfo.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBBulletinObserverViewController.h>
#import <SpringBoard/SBDefaultBannerTextView.h>
#import <SpringBoard/SBDefaultBannerView.h>
#import <SpringBoard/SBLockScreenManager.h>
#import <SpringBoard/SBLockScreenNotificationCell.h>
#import <SpringBoard/SBLockScreenNotificationListController.h>
#import <SpringBoard/SBLockScreenNotificationListView.h>
#import <SpringBoard/SBLockScreenNotificationModel.h>
#import <SpringBoard/SBMediaController.h>
#import <SpringBoard/SBNotificationCenterController.h>
#import <SpringBoard/SBNotificationCenterViewController.h>
#import <SpringBoard/SBNotificationsBulletinCell.h>
#import <SpringBoard/SpringBoard.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <UIKit/UITableViewCell+Private.h>
#import <version.h>
#import "HBFPShadowedLabel.h"
#include <dlfcn.h>

@interface SBAwayNotificationListCell : UITableViewCell {
	BBBulletin *_bulletin;
}
@property (nonatomic, retain) BBBulletin *bulletin;
@end

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Variables

static const char *kHBFPBackdropViewSettingsIdentifier;
static const char *kHBFPBackgroundGradientIdentifier;
static const char *kHBFPBackgroundViewIdentifier;

BOOL tintBanners, tintLockScreen, tintNotificationCenter;
BOOL biggerIcon, albumArtIcon;
BOOL bannerGradient, semiTransparent, borderRadius, textShadow;
BOOL lockGradient, lockFade;
BOOL removeIcon, removeGrabber, removeDateLabel;

BOOL hasStatusBarTweak;

NSMutableDictionary *tintCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];

#pragma mark - Get dominant color

UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;
	NSUInteger numberOfPixels = image.size.width * image.size.height;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (!pixels) {
		return [UIColor whiteColor];
	}

	CGContextRef context = CGBitmapContextCreate(pixels, image.size.width, image.size.height, BitsPerComponent, image.size.width * BytesPerPixel, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

	if (!context) {
		free(pixels);
		return [UIColor whiteColor];
	}

	CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

	for (NSUInteger i = 0; i < numberOfPixels; i++) {
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
	}

	red /= numberOfPixels;
	green /= numberOfPixels;
	blue /= numberOfPixels;

	CGContextRelease(context);
	free(pixels);

	return [UIColor colorWithRed:red / 255.f green:green / 255.f blue:blue / 255.f alpha:1];
}

#pragma mark - Resize image

// http://stackoverflow.com/a/10099016/709376

UIImage *HBFPResizeImage(UIImage *oldImage, CGSize newSize) {
	if (!oldImage) {
		return nil;
	}

	UIImage *newImage = nil;

	CGImageRef cgImage = oldImage.CGImage;
	NSUInteger oldWidth = CGImageGetWidth(cgImage);
	NSUInteger oldHeight = CGImageGetHeight(cgImage);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	pixel *oldData = (pixel *)calloc(oldHeight * oldWidth * BytesPerPixel, sizeof(pixel));
	NSUInteger oldBytesPerRow = BytesPerPixel * oldWidth;

	CGContextRef context = CGBitmapContextCreate(oldData, oldWidth, oldHeight, BitsPerComponent, oldBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGContextDrawImage(context, CGRectMake(0, 0, oldWidth, oldHeight), cgImage);
	CGContextRelease(context);

	NSUInteger newWidth = (NSUInteger)newSize.width;
	NSUInteger newHeight = (NSUInteger)newSize.height;
	NSUInteger newBytesPerRow = BytesPerPixel * newWidth;
	pixel *newData = (pixel *)calloc(newHeight * newWidth * BytesPerPixel, sizeof(pixel));

	vImage_Buffer oldBuffer = {
		.data = oldData,
		.height = oldHeight,
		.width = oldWidth,
		.rowBytes = oldBytesPerRow
	};

	vImage_Buffer newBuffer = {
		.data = newData,
		.height = newHeight,
		.width = newWidth,
		.rowBytes = newBytesPerRow
	};

	vImage_Error error = vImageScale_ARGB8888(&oldBuffer, &newBuffer, NULL, kvImageHighQualityResampling);

	free(oldData);

	CGContextRef newContext = CGBitmapContextCreate(newData, newWidth, newHeight, BitsPerComponent, newBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGImageRef cgImageNew = CGBitmapContextCreateImage(newContext);

	newImage = [UIImage imageWithCGImage:cgImageNew];

	CGImageRelease(cgImageNew);
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(newContext);

	free(newData);

	if (error != kvImageNoError) {
		NSLog(@"warning: failed to scale image: error %ld", error);
		return oldImage;
	}

	return newImage;
}

#pragma mark - Various helper functions

BOOL HBFPIsMusic(NSString *sectionID) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return albumArtIcon && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([sectionID isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [sectionID isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[@"artworkData"];
}

NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic) {
	SBMediaController *mediaController = (SBMediaController *)[%c(SBMediaController) sharedInstance];

	return isMusic ? [NSString stringWithFormat:@"_FPMusic_%@_%@_%@_%@", mediaController.nowPlayingApplication.bundleIdentifier, mediaController.nowPlayingTitle, mediaController.nowPlayingArtist, mediaController.nowPlayingAlbum] : sectionID;
}

void HBFPGetIconIfNeeded(NSString *key, NSString *sectionID, BOOL isMusic) {
	if (!iconCache[key]) {
		if (isMusic) {
			iconCache[key] = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[@"artworkData"]], CGSizeMake(120.f, 120.f));
		} else {
			SBApplication *app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:sectionID] autorelease];

			if (app) {
				SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
				UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

				if (icon) {
					iconCache[key] = icon;
				}
			}
		}
	}
}

#pragma mark - The Guts(tm)

CGFloat bannerHeight = 64.f;

%hook NSBundle

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table {
	// broad hook, yes i know. sue me.
	return [key isEqualToString:@"RELATIVE_DATE_NOW"] && [table isEqualToString:@"SpringBoard"] && removeDateLabel ? @"" : %orig;
}

%end

#pragma mark - Banners

@interface SBBannerContextView (FlagPaint)

- (void)_flagpaint_setHeightIfNeeded;

@end

%hook SBBannerContextView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (tintBanners) {
			_UIBackdropView *oldBackdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = 0.4f;
			settings.grayscaleTintLevel = 0;
			settings.grayscaleTintAlpha = 0.2f;

			objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			_UIBackdropView *backdropView = [[%c(_UIBackdropView) alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:settings];
			[oldBackdropView.superview insertSubview:backdropView belowSubview:oldBackdropView];
			[oldBackdropView removeFromSuperview];
			[oldBackdropView release];

			object_setInstanceVariable(self, "_backdropView", backdropView);

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
		[contentView layoutSubviews];
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

#pragma mark - Lock Screen

%hook SBLockScreenNotificationListView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (lockFade) {
			UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");

			CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
			gradientLayer.locations = IS_IPAD ? @[ @0, @0.1f, @0.9f, @1 ] : @[ @0, @0.04f, @0.96f, @1 ];
			gradientLayer.colors = @[
				(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor,
				(id)[UIColor whiteColor].CGColor,
				(id)[UIColor whiteColor].CGColor,
				(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor
			];
			containerView.layer.mask = gradientLayer;

			objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if (lockFade) {
		UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");

		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
		gradientLayer.frame = CGRectMake(0, 0, containerView.frame.size.width, containerView.frame.size.height);
	}
}

- (SBLockScreenNotificationCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBLockScreenNotificationCell *cell = %orig;

	if (tintLockScreen || biggerIcon) {
		SBAwayBulletinListItem *listItem = [self.model listItemAtIndexPath:indexPath];

		if (![listItem respondsToSelector:@selector(activeBulletin)]) {
			return cell;
		}

		BBBulletin *bulletin = listItem.activeBulletin;
		UIImageView *iconImageView = MSHookIvar<UIImageView *>(cell, "_iconImageView");

		BOOL isMusic = HBFPIsMusic(bulletin.sectionID);
		NSString *key = HBFPGetKey(bulletin.sectionID, isMusic);

		if (biggerIcon) {
			HBFPGetIconIfNeeded(key, bulletin.sectionID, isMusic);
			iconImageView.image = iconCache[key];

			if (isMusic) {
				iconImageView.layer.minificationFilter = kCAFilterTrilinear;
			}
		}

		if (tintLockScreen) {
			if (!iconCache[key]) {
				iconCache[key] = iconImageView.image;
			}

			if (!tintCache[key]) {
				tintCache[key] = HBFPGetDominantColor(iconCache[key]);
			}

			UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = tintCache[key];
		}
	}

	return cell;
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	%orig;
}

%end

%hook CSAwayNotificationController

- (SBAwayNotificationListCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBAwayNotificationListCell *cell = %orig;
	if (tintLockScreen){
		UIImageView *iconImageView = cell.imageView;
		BBBulletin *bulletin = cell.bulletin;
		BOOL isMusic = HBFPIsMusic(bulletin.sectionID);
		NSString *key = HBFPGetKey(bulletin.sectionID, isMusic);
		if (!iconCache[key]) {
			iconCache[key] = iconImageView.image;
		}

		if (!tintCache[key]) {
			tintCache[key] = HBFPGetDominantColor(iconCache[key]);
		}

		cell.backgroundColor = tintCache[key];
	}
	return cell;
}

%end

%hook SBLockScreenNotificationCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		if (tintLockScreen) {
			UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			backgroundView.alpha = lockGradient ? 1 : 0.55f;
			[self.realContentView insertSubview:backgroundView atIndex:0];

			objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			if (lockGradient) {
				BOOL isRTL = [NSLocale characterDirectionForLanguage:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]] == NSLocaleLanguageDirectionRightToLeft;

				CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
				gradientLayer.locations = isRTL ? @[ @1, @0.4f, @0.2f, @0 ] : @[ @0, @0.2f, @0.4f, @1 ];
				gradientLayer.startPoint = CGPointMake(0, 0.5f);
				gradientLayer.endPoint = CGPointMake(1.f, 0.5f);
				gradientLayer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:0.8f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.5f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.2f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.05f].CGColor
				];
				backgroundView.layer.mask = gradientLayer;

				objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if (tintLockScreen || biggerIcon) {
		if (biggerIcon) {
			UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");
			iconImageView.frame = CGRectMake(9.f, 12.5f, 30.f, 30.f);
		}

		if (tintLockScreen && lockGradient) {
			CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
			gradientLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
		}
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
}

%end

#pragma mark - Notification Center

%hook SBNotificationsSectionHeaderView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (tintNotificationCenter) {
			_UIBackdropView *oldBackdropView = MSHookIvar<_UIBackdropView *>(self, "_backdrop");

			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = 0.35f;
			settings.grayscaleTintLevel = 0;
			settings.grayscaleTintAlpha = 0.05f;

			objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			_UIBackdropView *backdropView = [[%c(_UIBackdropView) alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:settings];
			[oldBackdropView.superview insertSubview:backdropView belowSubview:oldBackdropView];
			[oldBackdropView removeFromSuperview];
			[oldBackdropView release];

			object_setInstanceVariable(self, "_backdrop", backdropView);
		}
	}

	return self;
}

- (void)setFloating:(BOOL)floating {
	if (tintNotificationCenter) {
		_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);
		settings.grayscaleTintAlpha = floating ? 0.15f : 0.05f;
	} else {
		%orig;
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier) release];
	%orig;
}

%end

%hook SBNotificationsBulletinCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		if (tintNotificationCenter) {
			UIView *backgroundView = [[UIView alloc] initWithFrame:self.frame];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			backgroundView.alpha = 0.15f;
			[self.realContentView insertSubview:backgroundView atIndex:0];

			objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}

	return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = highlighted ? 0.3f : 0.15f;
	} else {
		%orig;
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (tintNotificationCenter) {
		UIView *backgroundView = objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier);
		backgroundView.alpha = selected ? 0.35f : 0.15f;
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

		_UIBackdropViewSettings *settings = objc_getAssociatedObject(header, &kHBFPBackdropViewSettingsIdentifier);
		settings.colorTint = tintCache[key];
	}

	return header;
}

%end

#pragma mark - First run

void HBFPShowLockScreenBulletin(BBBulletin *bulletin);

%group FirstRun

BOOL firstRun = YES;

%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;

	if (firstRun) {
		firstRun = NO;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
			BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
			bulletin.bulletinID = @"ws.hbang.flagpaint";
			bulletin.sectionID = @"com.apple.Preferences";
			bulletin.title = @"Thanks for purchasing FlagPaint!";
			bulletin.unlockActionLabelOverride = @"configure";

			NSURL *url;

			if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer2.dylib"]) {
				url = [NSURL URLWithString:@"prefs:root=Cydia&path=FlagPaint7"];
			} else {
				url = [NSURL URLWithString:@"prefs:root=FlagPaint7"];
			}

			bulletin.defaultAction = [BBAction actionWithLaunchURL:url callblock:nil];

			HBFPShowLockScreenBulletin(bulletin);
		});
	}
}

%end

%end

#pragma mark - Preferences

static NSString *const kHBFPPrefsPath = @"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist";

static NSString *const kHBFPPrefsTintBannersKey = @"Tint";
static NSString *const kHBFPPrefsTintLockScreenKey = @"TintLockScreen";
static NSString *const kHBFPPrefsTintNotificationCenterKey = @"TintNotificationCenter";

static NSString *const kHBFPPrefsBiggerIconKey = @"BigIcon";
static NSString *const kHBFPPrefsAlbumArtIconKey = @"AlbumArt";

static NSString *const kHBFPPrefsBannerGradientKey = @"Gradient";
static NSString *const kHBFPPrefsSemiTransparentKey = @"Semitransparent";
static NSString *const kHBFPPrefsBorderRadiusKey = @"BorderRadius";
static NSString *const kHBFPPrefsTextShadowKey = @"TextShadow";

static NSString *const kHBFPPrefsLockGradientKey = @"LockGradient";
static NSString *const kHBFPPrefsLockFadeKey = @"LockFade";

static NSString *const kHBFPPrefsRemoveIconKey = @"RemoveIcon";
static NSString *const kHBFPPrefsRemoveGrabberKey = @"RemoveGrabber";
static NSString *const kHBFPPrefsRemoveDateLabelKey = @"RemoveDateLabel";

static NSString *const kHBFPPrefsNotFirstRunKey = @"NotFirstRun";

void HBFPLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kHBFPPrefsPath];

	if (prefs.allKeys.count == 0) {
		[@{ kHBFPPrefsNotFirstRunKey: @YES } writeToFile:kHBFPPrefsPath atomically:YES];
		%init(FirstRun);
	}

	tintBanners = GET_BOOL(kHBFPPrefsTintBannersKey, YES);
	tintLockScreen = GET_BOOL(kHBFPPrefsTintLockScreenKey, YES);
	tintNotificationCenter = GET_BOOL(kHBFPPrefsTintNotificationCenterKey, YES);

	biggerIcon = GET_BOOL(kHBFPPrefsBiggerIconKey, YES);
	albumArtIcon = GET_BOOL(kHBFPPrefsAlbumArtIconKey, YES);

	bannerGradient = GET_BOOL(kHBFPPrefsBannerGradientKey, NO);
	semiTransparent = GET_BOOL(kHBFPPrefsSemiTransparentKey, YES);
	borderRadius = GET_BOOL(kHBFPPrefsBorderRadiusKey, NO);
	textShadow = GET_BOOL(kHBFPPrefsTextShadowKey, NO);

	lockGradient = GET_BOOL(kHBFPPrefsLockGradientKey, YES);
	lockFade = GET_BOOL(kHBFPPrefsLockFadeKey, YES);

	removeIcon = GET_BOOL(kHBFPPrefsRemoveIconKey, NO);
	removeGrabber = GET_BOOL(kHBFPPrefsRemoveGrabberKey, YES);
	removeDateLabel = GET_BOOL(kHBFPPrefsRemoveDateLabelKey, YES);
}

#pragma mark - Show test bulletin

NSUInteger testIndex = 0;

BBBulletin *HBFPGetTestBulletin(BOOL isLockScreen) {
	static NSArray *TestApps;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		TestApps = [@[
			@"com.apple.MobileSMS", @"com.apple.mobilecal", @"com.apple.mobileslideshow", @"com.apple.camera",
			@"com.apple.weather", @"com.apple.mobiletimer", @"com.apple.Maps", @"com.apple.videos",
			@"com.apple.mobilenotes", @"com.apple.reminders", @"com.apple.stocks", @"com.apple.gamecenter",
			@"com.apple.Passbook", @"com.apple.MobileStore", @"com.apple.AppStore", @"com.apple.Preferences",
			@"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", @"com.apple.Music",
			@"com.apple.MobileAddressBook", @"com.apple.calculator", @"com.apple.compass", @"com.apple.VoiceMemos",
			@"com.apple.facetime", @"com.apple.nike"
		] retain];

		testIndex = arc4random_uniform(TestApps.count);
	});

	BBBulletin *bulletin = [[[BBBulletin alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint";
	bulletin.sectionID = TestApps[testIndex];
	bulletin.title = @"FlagPaint";

	if (isLockScreen) {
		bulletin.subtitle = @"Test notification";
	} else {
		bulletin.message = @"Test notification";
		bulletin.accessoryStyle = BBBulletinAccessoryStyleVIP;
	}

	testIndex = testIndex == TestApps.count - 1 ? 0 : testIndex + 1;

	return bulletin;
}

void HBFPShowTestBanner() {
	[(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:HBFPGetTestBulletin(NO) forFeed:2];
}

void HBFPShowLockScreenBulletin(BBBulletin *bulletin) {
	UIViewController *viewController = ((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).lockScreenViewController;
	SBLockScreenNotificationListController *notificationController = MSHookIvar<SBLockScreenNotificationListController *>(viewController, "_notificationController");

	[notificationController observer:nil addBulletin:bulletin forFeed:2];
}

void HBFPShowTestLockScreenNotification() {
	[(SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		HBFPShowLockScreenBulletin(HBFPGetTestBulletin(YES));
	});
}

void HBFPShowTestNotificationCenterBulletin() {
	[(SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance] presentAnimated:YES completion:^{
		[[((SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance]).viewController _allModeViewControllerCreateIfNecessary:YES] observer:nil addBulletin:HBFPGetTestBulletin(NO) forFeed:2];
	}];
}

#pragma mark - Constructor

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib"]) {
		dlopen("/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib", RTLD_NOW);
	}

	%init;

	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		hasStatusBarTweak = YES;
		dlopen("/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib", RTLD_NOW);
		// %init(TinyBarHax);
	}

	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestLockScreenNotification, CFSTR("ws.hbang.flagpaint/TestLockScreenNotification"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestNotificationCenterBulletin, CFSTR("ws.hbang.flagpaint/TestNotificationCenterBulletin"), NULL, kNilOptions);
}
