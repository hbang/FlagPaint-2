#import "HBFPShadowedLabel.h"

@implementation HBFPShadowedLabel

- (void)drawTextInRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, CGSizeMake(1.f, 1.f), 2.f, [UIColor colorWithWhite:0 alpha:0.8f].CGColor);

	[super drawTextInRect:rect];

	CGContextRestoreGState(context);
}

@end
