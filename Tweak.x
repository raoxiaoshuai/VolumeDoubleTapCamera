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

// ============ 私有类前向声明 ============
// LSApplicationWorkspace：私有类，用于在 SpringBoard 内唤起其他 App
// 该 API 在 iOS 15.6 仍可用，未被废弃
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

// ============ 全局状态 ============
// 上一次音量+按键触发的时间戳（基于 NSDate 参考时间）
static NSTimeInterval g_lastVolumeUpTime = 0.0;
// 双击识别窗口（秒）：两次点击间隔小于此值视为双击
static const NSTimeInterval kDoubleClickInterval = 0.6;
// 长按去抖阈值（秒）：两次调用间隔小于此值视为长按连续触发，不计入双击
// 用于排除长按音量键时的高频连续触发，避免误判为双击
static const NSTimeInterval kLongPressDebounce = 0.15;

%hook SBVolumeControl

// 系统在按下音量+键时会调用此方法（每次按键事件调用一次）
// 通过拦截此方法检测双击，同时保留原生音量调节
- (void)increaseVolume {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    if (g_lastVolumeUpTime > 0.0) {
        NSTimeInterval interval = now - g_lastVolumeUpTime;

        // 仅当间隔处于 (长按去抖阈值, 双击窗口) 之间时识别为双击
        // 间隔过短 → 长按的连续触发，跳过
        // 间隔过长 → 两次独立单击，跳过
        if (interval > kLongPressDebounce && interval < kDoubleClickInterval) {
            // 识别为双击：唤起相机，并阻止本次音量变化（避免相机启动时音量UI干扰）
            g_lastVolumeUpTime = 0.0;
            [self _vdc_launchCameraApp];
            return;
        }
    }

    // 记录本次点击时间，等待可能的第二次点击
    g_lastVolumeUpTime = now;

    // 调用原方法，保留原生音量+调节功能（单击/长按均正常工作）
    %orig;
}

// 新增方法：唤起原生相机 App
%new
- (void)_vdc_launchCameraApp {
    @autoreleasepool {
        Class LSAppWS = objc_getClass("LSApplicationWorkspace");
        if (!LSAppWS) {
            return;
        }
        id workspace = [LSAppWS performSelector:@selector(defaultWorkspace)];
        if (!workspace) {
            return;
        }
        // 调用私有方法打开相机 App（bundle id: com.apple.camera）
        // SpringBoard 进程拥有足够权限，可在锁屏/桌面下唤起相机
        SEL openSel = NSSelectorFromString(@"openApplicationWithBundleID:");
        if ([workspace respondsToSelector:openSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-perform-selector-leaks"
            [workspace performSelector:openSel withObject:@"com.apple.camera"];
#pragma clang diagnostic pop
        }
    }
}

%end
