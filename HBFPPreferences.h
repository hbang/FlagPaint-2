@interface HBFPPreferences : NSObject

@property BOOL hadFirstRun;

@property (readonly) BOOL tintBanners;
@property (readonly) BOOL tintLockScreen;
@property (readonly) BOOL tintNotificationCenter;

@property (readonly) BOOL biggerIcon;
@property (readonly) BOOL albumArtIcon;

@property (readonly) BOOL bannerGradient;
@property (readonly) BOOL bannerBorderRadius;
@property (readonly) BOOL bannerTextShadow;
@property (readonly) BOOL bannerRemoveGrabber;

@property (readonly) BOOL lockGradient;
@property (readonly) BOOL lockFade;
@property (readonly) BOOL lockDisableDimming;
@property (readonly) BOOL lockRemoveAction;

@property (readonly) BOOL notificationCenterFade;

@property (readonly) CGFloat tintVibrancy;
@property (readonly) CGFloat bannerColorIntensity;
@property (readonly) CGFloat bannerGrayscaleIntensity;
@property (readonly) CGFloat bannerOpacity;
@property (readonly) CGFloat lockOpacity;
@property (readonly) CGFloat notificationCenterOpacity;

@property (readonly) BOOL removeIcon;
@property (readonly) BOOL removeDateLabel;

@property (readonly) BOOL fonz;

@property (nonatomic, retain, readonly) NSDictionary *themeTints;

- (UIColor *)customTintForKey:(NSString *)key;

@end
