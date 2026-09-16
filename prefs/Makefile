ARCHS = arm64 arm64e
# Pinned rather than "latest": latest resolves to Xcode's SDK, which ships no
# private framework stubs, so -framework Preferences fails to link.
TARGET := iphone:clang:16.5:15.0

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = TelegramTimeSensitivePrefs

TelegramTimeSensitivePrefs_FILES = TTSRootListController.m ../TTSCommon.m
TelegramTimeSensitivePrefs_INSTALL_PATH = /Library/PreferenceBundles
TelegramTimeSensitivePrefs_FRAMEWORKS = UIKit
TelegramTimeSensitivePrefs_PRIVATE_FRAMEWORKS = Preferences
TelegramTimeSensitivePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/TelegramTimeSensitive.plist"$(ECHO_END)
