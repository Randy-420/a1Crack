export ARCHS = arm64 arm64e
export TARGET = iphone:16.5:14.0

ifeq ($(THEOS_PACKAGE_SCHEME), )
	THEOS_PACKAGE_DIR = DEBs/rootful
else ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
	THEOS_PACKAGE_DIR = DEBs/rootless
else ifeq ($(THEOS_PACKAGE_SCHEME), roothide)
	THEOS_PACKAGE_DIR = DEBs/roothide
else ifeq ($(THEOS_PACKAGE_SCHEME), jailed)
	THEOS_PACKAGE_DIR = DEBs/jailed
else
	THEOS_PACKAGE_DIR = DEBs
endif

INSTALL_TARGET_PROCESSES = SpringBoard

SUBPROJECTS += Tweak

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk