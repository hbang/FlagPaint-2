include theos/makefiles/common.mk

BUNDLE_NAME = FlagPaint7
FlagPaint7_FILES = FlagPaint7.mm
FlagPaint7_INSTALL_PATH = /Library/PreferenceBundles
FlagPaint7_FRAMEWORKS = UIKit
FlagPaint7_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FlagPaint7.plist$(ECHO_END)
