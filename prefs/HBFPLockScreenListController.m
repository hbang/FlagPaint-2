#import "HBFPLockScreenListController.h"
#include <notify.h>

@implementation HBFPLockScreenListController

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"LockScreen";
}

#pragma mark - Callbacks

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

@end
