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
			(id)[UIColor colorWithRed:48.f / 255.f green:238.f / 255.f blue:181.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:42.f / 255.f green:224.f / 255.f blue:184.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:24.f / 255.f green:193.f / 255.f blue:193.f / 255.f alpha:1].CGColor,
			(id)[UIColor colorWithRed:16.f / 255.f green:178.f / 255.f blue:195.f / 255.f alpha:1].CGColor
		];

		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"FlagPaint\nby HASHBANG Productions"];

		NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
		paragraphStyle.lineSpacing = 10.f;
		paragraphStyle.alignment = NSTextAlignmentCenter;

		[attributedString setAttributes:@{
			NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:50.f],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.f alpha:0.95f],
			NSKernAttributeName: [NSNull null],
			NSParagraphStyleAttributeName: paragraphStyle
		} range:NSMakeRange(0, 9)];

		[attributedString setAttributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:18.f],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:235.f / 255.f alpha:0.7f],
			NSKernAttributeName: [NSNull null]
		} range:NSMakeRange(10, attributedString.string.length - 10)];

		UILabel *flagPaintLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, topInset, 0, self.frame.size.height - topInset)];
		flagPaintLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		flagPaintLabel.textAlignment = NSTextAlignmentCenter;
		flagPaintLabel.numberOfLines = 0;
		flagPaintLabel.attributedText = attributedString;
		[self addSubview:flagPaintLabel];
	}

	return self;
}

@end
