TARGET = iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FlagPaint7
FlagPaint7_FILES = $(wildcard *.xm) $(wildcard *.m)
FlagPaint7_FRAMEWORKS = UIKit CoreGraphics QuartzCore Accelerate
FlagPaint7_PRIVATE_FRAMEWORKS = BulletinBoard
FlagPaint7_LIBRARIES = applist cephei

include $(THEOS_MAKE_PATH)/tweak.mk

ifneq ($(TARGET),simulator)
	SUBPROJECTS += prefs
	include $(THEOS_MAKE_PATH)/aggregate.mk
endif

after-install::
ifeq ($(RESPRING),0)
	install.exec "killall Preferences; sleep 0.2; sbopenurl 'prefs:root=FlagPaint'"
else
	install.exec spring
endif
