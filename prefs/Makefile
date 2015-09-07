include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FlagPaint7
FlagPaint7_FILES = Global.x $(wildcard *.mm) $(wildcard *.m)
FlagPaint7_INSTALL_PATH = /Library/PreferenceBundles
FlagPaint7_CFLAGS = -include Global.h
FlagPaint7_FRAMEWORKS = UIKit CoreGraphics QuartzCore
FlagPaint7_PRIVATE_FRAMEWORKS = Preferences
FlagPaint7_LIBRARIES = cephei cepheiprefs substrate

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FlagPaint7.plist$(ECHO_END)
