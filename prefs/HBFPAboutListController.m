#import "HBFPAboutListController.h"

@implementation HBFPAboutListController

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"About";
}

#pragma mark - Callbacks

- (void)openTranslations {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.hbang.ws/translations/"]];
}

@end
