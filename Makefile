ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = FlagPaint7
FlagPaint7_FILES = $(wildcard *.xm) $(wildcard *.m)
FlagPaint7_FRAMEWORKS = UIKit CoreGraphics QuartzCore Accelerate
FlagPaint7_PRIVATE_FRAMEWORKS = BulletinBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
ifeq ($(RESPRING),0)
	install.exec "killall Preferences; sleep 0.2; sbopenurl 'prefs:root=Cydia&path=FlagPaint7'"
else
	install.exec spring
endif

ifneq ($(TARGET),simulator)
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
endif
