#import "HBFPLockScreenListController.h"
#include <notify.h>

@implementation HBFPLockScreenListController

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"LockScreen";
}

#pragma mark - UIViewController

- (void)loadView {
	[super loadView];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:[bundle localizedStringForKey:@"TEST" value:nil table:@"Root"] style:UIBarButtonItemStylePlain target:self action:@selector(showTestLockScreenNotification)] autorelease];
}

#pragma mark - Callbacks

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

@end
