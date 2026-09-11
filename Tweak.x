//
//  Tweak.x
//  VolumeDoubleTapCamera
//
//  功能：双击音量+键唤起原生相机 App
//  优化：相机启动放后台线程，避免阻塞 SpringBoard 主线程
//  注入目标：SpringBoard（com.apple.springboard）
//  兼容：iOS 15.6 arm64
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach_time.h>

// ============ 全局状态 ============
// 上一次有效按键的 mach 时间戳
static uint64_t g_lastTapTime = 0;
// 双击识别窗口：0.6 秒（单位：纳秒）
static const uint64_t kDoubleClickNS = 600000000ULL;
// 长按去抖：小于 0.1 秒视为长按连续触发，直接跳过不处理
static const uint64_t kDebounceNS = 100000000ULL;

// 预声明 objc_msgSend 函数指针，避免运行时查找
static id (*g_msgSend_id)(id, SEL) = (void *)objc_msgSend;
static BOOL (*g_msgSend_BOOL_id)(id, SEL, id) = (void *)objc_msgSend;

// ============ 唤起相机 App（后台执行） ============
static void VDCLaunchCameraApp(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Class LSAppWS = objc_getClass("LSApplicationWorkspace");
        if (!LSAppWS) return;

        id workspace = g_msgSend_id(LSAppWS, @selector(defaultWorkspace));
        if (!workspace) return;

        // openApplicationWithBundleID: 是同步调用，放后台避免阻塞 SpringBoard
        g_msgSend_BOOL_id(workspace, @selector(openApplicationWithBundleID:), @"com.apple.camera");
    });
}

%hook SBVolumeControl

// 系统在音量+变化时调用此方法（按键/长按/系统调节均会触发）
- (void)increaseVolume {
    uint64_t now = mach_absolute_time();

    if (g_lastTapTime > 0) {
        uint64_t interval = now - g_lastTapTime;

        // 间隔过短：长按的连续触发，直接调用原方法，不做双击判断
        if (interval < kDebounceNS) {
            %orig;
            return;
        }

        // 间隔在双击窗口内：识别为双击，唤起相机
        if (interval < kDoubleClickNS) {
            g_lastTapTime = 0;
            VDCLaunchCameraApp();
            return; // 不调用 %orig，避免相机启动时音量变化
        }
    }

    // 记录本次时间戳，等待可能的第二次点击
    g_lastTapTime = now;

    // 调用原方法，保留原生音量调节
    %orig;
}

%end
