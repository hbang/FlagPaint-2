#import "NSCache+Subscripting.h"

@implementation NSCache (Subscripting)

- (id)objectForKeyedSubscript:(id)key {
	return [self objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id<NSCoding>)key {
	[self setObject:object forKey:key];
}

@end
