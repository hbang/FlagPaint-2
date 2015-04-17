#import "HBFPGradientView.h"

@implementation HBFPGradientView

@dynamic layer;

+ (Class)layerClass {
	return [CAGradientLayer class];
}

@end
