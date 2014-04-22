#import "HBFPLockScreenListController.h"
#import "HBFPHeaderView.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#include <notify.h>

@implementation HBFPLockScreenListController

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"LockScreen" target:self];
	}

	return _specifiers;
}

#pragma mark - Callbacks

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

@end
