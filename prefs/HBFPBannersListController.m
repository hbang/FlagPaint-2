#import "HBFPBannersListController.h"
#import <Preferences/PSSpecifier.h>
#include <notify.h>
#import <version.h>

@implementation HBFPBannersListController {
	BOOL _hasStatusBarTweak;
}

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"Banners";
}

#pragma mark - UIViewController

- (void)loadView {
	[super loadView];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:[bundle localizedStringForKey:@"TEST" value:nil table:@"Root"] style:UIBarButtonItemStylePlain target:self action:@selector(showTestBanner)] autorelease];

	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/TinyBar.dylib"]) {
		_hasStatusBarTweak = YES;
	}
}

#pragma mark - PSListController

- (NSArray *)specifiers {
	NSArray *oldSpecifiers = [super specifiers];
	NSMutableArray *specifiers = [[NSMutableArray alloc] init];

	for (PSSpecifier *specifier in oldSpecifiers) {
		if ((_hasStatusBarTweak && [@[ @"TextShadow", @"BannersSection" ] containsObject:specifier.identifier]) ||
			(!_hasStatusBarTweak && [@[ @"TextShadowDisabled", @"BannersSectionDisabled" ] containsObject:specifier.identifier])) {
			continue;
		}

		[specifiers addObject:specifier];
	}

	_specifiers = specifiers;
	return _specifiers;
}

#pragma mark - Callbacks

- (void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}

@end
