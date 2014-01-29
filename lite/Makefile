ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = FlagPaint7Lite
FlagPaint7Lite_FILES = Tweak.xm
FlagPaint7Lite_FRAMEWORKS = UIKit CoreGraphics QuartzCore
FlagPaint7Lite_PRIVATE_FRAMEWORKS = BulletinBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
ifeq ($(RESPRING),0)
	install.exec "killall Preferences; sleep 0.2; sbopenurl 'prefs:root=Cydia&path=FlagPaint7 Lite'"
else
	install.exec "killall SpringBoard"
endif

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
