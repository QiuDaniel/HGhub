# AIRead.md — AI 协作交接文档

> 写给后续接手的 AI（或人）：本次改动是 **为项目新增 iOS 端支持**（原本只有 Windows / macOS / Android）。
> 阅读顺序建议：先看「改动清单」，再按你要做的任务跳到对应章节。

---

## 一、改动背景（2026-11-17）

项目是 Tauri 2 + React 19 的跨端客户端，原本三端。本次把 iOS 端「能跑」所需的全部代码补齐。
**改动在 Windows 上开发，前端构建（`pnpm build`）已验证通过；iOS 编译/运行必须在 Mac 上验证（见第四节）。**

Rust 侧（`src-tauri/src/`）**零改动**——`lib.rs` 本来就是移动端就绪的：

- `#[cfg_attr(mobile, tauri::mobile_entry_point)]` 已存在（`src-tauri/src/lib.rs:10`）
- 自定义协议的 iOS 分支本来已写好：iOS/macOS 用 `hg://localhost`，Windows/Android 用 `http://hg.localhost`（`src-tauri/src/media.rs` 的 `LOCAL_ORIGIN`，与前端 `src/api.ts` 的 `LOCAL` 必须一致，两处都是按 `cfg` / UA 自动判平台）

## 二、改动清单

### 2.1 前端：iOS 平台识别 + 复用安卓移动端布局

| 文件 | 改动 |
|---|---|
| `src/api.ts` | 新增 `isIOS` 导出。判定：UA 含 `iPad\|iPhone\|iPod`，**或** UA 是 `Macintosh` 且 `navigator.maxTouchPoints > 1`（iPadOS 13+ 伪装桌面 UA）。⚠️ `platform` 赋值顺序是 android → **ios → macos** → windows，iPhone 的 UA 含 "like Mac OS X"，ios 必须先于 macos 判定。`platform` 联合类型加入 `"ios"`；`LOCAL` 改为 `isMacos \|\| isIOS ? "hg://localhost" : "http://hg.localhost"`。另新增三个真机适配工具（见 2.1.1） |
| `src/store.tsx` | `export type Platform` 加入 `"ios"` |
| `src/App.tsx` | 新增导出 `isMobilePlatform(p)`（`p === "android" \|\| p === "ios"`）。`AppBody` 里原来看 `platform === "android"` 的 4 处（wide 初值、是否渲染 `DesktopRail`、`bottomInset`、`stackInset`、`TabBar` 显隐）统一改用 `mobile` 变量；`MobileShell` 的 CSS 类从写死的 `plat-android` 改成 `` plat-${platform} ``；根组件 `App` 渲染条件改为 `mobile ? <MobileShell /> : <DesktopShell />`。**安卓硬件返回键监听（`addPluginListener("app", "back-button")`）保持 android 独享**——iOS 没有硬件返回键，别动它 |
| `src/index.css` | 新增 `.plat-ios` 规则：与 `.plat-android` 共用同一组 `--r-*` / `--nav-h` 变量；`.win-main` 的移动端背景规则并列 `.plat-ios` |

### 2.1.1 真机适配（第二轮改动）：HLS 与全屏的 iOS 分支

这两个点在 iOS 真机上必须走不同路径，代码已**预先写好**（同样未经真机验证）：

| 文件 | 改动 |
|---|---|
| `src/api.ts` | ① `preferNativeHls = isIOS`：iOS 上不用 hls.js，把 Rust 改写后的 m3u8 直接交给 WKWebView 原生播放（AVPlayer）。原因：iPhone <17.1 无 MSE，hls.js 装不上；iOS 17.1+ 的 ManagedMediaSource 与自定义协议（WKURLSchemeHandler）组合坑多，AVPlayer 走同一协议 handler 是稳定路径。② `hasElementFullscreen`：按**能力**探测 `document.documentElement.requestFullscreen`（桌面/iPad 有，iPhone 没有）。③ `asWkVideo()` + `WkVideo` 类型：给 `<video>` 的 webkit 私有全屏 API（`webkitEnterFullscreen` / `webkitExitFullscreen` / `webkitDisplayingFullscreen`）一个 TS 入口 |
| `src/components/VideoSurface.tsx` | hls.js 分支条件加 `!preferNativeHls`；新增 `nativeRef` 标记本次是否原生路径，`<video onError>` 仅在原生路径上报 `` `video/${error.code}` ``（hls.js 接管时解码错误由它的 MEDIA_ERROR 处理，不重复报）。**注意：VideoSurface 之前在原生路径下完全不报错，iOS 上播放失败会表现为无限转圈——这个 onError 就是为修它加的** |
| `src/components/Player.tsx` | 同上两处（hls 条件 + nativeRef/onError，错误写入 `errMsg` 显示在左上角）；`toggleFull` 改为三段式：已全屏 → 退出；`webkitDisplayingFullscreen` → `webkitExitFullscreen()`；`hasElementFullscreen` → 容器 `requestFullscreen()`（桌面/iPad）→ 都没有（iPhone）→ `video.webkitEnterFullscreen()`。全屏状态同步在原 `fullscreenchange` 之外补监听 video 的 `webkitbeginfullscreen` / `webkitendfullscreen`（iPhone 原生全屏不触发 fullscreenchange） |
| `src/components/Feed.tsx` | `toggleFull` 与状态同步同 Player（video 经 `videoRef.current?.el()` 取，同步 effect 依赖 `playKey`，因为 video 元素随切条重建） |

### 2.2 Tauri 配置：按平台拆分

| 文件 | 状态 | 说明 |
|---|---|---|
| `src-tauri/tauri.ios.conf.json` | **新增** | iOS 专属配置：`beforeBuildCommand` 为 `pnpm build && node scripts/sync-ios-icons.mjs`；窗口 390×844（iOS 上实际全屏，此值仅模板意义）；`bundle.ios.minimumSystemVersion: "13.0"`。Tauri CLI 对 `tauri.ios.conf.json` 是**自动合并**，不需要 `--config` |
| `src-tauri/tauri.android.conf.json` | **新增** | 安卓图标同步从全局 `beforeBuildCommand` **挪到这里**：`pnpm build && node scripts/sync-android-icons.mjs`。原因：原来全局命令会让 iOS/macOS 构建也去跑安卓脚本 |
| `src-tauri/tauri.conf.json` | 修改 | `beforeBuildCommand` 精简为 `pnpm build`（安卓图标同步移走了） |
| `src-tauri/capabilities/default.json` | 修改 | 加 `"platforms": ["windows", "macOS", "linux"]`。⚠️ 原因：里面的窗口权限（minimize / start-dragging 等）在移动端 schema 校验会失败，必须限定桌面 |
| `src-tauri/capabilities/mobile.json` | **新增** | `platforms: ["android", "iOS"]`，只留 `core:default` + `core:app:allow-exit`（安卓返回键的退出指令用） |

注意 `$schema` 字段指向 `../gen/schemas/*.json`，这些文件只在跑过 `tauri ios init` / `tauri android init` 后才存在——**schema 缺失只是编辑器没有智能提示，不影响构建**，不用修。

### 2.3 脚本与文档

| 文件 | 状态 | 说明 |
|---|---|---|
| `scripts/sync-ios-icons.mjs` | **新增** | 把 `src-tauri/icons/ios/AppIcon-*.png` 拷进 `src-tauri/gen/ios/App/App/Assets.xcassets/AppIcon.appiconset/`（只拷 png，保留模板的 `Contents.json`，文件名与 `tauri icon` 生成的一致直接覆盖）。原因同安卓：`src-tauri/gen/` 在 `.gitignore` 里不入库，重新 init 后图标会退回模板默认 |
| `package.json` | 修改 | 新增 `ios:init` / `ios:icons` / `ios:dev` / `ios:build`（对应 `tauri ios init/dev/build`） |
| `README.md` | 修改 | 「三端」→「四端」；新增 iOS 构建步骤；自定义协议说明加入 iOS；FAQ 加第 4 条（iOS 签名） |

图标资源 `src-tauri/icons/ios/` **本次没有重新生成**——之前跑 `tauri icon` 时已产出，直接复用。

## 三、设计决策速查（防止后续 AI 改回去）

1. **iOS 与 Android 共用移动端壳**：两者都是无桌面窗口的竖屏移动端。桌面壳（`DesktopShell` + `DesktopTitleBar`）里的窗口控制按钮、无边框拖拽对 iOS 毫无意义。
2. **协议基址 iOS 走 `hg://localhost`**：这是 Tauri/WKWebView 的平台行为（非 `.localhost` 形式），Rust `media.rs` 与前端 `api.ts` 两处必须同时一致，改一处必须改另一处。所有媒体（封面 img、m3u8 hls、分片 seg）都经这个自定义协议走 Rust 解密/改写。
3. **capabilities 按平台拆**：不要把桌面窗口权限加回移动端，iOS 构建时 schema 校验直接报错。
4. **`beforeBuildCommand` 按平台拆**：不要把图标同步脚本加回全局 `tauri.conf.json`。
5. **iOS 上 HLS 一律走原生 `<video>`（`preferNativeHls`）**：不要"顺手"删掉这个开关让 iOS 也走 hls.js——iPhone 低版本无 MSE 直接不可播，iOS 17.1+ 的 MMS + WKURLSchemeHandler 组合未验证。如果真机发现原生路径有问题想换 hls.js 试，改 `src/api.ts` 一处即可，别改组件。

## 四、待办：必须在 Mac 上完成的步骤（代码已就绪，尚未编译验证）

Windows 上**无法**验证 iOS 编译（`tauri ios` 依赖 Xcode）。在 Mac 上：

```bash
pnpm install
pnpm ios:init                 # 生成 src-tauri/gen/ios 工程（gen/ 不入库）
# Xcode 打开 src-tauri/gen/ios/App/App.xcodeproj → Signing & Capabilities 选 Team
# （个人免费 Apple ID 可真机自签；首次安装需在 iPhone 设置里信任开发者证书）
pnpm ios:dev                  # 真机 / 模拟器调试
pnpm ios:build                # 出 .app；分发需付费开发者账号（TestFlight / ipa）
```

若 `ios:init` 报 Rust target 缺失：`rustup target add aarch64-apple-ios`（新版 CLI 一般会自动装）。

## 五、真机风险点（适配代码已预写，仍未真机验证）

第五节的 HLS 与全屏两个大项已在代码层预写（见 2.1.1），但**没有真机验证过**，跑起来后按下面顺序检查：

1. **HLS（已预写 `preferNativeHls`）**：iOS 全部走 `<video src=改写后m3u8>` 原生播放。若黑屏/无法播：先确认是不是 AVPlayer 对自定义协议 `hg://localhost` 分片请求的问题（看 Rust 侧 `media::handle` 是否收到 seg 请求），再对比 Android 端行为。若要临时改回 hls.js 路径，把 `src/api.ts` 的 `preferNativeHls` 改成 `false` 即可（iOS 17.1+ 设备会走 ManagedMediaSource）。
2. **全屏（已预写 webkit 分支）**：iPhone 上点全屏按钮应唤起系统播放器全屏（`webkitEnterFullscreen`），状态图标经 `webkitbegin/endfullscreen` 事件同步。注意 `webkitEnterFullscreen` 需要用户手势触发——现在只在点击处理器里调用，别把它挪进 useEffect。
3. **安全区**：刘海/灵动岛/底部 Home 条靠 CSS `env(safe-area-inset-*)`（`App.tsx` 的 `MobileShell` 已设 `--sat`/`--sab`，`index.html` 已有 `viewport-fit=cover`）。真机确认底栏不被 Home 条压住。
4. **`core:app:allow-exit`**：移动端 capability 里保留它是因为安卓返回键最后一级调 `plugin:app|exit`；iOS 前端从不调用它，若 iOS 构建报该权限无效，可从 `mobile.json` 拆出 ios 专属 capability。

## 六、验证状态

- ✅ `pnpm build`（tsc --noEmit + vite build）通过（2026-11-17，Windows，两轮改动后均复验）
- ✅ 所有新增/修改 JSON 手工 parse 校验通过
- ⚠️ Rust 未重新编译（代码零改动；如需可 `cargo check`）
- ⚠️ iOS 实机编译、原生 HLS 播放、webkit 全屏、安全区 —— **全部未验证**，见第四、五节
