#import "HBFPRootListController.h"
#import "HBFPHeaderView.h"
#import <CepheiPrefs/HBAppearanceSettings.h>
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
	return [NSString stringWithFormat:[bundle localizedStringForKey:@"SHARE_TEXT" value:nil table:@"Root"], [UIDevice currentDevice].localizedModel];
}

+ (NSURL *)hb_shareURL {
	return [NSURL URLWithString:@"https://www.hbang.ws/flagpaint/"];
}

#pragma mark - UIViewController

- (instancetype)init {
	self = [super init];

	if (self) {
		HBAppearanceSettings *appearance = [[HBAppearanceSettings alloc] init];
		appearance.tintColor = [UIColor colorWithRed:0.137 green:0.816 blue:0.741 alpha:1.00];
		self.hb_appearanceSettings = appearance;
	}

	return self;
}

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
	NSString *string = ((NSNumber *)[self readPreferenceValue:specifier]).boolValue ? @"ON" : @"OFF";
	return [[NSBundle bundleWithIdentifier:@"ws.hbang.common.prefs"] localizedStringForKey:string value:string table:@"Common"];
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
