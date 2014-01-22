#import <Preferences/PSListController.h>

@interface FlagPaint7ListController: PSListController {
}
@end

@implementation FlagPaint7ListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"FlagPaint7" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
