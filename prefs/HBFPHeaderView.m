#import "HBFPHeaderView.h"

@implementation HBFPHeaderView

+ (Class)layerClass {
	return CAGradientLayer.class;
}

- (instancetype)initWithTopInset:(CGFloat)topInset {
	self = [self init];

	if (self) {
		self.clipsToBounds = YES;

		((CAGradientLayer *)self.layer).locations = @[ @0, @0.5f, @0.75f, @1 ];
		((CAGradientLayer *)self.layer).colors = @[
			(id)[UIColor colorWithRed:98.f / 255.f green:209.f / 255.f blue:210.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:34.f / 255.f green:163.f / 255.f blue:124.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:73.f / 255.f green:152.f / 255.f blue:87.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:103.f / 255.f green:147.f / 255.f blue:35.f / 255.f alpha:1].CGColor
		];

		NSMutableAttributedString *attributedString = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"FlagPaint7\nby HASHBANG Productions\nVersion %@", @"1.0"]] autorelease];

		NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		paragraphStyle.lineSpacing = 10.f;
		paragraphStyle.alignment = NSTextAlignmentCenter;

		[attributedString setAttributes:@{
			NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Thin" size:50.f],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.f alpha:0.8f],
			NSKernAttributeName: [NSNull null],
			NSParagraphStyleAttributeName: paragraphStyle
		} range:NSMakeRange(0, 9)];

		[attributedString setAttributes:@{
			NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:50.f],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.f alpha:0.5f],
			NSKernAttributeName: [NSNull null]
		} range:NSMakeRange(9, 1)];

		[attributedString setAttributes:@{
			NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:16.f],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:0.8f alpha:0.7f],
			NSKernAttributeName: [NSNull null]
		} range:NSMakeRange(11, attributedString.string.length - 11)];

		UILabel *flagPaintLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, topInset, 0, self.frame.size.height - topInset)] autorelease];
		flagPaintLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		flagPaintLabel.textAlignment = NSTextAlignmentCenter;
		flagPaintLabel.numberOfLines = 0;
		flagPaintLabel.attributedText = attributedString;
		[self addSubview:flagPaintLabel];
	}

	return self;
}

@end
