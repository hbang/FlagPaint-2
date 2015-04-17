#import "HBFPRootListController.h"
#import "HBFPHeaderView.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#include <notify.h>
#include <substrate.h>
#import <version.h>

static CGFloat const kHBFPHeaderTopInset = 64.f; // i'm so sorry.
static CGFloat const kHBFPHeaderHeight = 150.f;

@implementation HBFPRootListController {
	HBFPHeaderView *_headerView;
	UIView *_titleView;

	BOOL _hasStatusBarTweak;
	BOOL _isVisible;
}

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"Root";
}

+ (NSString *)hb_shareText {
	return @"I’m using #FlagPaint to add color to my notifications!";
}

+ (NSURL *)hb_shareURL {
	return [NSURL URLWithString:@"https://www.hbang.ws/flagpaint"];
}

+ (UIColor *)hb_tintColor {
	return [UIColor colorWithRed:35.f / 255.f green:208.f / 255.f blue:189.f / 255.f alpha:1];
}

#pragma mark - UIViewController

- (void)loadView {
	[super loadView];

	self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"FlagPaint" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];

	_headerView = [[HBFPHeaderView alloc] initWithTopInset:kHBFPHeaderTopInset];
	_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.table addSubview:_headerView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
		CGFloat headerHeight = kHBFPHeaderTopInset + kHBFPHeaderHeight;

		self.table.contentInset = UIEdgeInsetsMake(headerHeight, 0, 0, 0);
		self.table.contentOffset = CGPointMake(0, -headerHeight);

		_headerView.frame = CGRectMake(0, -headerHeight, self.view.frame.size.width, headerHeight);
	});

	[self reloadSpecifier:[self specifierForID:@"Tint"]];
	[self reloadSpecifier:[self specifierForID:@"TintLockScreen"]];
	[self reloadSpecifier:[self specifierForID:@"TintNotificationCenter"]];

	_titleView = IS_IOS_OR_NEWER(iOS_8_0) ? MSHookIvar<UIView *>(self.navigationItem, "_defaultTitleView") : MSHookIvar<UIView *>(self.navigationController.navigationBar, "_titleView");

	_isVisible = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	_titleView.alpha = 1;
	_isVisible = NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (!_isVisible) {
		return;
	}

	if (_titleView) {
		_titleView.alpha = (scrollView.contentOffset.y / kHBFPHeaderHeight) + 1;
	}

	if (scrollView.contentOffset.y >= -kHBFPHeaderTopInset - kHBFPHeaderHeight) {
		return;
	}

	CGRect headerFrame = _headerView.frame;
	headerFrame.origin.y = scrollView.contentOffset.y;
	headerFrame.size.height = -scrollView.contentOffset.y;
	_headerView.frame = headerFrame;
}

#pragma mark - Callbacks

- (NSString *)specifierEnabledString:(PSSpecifier *)specifier {
	NSString *string = ((NSNumber *)[self readPreferenceValue:specifier]).boolValue ? @"On" : @"Off";
	return [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:string value:string table:@"Localizable"];
}

- (void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}

- (void)showTestLockScreenNotification {
	notify_post("ws.hbang.flagpaint/TestLockScreenNotification");
}

#pragma mark - Memory management

- (void)dealloc {
	[_headerView release];
	[super dealloc];
}

@end
