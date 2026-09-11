# 目标平台：iOS 15.6 部署目标，使用 clang，SDK 14.5
TARGET := iphone:clang:14.5:15.6

# 多巴胺(Dopamine)为 rootless 越狱，必须使用 rootless 打包方案
THEOS_PACKAGE_SCHEME = rootless

# 安装后重启 SpringBoard 使 Tweak 生效
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeDoubleTapCamera

# 源文件
VolumeDoubleTapCamera_FILES = Tweak.x
# 启用 ARC
VolumeDoubleTapCamera_CFLAGS = -fobjc-arc -Wno-deprecated -Wno-unused
# 链接框架
VolumeDoubleTapCamera_LDFLAGS = -framework UIKit -framework Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
