#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBBulletinRequest.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBDefaultBannerView.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>
#import <version.h>

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Preference variables

BOOL shouldTint = YES;
BOOL useGradient = NO;

BOOL biggerIcon = YES;
BOOL biggerText = YES;

BOOL hideGrabber = YES;
BOOL hideDateLabel = YES;

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

#pragma mark - The Guts(tm)

static const char *kHBFPBackdropViewSettingsIdentifier;

NSMutableDictionary *tintCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];

%hook SBBannerContextView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (shouldTint) {
			_UIBackdropView *oldBackdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

			_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
			settings.colorTint = [UIColor blackColor];
			settings.colorTintAlpha = 0.5f;
			settings.grayscaleTintLevel = 0;
			settings.grayscaleTintAlpha = 0.4f;

			objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			_UIBackdropView *backdropView = [[%c(_UIBackdropView) alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:settings];
			[oldBackdropView.superview insertSubview:backdropView belowSubview:oldBackdropView];
			[oldBackdropView removeFromSuperview];
			[oldBackdropView release];

			object_setInstanceVariable(self, "_backdropView", backdropView);
		}
	}

	return self;
}

- (void)setBannerContext:(id)bannerContext withReplaceReason:(NSInteger)replaceReason {
	%orig;

	UIView *contentView = MSHookIvar<UIView *>(self, "_contentView");
	UIImageView *iconImageView = MSHookIvar<UIImageView *>(contentView, "_iconImageView");

	NSObject *viewSource = MSHookIvar<NSObject *>(contentView, "_viewSource");
	BBBulletin *bulletin = MSHookIvar<BBBulletin *>(viewSource, "_seedBulletin");

	if (biggerIcon) {
		if (!iconCache[bulletin.sectionID]) {
			SBApplication *app = [[(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:bulletin.sectionID] autorelease];

			if (app) {
				SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
				UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

				if (icon) {
					iconCache[bulletin.sectionID] = icon;
				}
			}
		}

		iconImageView.image = iconCache[bulletin.sectionID];
	}

	if (shouldTint) {
		_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);

		if (!tintCache[bulletin.sectionID]) {
			tintCache[bulletin.sectionID] = HBFPGetDominantColor(iconImageView.image);
		}

		settings.colorTint = tintCache[bulletin.sectionID];
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier) release];

	%orig;
}

%end

%hook SBDefaultBannerView

- (void)layoutSubviews {
	%orig;

	if (biggerIcon) {
		UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");
		iconImageView.frame = CGRectMake(8.f, 7.5f, 30.f, 30.f);

		UIImageView *textView = MSHookIvar<UIImageView *>(self, "_textView");

		CGRect textViewFrame = textView.frame;
		textViewFrame.origin.x = iconImageView.frame.origin.x + iconImageView.frame.size.width + 8.f;
		textViewFrame.size.width -= textView.frame.origin.x - textViewFrame.origin.x;
	}

	if (hideGrabber) {
		UIView *grabberView = MSHookIvar<UIImageView *>(self, IS_IOS_OR_NEWER(iOS_7_0_3) ? "_grabberView" : "_grabberImageView");
		[grabberView removeFromSuperview];
	}
}

%end

%hook SBBannerController

- (CGRect)_bannerFrameForOrientation:(UIInterfaceOrientation)orientation {
	CGRect frame = %orig;

	if (hideGrabber) {
		frame.size.height -= 18.f;
	}

	return frame;
}

%end

#pragma mark - Preferences

void HBFPLoadPrefs() {
	// ...
}

#pragma mark - Show test banner

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

	BBBulletinRequest *bulletin = [[[BBBulletinRequest alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint7";
	bulletin.title = @"FlagPaint";
	bulletin.message = @"Test notification";
	bulletin.sectionID = TestApps[testIndex];
	bulletin.accessoryStyle = BBBulletinAccessoryStyleVIP;
	[(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:2];

	testIndex = testIndex == TestApps.count - 1 ? 0 : testIndex + 1;
}

#pragma mark - Constructor

%ctor {
	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);
}
