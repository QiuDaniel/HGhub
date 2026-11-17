//! iOS（WKWebView）视口修正。
//!
//! 现象：iPhone 上页面视口比屏幕矮「顶部安全区 + 底部安全区」那么多
//! （实测 16 Pro：screen 402×874，`window.innerHeight` = 778 = 874−62−34），
//! 下边露出 WKWebView 默认的白色背景，底栏悬在离屏幕底 96pt 的位置。
//!
//! 原因：WKWebView 的 `scrollView.contentInsetAdjustmentBehavior` 默认是
//! `.automatic`，UIKit 会把安全区作为 contentInset 塞进滚动视图，WebKit 据此
//! 收窄「布局视口」；而前端 `index.html` 又开了 `viewport-fit=cover`，CSS 里
//! `env(safe-area-inset-*)`（App.tsx 的 `--sat` / `--sab`）再补偿一次 —— 两次叠加。
//!
//! 修法：把 `contentInsetAdjustmentBehavior` 设为 `.never`（枚举值 2），
//! 视口恢复整屏，安全区只由 CSS 的 `env()` 负责（这也是 `App.tsx` 的既有设计）。
//!
//! 只走 objc runtime 的消息发送，不引入额外 crate；仅在 iOS 目标编译。

#![cfg(target_os = "ios")]

use std::ffi::{c_char, c_void};

// objc_msgSend 是同一个符号的多个签名，按调用点分别声明是有意为之，
// 否则就得用 C 可变参数声明（在 arm64 上更容易出错）。
#[allow(clashing_extern_declarations)]
extern "C" {
    fn sel_registerName(name: *const c_char) -> *mut c_void;

    /// `- (UIScrollView *)scrollView`（无参，返回对象）
    #[link_name = "objc_msgSend"]
    fn msg_send_id(receiver: *mut c_void, selector: *mut c_void) -> *mut c_void;
    /// `- (void)setContentInsetAdjustmentBehavior:(NSInteger)`（一个整型参数）
    #[link_name = "objc_msgSend"]
    fn msg_send_void_isize(receiver: *mut c_void, selector: *mut c_void, arg: isize);
}

/// `UIScrollViewContentInsetAdjustmentBehavior::Never`
const BEHAVIOR_NEVER: isize = 2;

fn sel(name: &'static [u8]) -> *mut c_void {
    debug_assert_eq!(name.last(), Some(&0), "SEL 字面量必须以 NUL 结尾");
    unsafe { sel_registerName(name.as_ptr() as *const c_char) }
}

/// 关掉 WebView 的安全区 contentInset 调整。`webview` 是 WKWebView 指针。
///
/// # Safety
/// `webview` 必须是主线程上有效的 WKWebView 实例指针（Tauri 的
/// `PlatformWebview::inner()` 给的就是它，`with_webview` 保证在主线程执行）。
pub unsafe fn disable_safe_area_insets(webview: *mut c_void) {
    if webview.is_null() {
        return;
    }
    let scroll_view = unsafe { msg_send_id(webview, sel(b"scrollView\0")) };
    if scroll_view.is_null() {
        return;
    }
    unsafe {
        msg_send_void_isize(
            scroll_view,
            sel(b"setContentInsetAdjustmentBehavior:\0"),
            BEHAVIOR_NEVER,
        );
    }
}

/// 在启动时对 `main` 窗口（也即移动端唯一的 WebView）打补丁。
/// 窗口可能比 setup 回调晚建好，所以失败时短暂重试。
pub fn install(app: &tauri::AppHandle) {
    use tauri::Manager;

    fn apply(app: &tauri::AppHandle) -> bool {
        let Some(window) = app.get_webview_window("main") else {
            return false;
        };
        window
            .with_webview(|wv| unsafe { disable_safe_area_insets(wv.inner()) })
            .is_ok()
    }

    if apply(app) {
        return;
    }
    let handle = app.clone();
    std::thread::spawn(move || {
        for _ in 0..50 {
            std::thread::sleep(std::time::Duration::from_millis(100));
            if apply(&handle) {
                return;
            }
        }
    });
}
