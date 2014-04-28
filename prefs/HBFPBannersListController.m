#import "HBFPBannersListController.h"
#import <Preferences/PSSpecifier.h>
#include <notify.h>

@implementation HBFPBannersListController {
	BOOL _hasStatusBarTweak;
}

#pragma mark - UIViewController

- (void)loadView {
	[super loadView];

	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		_hasStatusBarTweak = YES;
	}
}

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSArray *oldSpecifiers = [self loadSpecifiersFromPlistName:@"Banners" target:self];
		NSMutableArray *specifiers = [[NSMutableArray alloc] init];

		for (PSSpecifier *specifier in oldSpecifiers) {
			if ((_hasStatusBarTweak && [@[ @"TextShadow", @"BannersSection" ] containsObject:specifier.identifier]) ||
				(!_hasStatusBarTweak && [@[ @"TextShadowDisabled", @"BannersSectionDisabled" ] containsObject:specifier.identifier])) {
				continue;
			}

			[specifiers addObject:specifier];
		}

		_specifiers = specifiers;
	}

	return _specifiers;
}

#pragma mark - Callbacks

- (void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}

@end
