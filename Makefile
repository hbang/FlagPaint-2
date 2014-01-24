ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = FlagPaint7
FlagPaint7_FILES = Tweak.xm FirstLaunch.xm
FlagPaint7_FRAMEWORKS = UIKit CoreGraphics QuartzCore Accelerate
FlagPaint7_PRIVATE_FRAMEWORKS = BulletinBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "spring"

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
