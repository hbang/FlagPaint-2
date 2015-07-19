#import "HBFPSuggestedTweaksListController.h"
#import <Preferences/PSSpecifier.h>

@implementation HBFPSuggestedTweaksListController

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return @"SuggestedTweaks";
}

#pragma mark - Callbacks

- (void)openPackage:(PSSpecifier *)specifier {
	NSString *identifier = specifier.properties[@"packageIdentifier"];
	NSString *repo = specifier.properties[@"packageRepository"];

	NSURL *url;

	if (repo) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"cydia://url/https://cydia.saurik.com/api/share#?source=%@&package=%@", repo, identifier]];
	} else {
		url = [[NSURL URLWithString:@"cydia://package/"] URLByAppendingPathComponent:identifier];
	}

	[[UIApplication sharedApplication] openURL:url];
}

@end
