#import "HBFPNotificationCenterListController.h"
#include <notify.h>

@implementation HBFPNotificationCenterListController

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"NotificationCenter" target:self] retain];
	}

	return _specifiers;
}

@end
