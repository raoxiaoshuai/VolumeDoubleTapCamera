//
//  Tweak.x
//  VolumeDoubleTapCamera
//
//  功能：双击音量+键唤起原生相机 App
//  设计：仅捕获双击事件，单击/长按保留原生音量调节行为
//  注入目标：SpringBoard（com.apple.springboard）
//  兼容：iOS 15.6 arm64
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ============ 全局状态 ============
// 上一次音量+按键触发的时间戳（基于 NSDate 参考时间）
static NSTimeInterval g_lastVolumeUpTime = 0.0;
// 双击识别窗口（秒）：两次点击间隔小于此值视为双击
static const NSTimeInterval kDoubleClickInterval = 0.6;
// 长按去抖阈值（秒）：两次调用间隔小于此值视为长按连续触发，不计入双击
static const NSTimeInterval kLongPressDebounce = 0.15;

// ============ 唤起相机 App 的 C 函数 ============
// 用 C 函数而不是 OC 方法，避免 SBVolumeControl 前向声明问题
static void VDCLaunchCameraApp(void) {
    @autoreleasepool {
        // 获取 LSApplicationWorkspace 类
        Class LSAppWS = objc_getClass("LSApplicationWorkspace");
        if (!LSAppWS) return;

        // 调用 +defaultWorkspace 获取单例
        id (*getWorkspace)(Class, SEL) = (void *)objc_msgSend;
        id workspace = getWorkspace(LSAppWS, @selector(defaultWorkspace));
        if (!workspace) return;

        // 调用 -openApplicationWithBundleID: 打开相机
        // com.apple.camera 是系统相机的 bundle id
        BOOL (*openApp)(id, SEL, NSString *) = (void *)objc_msgSend;
        openApp(workspace, @selector(openApplicationWithBundleID:), @"com.apple.camera");
    }
}

%hook SBVolumeControl

// 系统在按下音量+键时会调用此方法
// 通过拦截此方法检测双击，同时保留原生音量调节
- (void)increaseVolume {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    if (g_lastVolumeUpTime > 0.0) {
        NSTimeInterval interval = now - g_lastVolumeUpTime;

        // 仅当间隔处于 (长按去抖阈值, 双击窗口) 之间时识别为双击
        if (interval > kLongPressDebounce && interval < kDoubleClickInterval) {
            // 识别为双击：唤起相机，阻止本次音量变化
            g_lastVolumeUpTime = 0.0;
            VDCLaunchCameraApp();
            return;
        }
    }

    // 记录本次点击时间
    g_lastVolumeUpTime = now;

    // 调用原方法，保留原生音量+调节功能
    %orig;
}

%end
