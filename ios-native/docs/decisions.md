# 决策记录（ADR）· ios-native

> 只记录**会影响后续实现**的决定。改决定时：新增一条 ADR 标记 supersedes，不要偷偷改历史。
> 更新：2026-11-17

---

## ADR-001 原生工程与 Tauri 四端并存

**状态**：Accepted（2026-11-17）

**背景**：现有 Tauri 2 + React 四端已覆盖 Windows/macOS/Android/iOS-WebView；iOS 端能编译、能播，但 UI 是 WebView。

**决定**：新增 `ios-native/` 独立工程，只交付 iOS；`src/`、`src-tauri/` 与现有构建流程完全不动。原生工程通过协议契约与 Tauri 版对齐，不共享代码。

**后果**：
- 两套 iOS 实现短期并存（Tauri iOS + 原生 iOS），文档需明确“以哪套为准”。
- 原生版可独立演进，失败也不影响现有四端。
- 根目录 README 后续可加一行“iOS 原生版”链接，但不改现有构建说明。

**备选**：直接把 Tauri 的 iOS target 替换掉（风险大、不可回退）；只做原生播放器插件（不是纯原生）。

---

## ADR-002 Swift 重写，不复用 Rust 内核

**状态**：Accepted（2026-11-17）

**背景**：Rust 侧有网络信封、封面解密、HLS 改写、线路解析，共约 1.4k 行；可通过 UniFFI/XCFramework 复用。

**决定**：iOS 端用 Swift 重写这些逻辑，不引入 FFI。

**理由**：
- 真正难的部分（AVPlayer、手势、UI）本来就必须 Swift 写，FFI 省不掉。
- 引入 UniFFI 会多一套构建、调试、错误映射链路；Rust 核心只有 1.4k 行，重写成本低于长期维护成本。
- 单端自用，没有“Android 也做原生、共享内核”的需求。

**后果**：
- 契约必须文档化（见 [api-contract.md](api-contract.md)）；上游变更要同步改两处。
- 若未来 Android 也做原生，可重新评估把核心抽成 Rust/或 Swift 共享。

**备选**：UniFFI 复用（否决）；把 Rust 编成静态库手写 C ABI（更重）。

---

## ADR-003 最低 iOS 17.0

**状态**：Accepted（2026-11-17）

**背景**：Tauri iOS 配置的最低版本是 15.0，那是 Xcode 27 SDK 的下限约束，不是产品需求。

**决定**：原生工程 `IPHONEOS_DEPLOYMENT_TARGET = 17.0`。

**理由**：
- `@Observable`、`NavigationStack`、`scrollPosition`、`.presentationDetents` 等都能直接用。
- 自用设备在 iOS 17+；不为老设备维护降级分支。
- Xcode 27.1 支持 15.0–27.1 的部署目标，17.0 安全。

**后果**：不能装 iOS 16 及以下；若以后要支持，需替换 `@Observable` 为 `ObservableObject`、调整导航与 sheet API。

---

## ADR-004 分层 MVVM + Repository

**状态**：Accepted（2026-11-17）

**背景**：需要一套能长期维护、又不过度设计的架构。

**决定**：
- App（组合根）/ Features（MVVM）/ Core（Repository + Service）/ DesignSystem。
- 单向数据流：View → ViewModel → Repository → APIClient。
- 不引 TCA，不做 UseCase 层。
- 全局状态只放 `AppState`（session/theme/feed/login/toast），其余 Feature 本地。

**后果**：
- ViewModel 可能变胖：约定单 VM <200 行，复杂逻辑抽 Service。
- 没有 reducer 的可回放性；本项目不需要。
- 测试以 VM + Repository 为主，播放器走手动冒烟。

**备选**：TCA（重）、Clean + UseCase（转发层）、单一大 Store（耦合）。

---

## ADR-005 三方库清单

**状态**：Accepted（2026-11-17）

**决定**：

| 库 | 版本 | 用途 |
|---|---|---|
| Nuke + NukeUI | 13.2.3 | 图片下载/缓存/解码；`makeImageDecoder` 挂封面解密 |
| CryptoSwift | 1.10.0 | AES-128-CBC |
| Valet | 5.1.1 | Keychain token |
| Defaults | 9.0.9 | 主题/静音/收藏/历史等轻量持久化 |
| SwiftSoup | 2.14.4 | HTML 清洗、URL 补全 |
| ZMarkupParser | 2.0.2 | HTML → NSAttributedString |
| ZNSTextAttachment | 1.2.0 | `<img>` 异步 attachment（ZMarkupParser 依赖，显式引入） |
| AlertToast | 1.3.9 | toast/HUD |
| Pulse | 5.2.3 | DEBUG 网络日志 |

**理由**：
- Nuke 的 `ImageDecoding` 适合“先解密再解码”，Kingfisher 的数据预处理链路没这么直接。
- Valet 替代 KeychainAccess：后者 `Package.swift` 带 `unsafeFlags`，作为 SPM 依赖容易踩限制。
- ZMarkupParser 支持 `<ul>/<table>/<img>`，比自写 AttributedString 或 WKWebView 更符合“纯原生”。
- 其余都是小而稳的库。

**后果**：
- CryptoSwift 是 zlib 风格许可，需在 [ACKNOWLEDGEMENTS.md](../ACKNOWLEDGEMENTS.md) 致谢。
- ZMarkupParser 的 manifest 把 `swift-snapshot-testing` 精确钉在 1.12.0；**不要同时引 1.19.x**，否则版本冲突。
- 所有版本用 `exactVersion` 锁定；`Package.resolved` 由 Xcode 生成、随 `.xcodeproj` 忽略，不作为配置源。

**备选**：Kingfisher、KeychainAccess、Atributika、手写 CommonCrypto（均未采用）。

---

## ADR-006 不引 Alamofire / TCA / Kingfisher / KSPlayer

**状态**：Accepted（2026-11-17）

**决定**：
- 网络用 `URLSession`，不用 Alamofire/Moya。
- 状态用 `@Observable`，不用 TCA。
- 图片用 Nuke，不用 Kingfisher（二选一）。
- 播放用 AVPlayer/AVKit，不用 KSPlayer/FFmpeg。

**理由**：
- 信封是“POST 一个 JSON，里面再描述 method/path/body”的非标准协议，Alamofire 的 Router/Interceptor 反而多绕一层。
- TCA 对自用小 App 是过度设计。
- HLS + AES-128 AVPlayer 原生支持；FFmpeg 只在非 HLS 编码时才需要。
- 多引一个功能重叠的库只会增加体积和升级面。

**后果**：通用的 HTTP 重试/日志/进度要自己写少量代码；但都是可测的薄封装。

---

## ADR-007 导航：Tab 内 NavigationStack + fullScreenCover

**状态**：Accepted（2026-11-17）

**背景**：Web 版是“单栈盖在 Tab 上”；原生若照搬会出现返回错乱、Tab 状态丢失。

**决定**：
- `TabView` 四个 Tab，每个 Tab 一个独立 `NavigationStack(path: [Route])`。
- 播放器用根级 `.fullScreenCover(item: $app.feed)`。
- 登录 `.sheet`；选集/评论 `.sheet` + detents。

**后果**：
- 从任何 Tab 打开播放器，关闭后回到原 Tab 的栈与滚动位置。
- `Route` 只放可 push 的页面；播放器不进 `Route`。
- 跨 Tab 跳转（如首页顶部搜索）通过 `AppState` 切 Tab，不直接改另一个 Tab 的 path。

**备选**：单一 `NavigationPath` 塞所有页面（否决）；把播放器当 push 页面（TabBar 处理麻烦）。

---

## ADR-008 单 AVPlayer + UICollectionView pager

**状态**：Accepted（2026-11-17）

**背景**：竖滑 Feed 若每页一个 AVPlayer，会有内存、音频焦点、预加载、恢复进度四个问题。

**决定**：
- 整个 Feed 一个 `AVPlayer`；翻页 `replaceCurrentItem`。
- pager 用系统 `UICollectionView`（`UIViewControllerRepresentable` 包一层），不引第三方 pager。
- 非当前 cell 只显示封面；当前 cell 上叠 `AVPlayerLayer` 宿主。
- 只预加载下一条的 `AVURLAsset`。

**后果**：
- 翻页与播放解耦，进度字典由 `FeedViewModel` 管。
- 手势仲裁（翻页 vs 亮度/音量 vs 进度）要自己写，但这是本项目的核心体验，值得。
- 不引入 SwiftUIPager：它和自定义手势/播放层的适配成本高于收益。

**备选**：每 cell 一个 AVPlayer（否决）；SwiftUIPager（否决）；纯 SwiftUI ScrollView paging（M2 可评估，若性能不够再换 UICollectionView）。

---

## ADR-009 XcodeGen 管理工程

**状态**：Accepted（2026-11-17）

**决定**：`project.yml` 是唯一工程配置源；`.xcodeproj` 与其中的 `Package.resolved` 由 `xcodegen generate` 生成并 gitignore。

**理由**：
- 工程文件可 review、可脚本生成、AI 可直接改；避免手点 Xcode 产生不可见 diff。
- target/scheme/依赖/签名配置集中在一处。

**后果**：
- 新人/新机先 `xcodegen generate`。
- 改工程配置不要直接改 `.xcodeproj`；改 `project.yml` 后重新生成。

---

## ADR-010 自用分发，不追 App Store

**状态**：Accepted（2026-11-17）

**决定**：仅自用学习；免费 Apple ID 自签（7 天 provisioning）或付费账号；不做 App Store 上架、不做 TestFlight 公开分发。

**理由**：
- 第三方内容客户端上架有 5.2.x 授权风险；纯原生不改变这一点。
- 自用不需要审核、隐私清单、商店素材。

**后果**：
- 7 天到期需重装；文档中不写商店发布流程。
- 若未来要上架，需重新评估内容授权、隐私清单、审核风险，并新增 ADR。


---

## ADR-011 网络走系统代理，不做 App 级代理（v1）

**状态**：Accepted（2026-11-17）

**背景**：本机访问上游需要代理；Rust 版有 `HGHUB_PROXY` 和 `system-proxy`。原生端若自行实现代理，会增加配置、凭据和 HLS 适配成本。

**决定**：
- v1 不自建代理 UI/配置；`URLSession`/CFNetwork 自动读取系统代理。
- 模拟器复用 macOS 系统代理（当前 127.0.0.1:7890）。
- 真机在 Wi-Fi 设置里配 HTTP 代理指向 Mac 的局域网 IP。
- AVPlayer 的 HLS 是否走系统代理，M2 真机验证；不走则用 `AVAssetResourceLoaderDelegate`。
- 如果以后需要 App 级代理，再给 `URLSessionConfiguration` 设 `connectionProxyDictionary`，并单独评估 HLS。

**后果**：
- 用户需要自己开系统代理；App 内不做“代理开关”。
- 排查网络时不能用裸 `curl` 下结论（curl 不读系统代理）。
- 自检/UI 测试依赖系统代理，代理关闭时网络测试失败属环境问题。

**备选**：内置代理配置（v1 否决，增加复杂度）；本地转发代理（否决，等于重造 Tauri 的 `hg://` 层）。
