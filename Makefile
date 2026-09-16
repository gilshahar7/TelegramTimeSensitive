TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TelegramTimeSensitive

TelegramTimeSensitive_FILES = TTSCommon.m NSEHook.x SpringBoardHook.x
TelegramTimeSensitive_CFLAGS = -fobjc-arc
TelegramTimeSensitive_FRAMEWORKS = UserNotifications

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
