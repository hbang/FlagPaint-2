#import "HBFPLockScreenListController.h"
#include <notify.h>

@implementation HBFPLockScreenListController

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"LockScreen" target:self] retain];
	}

	return _specifiers;
}

#pragma mark - Callbacks

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

@end
