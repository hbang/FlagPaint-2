#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBBulletinRequest.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBBannerContextView.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBDefaultBannerTextView.h>
#import <SpringBoard/SBDefaultBannerView.h>
#import <SpringBoard/SBMediaController.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <version.h>

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Preference variables

BOOL tintBanners, tintLockScreen, tintNotificationCenter;
BOOL biggerIcon, albumArtIcon;
BOOL useGradient, semiTransparent, borderRadius, textShadow;
BOOL removeIcon, removeGrabber, removeDateLabel;

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

#pragma mark - The Guts(tm)

static const char *kHBFPBackdropViewSettingsIdentifier;
static const char *kHBFPBackgroundGradientIdentifier;

NSMutableDictionary *tintCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];
CGFloat bannerHeight = 64.f;

@interface SBBannerContextView (FlagPaint)

- (void)_flagpaint_setHeightIfNeeded;

@end

@interface SBDefaultBannerTextView (FlagPaint)

- (void)_flagpaint_centerAttributedStringIfNeeded:(char *)ivar;

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

			if (useGradient) {
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
		if (!iconCache[key]) {
			if (isMusic) {
				iconCache[key] = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[@"artworkData"]], CGSizeMake(120.f, 120.f));
			} else {
				SBApplication *app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:bulletin.sectionID] autorelease];

				if (app) {
					SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
					UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

					if (icon) {
						iconCache[key] = icon;
					}
				}
			}
		}

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
	if (removeGrabber) {
		SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView *>(self, "_contentView");
		SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView *>(contentView, "_textView");
		[contentView layoutSubviews];
		[textView layoutSubviews];

		CGRect frame = self.frame;
		frame.size.height = bannerHeight - ([textView textWillWrapForWidth:textView.frame.size.width] ? 5.f : 18.f);
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
		[grabberView removeFromSuperview];
	}
}

%end

%hook SBDefaultBannerTextView

- (void)setRelevanceDateText:(NSString *)relevanceDateText {
	%orig(removeDateLabel && [relevanceDateText isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"RELATIVE_DATE_NOW" value:@"now" table:@"SpringBoard"]] ? @"" : relevanceDateText);
}

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

#pragma mark - Preferences

void HBFPLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist"];

	tintBanners = GET_BOOL(@"Tint", YES);
	albumArtIcon = GET_BOOL(@"AlbumArt", YES);
	useGradient = GET_BOOL(@"Gradient", NO);

	biggerIcon = GET_BOOL(@"BigIcon", YES);
	semiTransparent = GET_BOOL(@"Semitransparent", YES);
	borderRadius = GET_BOOL(@"BorderRadius", NO);
	textShadow = GET_BOOL(@"TextShadow", NO);

	removeIcon = GET_BOOL(@"RemoveIcon", NO);
	removeGrabber = GET_BOOL(@"RemoveGrabber", YES);
	removeDateLabel = GET_BOOL(@"RemoveDateLabel", YES);
}

#pragma mark - Show test banner

void HBFPShowBanner(NSString *sectionID, NSString *title, NSString *message, BOOL isTest) {
	BBBulletinRequest *bulletin = [[[BBBulletinRequest alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint7";
	bulletin.sectionID = sectionID;
	bulletin.title = title;
	bulletin.message = message;

	if (isTest) {
		bulletin.accessoryStyle = BBBulletinAccessoryStyleVIP;
	}

	[(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:2];
}

NSUInteger testIndex = 0;

void HBFPShowTestBanner() {
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

	HBFPShowBanner(TestApps[testIndex], @"FlagPaint", @"Test notification", YES);

	testIndex = testIndex == TestApps.count - 1 ? 0 : testIndex + 1;
}

#pragma mark - Constructor

%ctor {
	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);
}
