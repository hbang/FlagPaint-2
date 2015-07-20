#define _FLAGPAINT_DOMINANTCOLOR_XM
#import "NSCache+Subscripting.h"

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

NSCache *tintCache = [[NSCache alloc] init];
NSDictionary *themeTints;

#pragma mark - Get dominant color

UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;
	NSUInteger numberOfPixels = image.size.width * image.size.height;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (!pixels) {
		HBLogError(@"allocating pixels failed - returning white");
		return [UIColor whiteColor];
	}

	CGContextRef context = CGBitmapContextCreate(pixels, image.size.width, image.size.height, BitsPerComponent, image.size.width * BytesPerPixel, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

	if (!context) {
		HBLogError(@"creating bitmap context failed - returning white");
		free(pixels);
		return [UIColor whiteColor];
	}

	CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

	for (NSUInteger i = 0; i < numberOfPixels; i++) {
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
	}

	CGContextRelease(context);
	free(pixels);

	UIColor *color = [UIColor colorWithRed:red / numberOfPixels / 255.f green:green / numberOfPixels / 255.f blue:blue / numberOfPixels / 255.f alpha:1];

	if (_UIAccessibilityEnhanceBackgroundContrast()) {
		CGFloat hue, saturation, brightness;
		[color getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];
		color = [UIColor colorWithHue:hue saturation:MIN(1.f, saturation + 0.2f) brightness:MAX(0, brightness - 0.15f) alpha:1];
	}

	return color;
}

#pragma mark - Get tint for key

UIColor *HBFPTintForKey(NSString *key, UIImage *fallbackImage) {
	UIColor *tint = nil;

	if (tintCache[key]) {
		HBLogDebug(@"%@: tint was cached", key);
		tint = tintCache[key];
	} else {
		NSString *prefsKey = [@"CustomTint-" stringByAppendingString:key];
		BOOL cache = !HBFPIsMusic(key);

		if (preferences[prefsKey]) {
			HBLogDebug(@"%@: trying preferences", key);
			tint = HBFPColorFromDictionaryValue(preferences[prefsKey]);
			cache = NO;
		}

		if (!tint && themeTints[key]) {
			HBLogDebug(@"%@: trying theme", key);
			tint = HBFPColorFromDictionaryValue(themeTints[key]);
		}

		if (!tint) {
			HBLogDebug(@"%@: trying dominaint color", key);
			UIImage *icon = HBFPIconForKey(key, fallbackImage);

			if (!icon) {
				HBLogDebug(@"%@: getting icon failed - using white", key);
				return [UIColor whiteColor];
			}

			tint = HBFPGetDominantColor(icon);
			HBLogDebug(@"%@: using %@", key, tint);
		}

		if (cache && !tintCache[key]) {
			tintCache[key] = [tint retain];
		}

		if (!tint) {
			HBLogDebug(@"%@: still no icon - using white", key);
			tint = [UIColor whiteColor];
		}
	}

	CGFloat vibrancy = [preferences floatForKey:kHBFPPreferencesTintVibrancyKey] / 100.f - 0.5f;

	CGFloat hue, saturation, brightness;
	[tint getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];

	return [UIColor colorWithHue:hue saturation:MIN(1.f, saturation + (vibrancy / 2.f)) brightness:MAX(0, brightness - vibrancy) alpha:1];
}
