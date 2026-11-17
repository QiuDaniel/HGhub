# AIRead.md — AI 协作交接文档

> 写给后续接手的 AI（或人）：本次改动是 **为项目新增 iOS 端支持**（原本只有 Windows / macOS / Android）。
> 已按第二轮（macOS 真编译）的实测结果更新：重点看 2.4（视口修正）、第四节（编译步骤/环境坑）、第六节（验证状态）。

---

## 一、改动背景（2026-11-17）

项目是 Tauri 2 + React 19 的跨端客户端，原本三端。本次把 iOS 端「能跑」所需的全部代码补齐。改动分两轮：

- **第一轮（Windows）**：前端平台适配 + 配置拆分，只验证了 `pnpm build`。这一轮 `src-tauri/` 确实零改动。
- **第二轮（macOS）**：真实编译验证。修掉 3 个「只有真编译才会暴露」的配置错误（`bundle.iOS` 键名、部署目标下限、图标同步路径），并新增 `src-tauri/src/ios_viewport.rs` 修 iOS 视口 —— **Rust 侧从此不再零改动**，详见 2.4。

`lib.rs` 在第一轮时本来就是移动端就绪的：

- `#[cfg_attr(mobile, tauri::mobile_entry_point)]` 已存在（`src-tauri/src/lib.rs:12`，第二轮加了 `mod ios_viewport;` 后行号从 10 变成 12）
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
| `src-tauri/tauri.ios.conf.json` | **新增** | iOS 专属配置：`beforeBuildCommand` 为 `pnpm build && node scripts/sync-ios-icons.mjs`；窗口 390×844（iOS 上实际全屏，此值仅模板意义）；`bundle.iOS.minimumSystemVersion: "15.0"`。Tauri CLI 对 `tauri.ios.conf.json` 是**自动合并**，不需要 `--config`。⚠️ 两个坑见下 |
| `src-tauri/tauri.android.conf.json` | **新增** | 安卓图标同步从全局 `beforeBuildCommand` **挪到这里**：`pnpm build && node scripts/sync-android-icons.mjs`。原因：原来全局命令会让 iOS/macOS 构建也去跑安卓脚本 |
| `src-tauri/tauri.conf.json` | 修改 | `beforeBuildCommand` 精简为 `pnpm build`（安卓图标同步移走了） |
| `src-tauri/capabilities/default.json` | 修改 | 加 `"platforms": ["windows", "macOS", "linux"]`。⚠️ 原因：里面的窗口权限（minimize / start-dragging 等）在移动端 schema 校验会失败，必须限定桌面 |
| `src-tauri/capabilities/mobile.json` | **新增** | `platforms: ["android", "iOS"]`，只留 `core:default` + `core:app:allow-exit`（安卓返回键的退出指令用） |

注意 `$schema` 字段指向 `../gen/schemas/*.json`，这些文件只在跑过 `tauri ios init` / `tauri android init` 后才存在——**schema 缺失只是编辑器没有智能提示，不影响构建**，不用修。

**`tauri.ios.conf.json` 踩过的两个坑（都已修，别改回去）：**

1. **键名是 `bundle.iOS`，不是 `bundle.ios`。** Tauri 2 的 `BundleConfig` 里 `macOS` / `iOS` 都是大写开头（只有 `android`、`windows`、`linux` 是小写）。写成 `ios` 时 `tauri ios init` 直接报 `Additional properties are not allowed ('ios' was unexpected)`，整条 iOS 流程起不来。
2. **`minimumSystemVersion` 不能低于当前 Xcode SDK 的下限。** Tauri 默认 13.0，但 Xcode 27 / iOS 27.1 SDK 只接受 **15.0–27.1**，低于下限时 xcodebuild 直接 `BUILD FAILED`（报 `The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0, but the range of supported deployment target versions is 15.0 to 27.1`）。本项目现为 `15.0`；想支持更老系统只能换更老的 Xcode。

### 2.3 脚本与文档

| 文件 | 状态 | 说明 |
|---|---|---|
| `scripts/sync-ios-icons.mjs` | **新增** | 把 `src-tauri/icons/ios/AppIcon-*.png` 拷进 **`src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset/`**（只拷 png，保留模板的 `Contents.json`，文件名与 `tauri icon` 生成的一致直接覆盖）。原因同安卓：`src-tauri/gen/` 在 `.gitignore` 里不入库，重新 init 后图标会退回模板默认。⚠️ 路径原本写成 `gen/ios/App/App/Assets.xcassets/...`（那是 Tauri 1 / 其他模板的布局），而 Tauri 2 实际生成在 **`gen/apple/`**，且脚本在目标不存在时只打印「跳过」并 `exit 0`，**表现为静默失效：图标永远不同步、构建也不报错**。改路径后实测能正常覆盖 18 个 png |
| `package.json` | 修改 | 新增 `ios:init` / `ios:icons` / `ios:dev` / `ios:build`（对应 `tauri ios init/dev/build`） |
| `README.md` | 修改 | 「三端」→「四端」；新增 iOS 构建步骤；自定义协议说明加入 iOS；FAQ 加第 4 条（iOS 签名） |

图标资源 `src-tauri/icons/ios/` **本次没有重新生成**——之前跑 `tauri icon` 时已产出，直接复用。

### 2.4 Rust：iOS 视口修正（第二轮新增，唯一一处 Rust 改动）

| 文件 | 状态 | 说明 |
|---|---|---|
| `src-tauri/src/ios_viewport.rs` | **新增** | 只在 `cfg(target_os = "ios")` 下编译。启动时用 `WebviewWindow::with_webview` 拿到 WKWebView 指针，经 objc runtime 把 `scrollView.contentInsetAdjustmentBehavior` 设为 `.never`（枚举值 2）。不新增任何 crate 依赖（手写 `objc_msgSend` / `sel_registerName` 的 extern 声明，用 `#[allow(clashing_extern_declarations)]` 允许同名符号不同签名） |
| `src-tauri/src/lib.rs` | 修改 | `mod ios_viewport;`（带 cfg）+ `setup` 里一行 `ios_viewport::install(app.handle())`。窗口可能晚于 setup 建好，内部有 50×100ms 重试 |

**为什么要这个补丁（现象 → 根因 → 数据）：** iPhone 上页面视口比屏幕矮「顶部安全区 + 底部安全区」，底部露出一条 WKWebView 默认白底，底栏悬在离屏幕底 96pt 处。实测（模拟器读 `window.innerHeight` + `env(safe-area-inset-*)`）：

| 设备 | 屏幕 (pt) | 修复前 innerHeight | 安全区 sat/sab | 修复后 |
|---|---|---|---|---|
| iPhone 16 Pro | 402×874 | 402×**778** | 62 / 34 | 402×**874** ✅ |
| iPhone 16 Pro Max | 440×956 | 440×**860** | 62 / 34 | 整屏 ✅ |
| iPhone SE (3rd) | 375×667 | 375×**647** | 20 / 0 | 整屏 ✅ |

差额恒等于 `sat + sab`：WKWebView 默认 `contentInsetAdjustmentBehavior = .automatic`，UIKit 把安全区当 contentInset 塞进滚动视图，WebKit 据此收窄布局视口；而前端已经开了 `viewport-fit=cover`，`App.tsx` 的 `--sat` / `--sab`（以及 `Feed.tsx`、`ui.tsx`）又补偿一次 —— **两次叠加**。补丁的效果是「视口恢复整屏，安全区只由 CSS `env()` 负责」，与前端既有设计一致。

### 2.5 上游接口变更（2026-11-17 实测，别再用老写法）

| 事项 | 结论 |
|---|---|
| **播放** | 老的 `GET /api/videos/{id}/play` 已废弃，返回的 `video_url` 是空串（界面表现为「暂无播放地址」）。现行接口是 `POST /api/videos/{id}/episodes/{ep}/playback`，**body 必须是空 JSON `{}`**（带 id/ep 会返回 `播放参数无效`），响应看 `data.streams.main / hevc / preview`。⚠️ **这个接口不能走 `/api/edge/request` 信封**（信封会返回 `{"error":"请求无法处理"}`），`net::post_json` 就是为它加的；`api_play` 仍保留旧接口兜底 |
| **分类** | 必须用数字 `cate_id`：`/api/videos?cate_id=24&page=&size=`。旧的 `/api/videos/category/{slug}` 已被上游下架，返回 410「内容已下线」；`category_id` 会被静默忽略并返回全量。`Category.tsx` 的 `CHANNELS` 现在写的是 `24/25/26/27`，其中 26/27 上游已清空，页面加载完会自动隐藏空频道 |
| 分页 | `/api/videos?page=N` 每页 20 条，`size` / `limit` 上游不认；榜单只给前 20，不能翻页 |
| 封面 | 仍是 AES-128-CBC(NoPadding)，key/iv 见 `media.rs` 顶部；与社区复刻版实现一致，可互相印证 |
| CDN 域名 | 会漂：清单在 `*.tjyyjk.cn`，密钥/分片在 `tp*.qnlycc.cn`，图床 `pic.qnlycc.cn`。**别把这些域名硬编码成白名单**，否则上游一改版就挂 |

线索来源：社区复刻版 `https://github.com/vps1986/hghub-clone` 的 `proxy/server.py` 顶部注释 + README 第十二节，那边把上游改版史和踩坑记下来了。

### 2.6 iOS 播放必须直连上游（实测踩出来的）

`<video>` 在 WKWebView 里由 AVFoundation 拉流，**不经过 WKURLSchemeHandler**，所以把 `hg://localhost/hls?u=...` 喂给它只会得到 `MEDIA_ERR_SRC_NOT_SUPPORTED`（界面显示 `video/4`，而封面 `<img>` 走 WebKit 网络栈是正常的）。

修法：`src/api.ts` 的 `playSrc()` —— iOS（`preferNativeHls`）直接返回上游 m3u8/mp4 **原地址**，AVPlayer 自己拉清单/密钥/分片（AES-128 HLS 是原生支持的）；其它平台仍走 `mediaUrl()` → `hg://` 改写（Windows/Android 的 WebView 需要它绕 CORS）。`Player.tsx` 与 `VideoSurface.tsx` 都已改用 `playSrc()`。

## 三、设计决策速查（防止后续 AI 改回去）

1. **iOS 与 Android 共用移动端壳**：两者都是无桌面窗口的竖屏移动端。桌面壳（`DesktopShell` + `DesktopTitleBar`）里的窗口控制按钮、无边框拖拽对 iOS 毫无意义。
2. **协议基址 iOS 走 `hg://localhost`**：这是 Tauri/WKWebView 的平台行为（非 `.localhost` 形式），Rust `media.rs` 与前端 `api.ts` 两处必须同时一致，改一处必须改另一处。封面与（非 iOS 的）视频都经这个自定义协议走 Rust 解密/改写。**例外：iOS 的 `<video>` 必须直连上游**，见第 8 条。
3. **capabilities 按平台拆**：不要把桌面窗口权限加回移动端，iOS 构建时 schema 校验直接报错。
4. **`beforeBuildCommand` 按平台拆**：不要把图标同步脚本加回全局 `tauri.conf.json`。
5. **iOS 上 HLS 一律走原生 `<video>`（`preferNativeHls`）**：不要"顺手"删掉这个开关让 iOS 也走 hls.js——iPhone 低版本无 MSE 直接不可播，iOS 17.1+ 的 MMS + WKURLSchemeHandler 组合未验证。如果真机发现原生路径有问题想换 hls.js 试，改 `src/api.ts` 一处即可，别改组件。
6. **不要删掉 `ios_viewport.rs` 那个原生补丁**：它修的不是"多垫了一层"，而是 WKWebView 把安全区算进了布局视口。删掉后底部会重新出现白带（96pt/20pt 视设备而定），且**不会**有编译错误，只表现为真机/模拟器上一条突兀的白边 —— 见 2.4 的实测数据表。
7. **部署目标 `15.0` 是 Xcode 27 的硬下限**，不是随便挑的；换 Xcode 大版本时要重新确认这个下限（新版可能抬到 16/17）。
8. **iOS 的视频地址必须用 `playSrc()` 直连上游，不要改回 `playlist()`**：`<video>` 走 AVFoundation，不经过 WKURLSchemeHandler，`hg://` 会被判为不支持的媒体源（`video/4`），**编译和封面都正常，只有视频黑屏/报错**——见 2.6。

## 四、Mac 上的编译步骤与当前状态

Windows 上**无法**验证 iOS 编译（`tauri ios` 依赖 Xcode）。以下在 macOS（Xcode 27.1 / iOS 27.1 SDK / CocoaPods 1.17 / Node 24 / pnpm 12）上跑过：

```bash
pnpm install
pnpm ios:init                 # 生成 src-tauri/gen/apple/（gen/ 不入库）
node scripts/sync-ios-icons.mjs

# 模拟器（无需签名，编译验证走这条）
pnpm tauri ios build --target aarch64-sim --debug
xcrun simctl install booted src-tauri/gen/apple/build/arm64-sim/HGhub.app
xcrun simctl launch booted com.hghub.huangguo

# 真机（需要 Team，见下面的「未完成」）
pnpm ios:dev
pnpm ios:build
```

生成出来的东西（**AIRead 早前写的 `gen/ios/App/App.xcodeproj` 是错的**）：

- 工程根目录：`src-tauri/gen/apple/`
- Xcode 工程：`src-tauri/gen/apple/huangguo-client.xcodeproj`
- **scheme / target 名：`huangguo-client_iOS`**（不是 `App`）
- 产物：`src-tauri/gen/apple/build/arm64-sim/HGhub.app`
- 另有 `Podfile` / `project.yml`（XcodeGen 生成，改配置后重跑 `pnpm ios:init` 会覆盖）

**未完成：真机签名。** `pnpm tauri ios build --target aarch64` 会在编译前中止，报 `Signing for "huangguo-client_iOS" requires a development team`。要填 `tauri.ios.conf.json` 的 `bundle.iOS.developmentTeam`（或在 Xcode 的 Signing & Capabilities 选 Team）。注意 `com.hghub.huangguo` 需在该账号下注册；个人免费 Team 只能自签真机，且首次安装要在 iPhone 设置里信任开发者证书。

如 `ios:init` 报 Rust target 缺失：`rustup target add aarch64-apple-ios`（模拟器另需 `aarch64-apple-ios-sim`）。

**顺带记一笔环境坑（Windows→Mac 迁移时必踩）：**

- `node_modules` 从 Windows 拷过来是废的（里面是 `@rollup/rollup-win32-x64-*`、`@tauri-apps/cli-win32-*` 这类平台包，`.bin` 也没有可执行位），必须删掉重装。
- Corepack 起不动 pnpm 12：corepack（0.32/0.36 都）给 pnpm ≥6 硬编码入口 `bin/pnpm.cjs`，而 pnpm 12 改成了根目录 `pnpm` + `bin/pnpm.mjs`，于是 `pnpm -v` 直接 `MODULE_NOT_FOUND`。解法：`corepack disable` 后 `npm i -g pnpm@12.21.0`。
- 注意 corepack 会顺手往 `package.json` 塞 `packageManager` 字段，之后 pnpm 12 会把 pnpm 自身写进 `pnpm-lock.yaml`（多 160+ 行 `@pnpm/exe.*`）。不需要的话把该字段和 lock 一起还原。
- pnpm 12 不再读 `package.json` 里的 `pnpm.onlyBuiltDependencies`，要迁移到 `pnpm-workspace.yaml`（当前不影响构建）。

## 五、仍未验证的风险点（编译已过，功能未验）

第一~四节保证了「编译能过、能装能启动」，但下面这些**只有真机能定论**：

1. **HLS**：✅ 已在模拟器实测能播（走 `playSrc()` 直连上游 CDN，AVPlayer 原生解 AES-128）。若真机黑屏：先看 `<video>` 的 error code——`video/4` 基本等于地址又被改回了 `hg://` 自定义协议（见 2.6）；能出画面但卡住则看 CDN 是否被本地 DNS 污染或需要代理。
2. **全屏（已预写 webkit 分支）**：iPhone 上点全屏按钮应唤起系统播放器全屏（`webkitEnterFullscreen`），状态图标经 `webkitbegin/endfullscreen` 事件同步。注意 `webkitEnterFullscreen` 需要用户手势触发——现在只在点击处理器里调用，别把它挪进 useEffect。
3. **安全区**：✅ 已在模拟器上定位并修掉（见 2.4）。真机仍建议复核一遍：`--sat`/`--sab` 来自 CSS `env(safe-area-inset-*)`，原生侧的 inset 已由 `ios_viewport.rs` 关掉；若某台设备仍有白边/压住，先打印 `window.innerHeight` 与 `screen.height` 是否相等。
4. **`core:app:allow-exit`**：移动端 capability 里保留它是因为安卓返回键最后一级调 `plugin:app|exit`；iOS 前端从不调用它，若 iOS 构建报该权限无效，可从 `mobile.json` 拆出 ios 专属 capability。（当前 iOS 构建没有报这个错。）
5. **网络可达性**：本次验证时 `huangguoai.com` 从本机不可达（curl 超时 / HTTP 000），首页一直转圈，日志里是 `error sending request ... operation timed out`。这是线路/代理问题，不是 iOS 适配问题——真机联调前先确认站点可达，否则会误判成 HLS/接口的 bug。

## 六、验证状态（2026-11-17，macOS / Xcode 27.1）

| 验证项 | 命令 | 结果 |
|---|---|---|
| 前端构建 | `pnpm build`（tsc --noEmit + vite） | ✅ 856 kB JS / 52 kB CSS |
| Rust 桌面 | `cargo check`（aarch64-apple-darwin） | ✅ |
| Rust iOS 设备切片 | `cargo check --target aarch64-apple-ios` + `cargo build --target aarch64-apple-ios --lib` | ✅ 链接出 arm64 静态库 |
| iOS 模拟器整包 | `pnpm tauri ios build --target aarch64-sim --debug` | ✅ `gen/apple/build/arm64-sim/HGhub.app` |
| 模拟器启动 | `simctl install` + `launch`（iPhone 16 Pro / 18.5） | ✅ 移动壳 + 底栏渲染，视口 402×874 |
| 布局回归 | 3 台设备读 `window.innerHeight` | ✅ 均等于屏幕高度（修复前少 96/96/20pt） |
| iOS 真机整包 | `pnpm tauri ios build --target aarch64` | ⚠️ 停在 `requires a development team`（签名未配，非代码问题） |
| 播放（新接口） | 模拟器 + 镜像线路点播 | ✅ 出画面；`post_json` → `streams.main` → AVPlayer |
| 分类（cate_id） | `GET /api/videos?cate_id=24` | ✅ status=1 且有数据；410 消失 |
| 真机 HLS / webkit 全屏 / 安全区 | — | ⚠️ 真机**未验证**（模拟器已通过），见第五节 |
| 线上接口可达性 | 裸 `curl` vs 走系统代理 vs DoH | ⚠️ **不是站点挂了**：本机网络的 DNS 对这几个域名返回了污染 IP，且 `curl` 不读 macOS 系统代理。走系统代理或 DoH 均 200（所以排查这类问题别用裸 curl 下结论） |

一句话总结：**编译链路（前端 + Rust + Xcode + 打包 + 启动）跑通，模拟器上点播也通了；还差真机（签名、webkit 全屏、真机网络）。**
