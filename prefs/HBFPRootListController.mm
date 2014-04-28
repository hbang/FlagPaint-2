#import "HBFPRootListController.h"
#import "HBFPHeaderView.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#include <notify.h>
#include <substrate.h>

static CGFloat const kHBFPHeaderTopInset = 64.f; // i'm so sorry.
static CGFloat const kHBFPHeaderHeight = 150.f;

@implementation HBFPRootListController {
	HBFPHeaderView *_headerView;
	BOOL _hasStatusBarTweak;
	BOOL _isVisible;
}

#pragma mark - Constants

+ (NSString *)hb_shareText {
	return @"I’m using #FlagPaint to add color to my notifications!";
}

+ (NSURL *)hb_shareURL {
	return [NSURL URLWithString:@"http://hbang.ws/flagpaint"];
}

+ (UIColor *)hb_tintColor {
	return [UIColor colorWithRed:34.f / 255.f green:163.f / 255.f blue:124.f / 255.f alpha:1];
}

#pragma mark - UIViewController

- (void)loadView {
	[super loadView];

	self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"FlagPaint7" style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];

	_headerView = [[HBFPHeaderView alloc] initWithTopInset:kHBFPHeaderTopInset];
	_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_headerView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
		CGFloat headerHeight = kHBFPHeaderTopInset + kHBFPHeaderHeight;

		self.view.contentInset = UIEdgeInsetsMake(headerHeight, 0, 0, 0);
		self.view.contentOffset = CGPointMake(0, -headerHeight);

		_headerView.frame = CGRectMake(0, -headerHeight, self.view.frame.size.width, headerHeight);
	});

	[self reloadSpecifier:[self specifierForID:@"Tint"]];
	[self reloadSpecifier:[self specifierForID:@"TintLockScreen"]];

	_isVisible = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	UIView *titleView = MSHookIvar<UIView *>(self.navigationController.navigationBar, "_titleView");
	titleView.alpha = 1;

	_isVisible = NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (!_isVisible) {
		return;
	}

	UIView *titleView = MSHookIvar<UIView *>(self.navigationController.navigationBar, "_titleView");

	if (titleView) {
		titleView.alpha = (scrollView.contentOffset.y / kHBFPHeaderHeight) + 1;
	}

	if (scrollView.contentOffset.y >= -kHBFPHeaderTopInset - kHBFPHeaderHeight) {
		return;
	}

	CGRect headerFrame = _headerView.frame;
	headerFrame.origin.y = scrollView.contentOffset.y;
	headerFrame.size.height = -scrollView.contentOffset.y;
	_headerView.frame = headerFrame;
}

#pragma mark - PSListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
	}

	return _specifiers;
}

#pragma mark - Callbacks

- (NSString *)bannerTintEnabled:(PSSpecifier *)specifier {
	return ((NSNumber *)[self readPreferenceValue:specifier]).boolValue ? @"On" : @"Off";
}

- (NSString *)lockScreenTintEnabled:(PSSpecifier *)specifier {
	return ((NSNumber *)[self readPreferenceValue:specifier]).boolValue ? @"On" : @"Off";
}

- (void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

- (void)showTestNotificationCenterBulletin {
	notify_post("ws.hbang.flagpaint/TestNotificationCenterBulletin");
}

#pragma mark - Memory management

- (void)dealloc {
	[_headerView release];

	[super dealloc];
}

@end
