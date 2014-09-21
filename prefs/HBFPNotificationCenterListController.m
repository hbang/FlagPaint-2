#import "HBFPNotificationCenterListController.h"
#import <Preferences/PSSpecifier.h>
#include <dlfcn.h>
#include <notify.h>

@implementation HBFPNotificationCenterListController

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		BOOL (*_UIAccessibilityEnhanceBackgroundContrast)() = (BOOL (*)())dlsym(RTLD_DEFAULT, "_UIAccessibilityEnhanceBackgroundContrast");

		NSArray *oldSpecifiers = [self loadSpecifiersFromPlistName:@"NotificationCenter" target:self];
		NSMutableArray *specifiers = [[NSMutableArray alloc] init];

		for (PSSpecifier *specifier in oldSpecifiers) {
			if (([specifier.identifier isEqualToString:@"NotificationCenterOpacity"] && _UIAccessibilityEnhanceBackgroundContrast()) ||
				([specifier.identifier isEqualToString:@"NotificationCenterOpacityHighContrast"] && !_UIAccessibilityEnhanceBackgroundContrast())) {
				continue;
			}

			[specifiers addObject:specifier];
		}

		_specifiers = specifiers;
	}

	return _specifiers;
}

#pragma mark - Callbacks

- (void)respring {
	notify_post("ws.hbang.flagpaint/Respring");
}

@end
