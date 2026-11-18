# 架构设计 · ios-native

> 版本：v0.1（M0 基线）
> 更新：2026-11-17
> 关联：[需求](requirements.md) · [开发计划](development-plan.md) · [接口契约](api-contract.md) · [ADR](decisions.md)

---

## 1. 一句话

**分层 MVVM（SwiftUI + Observation）+ Repository + 少量 Coordinator/Service，单向数据流。**
不引 TCA，不做 Clean 的 UseCase 层；业务规则薄，Repo 足够。UIKit 只用于两个“系统级”组件：竖滑分页（`UICollectionView`）与播放器（`AVPlayerLayer`/`AVKit`）。

## 2. 分层与依赖

```
┌──────────────────────────────────────────────┐
│ App（组合根）                                 │
│ HGHubApp · AppState · RootTabView · Route    │
│ AppDependencies（api/repo/session/library）   │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│ Features（MVVM，一屏一 VM）                   │
│ View ──▶ @Observable ViewModel ──▶ 协议       │
│ Home / Feed+Player / Search / Category       │
│ Profile / Settings / Posts / Auth            │
└──────────────────┬───────────────────────────┘
                   │ 只依赖协议
┌──────────────────▼───────────────────────────┐
│ Core（无页面逻辑）                            │
│ Repositories · APIClient(actor) · Session    │
│ LocalLibrary · LineStore · ImagePipeline     │
│ HTMLRenderer · Models                        │
└──────────────────┬───────────────────────────┘
                   │
        URLSession / AVPlayer / Nuke / Valet / Defaults
```

**依赖规则**：

1. App → Features → Core，反向不允许。
2. Features 之间不互相 import；跨 Feature 的动作走 `AppState`（如“打开播放器”“弹登录”）。
3. DesignSystem 不依赖任何业务层。
4. Core 不 import SwiftUI；只有 `Images`、`HTML` 允许 import UIKit（产物是 `UIImage` / `NSAttributedString`）。

> 先单 target + 目录约束；`Core` 变大后再拆本地 SPM 包，依赖方向已经按可拆方式设计。

## 3. 模块职责

| 模块 | 职责 | 不做什么 |
|---|---|---|
| `App/` | `HGHubApp` 入口、`AppState`（session/theme/feed/login/toast）、`RootTabView`、`Route`、`AppDependencies` 组装 | 业务请求、列表缓存 |
| `Features/Home` | 首页 Feed 的列表加载与分页 | 播放器实现 |
| `Features/Feed` | 全屏竖滑容器、`FeedViewModel`（详情/播放信息缓存）、`PlayerCoordinator`、播放控件、选集/评论 sheet | 直接拼信封 |
| `Features/Search` | 搜索、搜索历史、榜单 | 播放 |
| `Features/Category` | 频道列表与频道内列表 | 播放 |
| `Features/Profile` | 资料卡、收藏、历史 | 设置实现 |
| `Features/Settings` | 主题、线路入口、清缓存、诊断、更新 | 业务接口 |
| `Features/Posts` | 吃瓜列表与正文 | 视频播放（复用 Feed） |
| `Features/Auth` | 登录/注册表单与校验 | 会话持久化 |
| `Core/Networking` | `APIClient`（actor）、边缘信封、重试、错误映射 | 页面状态 |
| `Core/Repositories` | 按领域把 API 变成强类型方法；401/字段漂移兜底 | UI |
| `Core/Models` | Codable DTO | 业务逻辑 |
| `Core/Session` | token（Valet）+ 用户资料 | 登录表单 |
| `Core/Storage` | `LocalLibrary`（收藏/历史/关注/搜索历史）、`Defaults` keys | 服务端数据 |
| `Core/Lines` | 固定线路、镜像解析、探测、持久化 | 页面 |
| `Core/Images` | Nuke pipeline、封面 AES 解码器、图片请求头 | 页面布局 |
| `Core/HTML` | SwiftSoup 清洗 + ZMarkupParser 渲染 | 页面导航 |
| `DesignSystem` | 颜色/字体/间距/通用组件 | 业务 |

## 4. 状态管理

### 4.1 全局状态：`AppState`

只放四类跨屏状态：

```swift
@MainActor @Observable
final class AppState {
    var session: Session?          // 登录态
    var theme: Theme = .dark
    var feed: FeedContext?         // 全屏播放（nil 表示关闭）
    var loginPresented = false
    var toast: Toast?
}
```

**不放**：视频列表、搜索关键词、播放器进度、评论列表——这些属于 Feature 本地状态，避免一个巨型 Store。

### 4.2 Feature 状态：`@Observable` ViewModel

- 每个屏幕一个 VM，`@MainActor`，持有 `Phase`（idle/loading/loaded/failed）与数据。
- VM 依赖 **Repository 协议**，不依赖 `APIClient` 具体类型；测试可替换。
- 网络任务用 `Task` 持有，`onDisappear`/新请求时取消。

### 4.3 本地库：`LocalLibrary`

收藏、喜欢、关注、观看历史、搜索历史。`@Observable` + `Defaults` 持久化，注入到需要它的 VM。

- 观看历史最多 80 条，字段 `id, ep, t, dur, at`；同 id 置顶。
- 集数变化时进度归零；同集恢复秒数。
- 写回节流：播放中每 5s 一次 + 暂停/退出/切条时立即一次。

## 5. 数据流

### 5.1 首页加载

```
HomeView.onAppear
  → HomeViewModel.loadNext()
    → VideoRepository.feed(page:size:)
      → APIClient.get("/api/videos?page=…&size=…")
        → EdgeEnvelope → POST {base}/api/edge/request
      ← Paged<VideoCard>
    ← items / pagination
  → HomeViewModel.items 更新
HomeView 渲染 FeedScreen(ids, index)
```

### 5.2 播放一条视频

```
FeedScreen 当前页变化
  → FeedViewModel.onPageChanged(index)
    → 取缓存 detail / playInfo；没有则并发请求
      → VideoRepository.detail(id)     // /api/videos/{id}
      → VideoRepository.playback(id,ep) // 直连 playback
    → PlayerCoordinator.load(url: PlayInfo.videoUrl, headers: cdn)
      → AVPlayer.replaceCurrentItem
  ← PlayerState（time/duration/buffered/isPlaying/error）
PlayerOverlay 绑定 PlayerState
```

### 5.3 点赞

```
PlayerOverlay.onLike
  → 未登录 → AppState.loginPresented = true
  → 已登录 → FeedViewModel.toggleLike()
    → LocalLibrary 乐观更新（立即 UI）
    → VideoRepository.like(id, ep, on)
      成功：保持
      失败：回滚 + toast
```

### 5.4 401

```
APIClient 收到 401/403
  → throw APIError.unauthorized
Repository 原样抛出
ViewModel 捕获
  → AppState.handleUnauthorized()（幂等：清 session、弹登录、只弹一次）
```

### 5.5 切线路

```
Settings → LinePicker
  → LineRepository.setBase(url)（校验 http(s) + host）
    → APIClient.setBase(url)（actor 属性）
    → Defaults 持久化
  → 后续请求使用新 base；在途请求不串线
```

## 6. 导航模型

- `TabView` 四个 Tab：首页 / 搜索 / 分类 / 我的。
- **每个 Tab 一个独立 `NavigationStack(path: [Route])`**，切 Tab 保留各自栈。
- `Route` 只放可 push 的页面：

```swift
enum Route: Hashable {
    case channel(cate: String, name: String)
    case ranks
    case settings
    case posts
    case post(id: Int)
}
```

- **全屏播放器**：根视图 `.fullScreenCover(item: $app.feed)`，从任何 Tab 打开，天然盖住 TabBar；关闭回到原列表与滚动位置。
- **登录**：`.sheet`。
- **选集 / 评论**：`.sheet` + `.presentationDetents([.medium, .large])`。
- **不吃**：`NavigationLink` 隐式跳转、全局 `NavigationPath` 塞所有页面、把播放器当普通 push 页面。

## 7. 播放器架构（本项目最复杂的部分）

### 7.1 组件

| 组件 | 职责 |
|---|---|
| `FeedScreen` | SwiftUI 容器：pager + 播放层 + 控件 + sheets |
| `FeedViewModel` | 当前 index、详情/播放信息缓存、选集/评论数据、点赞收藏 |
| `FeedPager` | `UICollectionView` 竖滑分页（UIKit 桥接），只负责“当前第几条” |
| `PlayerCoordinator` | 单 `AVPlayer` 生命周期、item 预加载、进度/time observer、错误 |
| `PlayerState` | `@Observable`：time/duration/buffered/isPlaying/error/rate |
| `PlayerOverlay` | SwiftUI 控件：播放/暂停、进度条、选集、评论、倍速、静音、全屏、点赞 |
| `PlayerSurface` | `UIViewRepresentable` 包 `AVPlayerLayer`（或 `AVPlayerViewController`） |
| `EpisodesSheet` | 选集面板 |
| `CommentsSheet` | 评论面板 |

### 7.2 单播放器策略

- **整个 Feed 只创建一个 `AVPlayer`**；翻页时 `replaceCurrentItem`，不创建多个播放器。
- pager 的非当前 cell 只显示封面；当前条目的视频用固定的 `PlayerSurface` 叠在 pager 上方，`isUserInteractionEnabled=false`，切条时先隐藏，`readyToPlay` 后显示。
- 预加载只做下一条：`AVURLAsset.load(.isPlayable)`，最多 2 个 asset。
- 每个 `(videoID, ep)` 的播放进度存 `FeedViewModel` 字典；切回时 seek 恢复。

### 7.3 全屏

- 首选 `AVPlayerViewController`（系统控件 + PiP），自定义控件时用 `AVPlayerLayer` + `AVPictureInPictureController`。
- 退出全屏恢复 overlay；`PlayerCoordinator` 不重建。
- iPhone 不允许横屏（v1 竖屏），全屏仍是竖屏铺满。

### 7.4 系统能力

- 后台音频：`AVAudioSession .playback` + `MPRemoteCommandCenter` + Now Playing（P1）。
- PiP：`AVPictureInPictureController`（P1）。
- AirPlay：`AVRoutePickerView`（P1）。
- 锁屏控制：`MPRemoteCommandCenter`（P1）。

### 7.5 手势冲突

竖滑翻页 vs 上下滑亮度/音量 vs 横滑进度，三者必须有一套明确的仲裁：

1. 横向位移 > 纵向位移 → 进度拖动，pager 不翻页。
2. 纵向滑动起点在屏幕左/右边缘 20% → 亮度/音量，pager 不翻页。
3. 其余纵向滑动 → pager 翻页。
4. 单击暂停；双击点赞；长按 2x（松手恢复）。

M2 初版实现：横向 `|vx| > 1.15|vy|`、左右边缘各 20% 才进入亮度/音量、长按 0.4s；专用 `UIPanGestureRecognizer` 通过 `collectionView.panGestureRecognizer.require(toFail:)` 先决定方向，中心纵向失败后交给 pager。阈值仍需真机继续调，后续修改同步到本节。

### 7.6 详情 / 互动 / 评论（M3）

- 模型：`VideoDetail`（详情 + episodes + counts + interaction）、`Comment` / `CommentPage`、`LoginResponse`。
- 仓库：`AccountRepository`（login/logout/me）、`VideoSocialRepository`（detail/comments/sendComment/like/collect/follow）；`APIClient` 增加 typed post 与“只关心 status”的 action。
- 共享状态：`FeedInteractionModel` 同时服务 Feed overlay 与详情面板，避免两处点赞/收藏状态分叉；乐观更新 + 失败回滚；未登录先弹登录，不预发请求；401 由 `AppDependencies.handleUnauthorized` 统一清 Keychain/token 并弹登录。
- 评论：`CommentsViewModel` 分页/去重；`CommentsSheet` 半屏/全屏、底部输入框用 `safeAreaInset` 避开键盘；发送成功 toast「审核通过后展示」并重拉第 1 页；楼中楼当前只展示首条。
- 分享：详情面板用系统 `ShareLink`，链接为 `{base}/video/{id}/`。
- 登录：`LoginSheet` 调真实 `loginByPassword`，token 写 Valet 并注入 `APIClient`；退出即使接口失败也清本地。

### 7.7 搜索 / 分类 / 榜单（M4）

- `VideoDiscoveryRepository`：`search`、`category`、`ranks`，由 `APIClient` 走信封。
- `SearchViewModel`：空词不请求，提交时写 `LocalLibrary.searchHistory`；分页/去重/错误态；结果进 `FeedContext(source: "search", query:)`。
- `CategoryViewModel`：4 个频道并发首屏（每频道 8 条），0 条频道隐藏；`ChannelViewModel` 负责频道内分页。
- `RankViewModel`：hot/recommend/potential，前 20，不翻页；`RankItem` 单独解码 `video_id`。
- `FeedContext` 增加 `source/query/cate`；`FeedViewModel` 按来源继续请求 search/category 下一页，避免从搜索/频道进入 Feed 后错拉首页。
- 列表入口统一调 `AppState.presentFeed(...)`，统一带续播历史。

### 7.8 我的 / 设置 / 线路（M5）

- `LibraryViewModel`：用 `VideoDetail` 回填收藏与最近 30 条历史；点击统一 `AppState.presentFeed`，按历史集/秒续播。
- 设置：`MaintenanceService` 提供清缓存（Nuke + `URLCache`）、诊断、更新检查；`LiveMaintenanceService` 走系统代理。
- 诊断：`getaddrinfo` 解析 DNS，`CFNetworkCopySystemProxySettings` 读 HTTP 代理，`URLSession` 请求当前 base。
- 线路：`LineService` 拉 `huangguoai.pages.dev` → `publish.js`，解析 `var urls` × `var subdomains`；探测 6 并发、8s 超时；切换同时更新 `LineStore` 持久化与 `APIClient` base。
- 更新：GitHub Release 数字段比较，只展示不自动安装；404 视为无 Release。
- 缓存清理不清登录/收藏/历史。

### 7.9 吃瓜 Posts（M6）

- `PostRepository`：列表、详情、评论、发评论、点赞、收藏；`Post` 模型兼容列表/详情可选字段。
- `PostsViewModel`：2 列卡片、分页/去重/错误态；入口在分类页「黄果吃瓜」。
- `PostDetailViewModel`：详情 + 乐观点赞/收藏；`PostCommentsViewModel` 分页/发送。
- `HTMLSanitizer`（SwiftSoup）+ `PostHTMLRenderer`（ZMarkupParser）+ `HTMLContentView`（UITextView）；去脚本/事件/`javascript:`，补全 URL，`data-src` 回填。
- 登录拦截与 401 复用 M3 规则；帖子互动未落本地。

## 8. 网络层

### 8.1 APIClient

```swift
actor APIClient {
    private var base: URL
    private var token: String?
    private let session: URLSession

    func setBase(_ url: URL)
    func setToken(_ token: String?)

    func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T
    func post<T: Decodable>(_ path: String, body: some Encodable, as: T.Type) async throws -> T
    func playback(id: Int, ep: Int) async throws -> PlayInfo
}
```

- `get/post` 走边缘信封：`method/path/body(base64)/content_type` + `Referer` + `Bearer`。
- `playback` 直连：`POST {base}/api/videos/{id}/episodes/{ep}/playback`，body `{}`，不走信封。
- 重试：网络错误/超时最多 3 次，350ms 递增；401/403、业务错误不重试。
- 解码：`JSONDecoder` + `convertFromSnakeCase`；字段缺失用可选/默认值兜底。
- 错误：`APIError { network, timeout, unauthorized, http(Int), business(String), decoding }`。

### 8.2 为什么不用 Alamofire / Moya

信封不是标准 REST：真实 method/path/body 都塞进一个 POST 的 JSON 里，`status==1` 再解包。Alamofire 的收益只有重试/拦截器；Moya 的 target 抽象更不贴合“单入口”。URLSession 是系统轮子，手写的只是 30 行信封拼装，属于业务协议，不是通用能力。

### 8.3 代理

- v1 不自建代理配置：`URLSession`/CFNetwork 自动读取系统代理。
- 模拟器复用 macOS 系统代理；真机在 Wi-Fi 设置里指向 Mac 的局域网 IP:7890。
- `curl` 不读系统代理，排查时必须显式 `-x`；详见 [接口契约 § 11](api-contract.md#11-代理与网络排查)。
- AVPlayer 的 HLS 请求是否走系统代理，M2 真机验证；必要时用 `AVAssetResourceLoaderDelegate`。
- 若未来要 App 级代理，给 `URLSessionConfiguration` 设 `connectionProxyDictionary`；HLS 仍需系统代理/resource loader。

### 8.4 鉴权与线路注入

`APIClient` 是 actor，token/base 用 actor 属性；`SessionStore`、`LineStore` 在登录/切线路时调用 `setToken`/`setBase`，避免跨 actor 读 `@MainActor` 状态。

## 9. 媒体层

### 9.1 封面（Nuke）

- `CoverImageDecoder: ImageDecoding`：先判 magic（JPEG/PNG/GIF/WebP），不是已知图片则 AES-128-CBC 解密 + 去 PKCS#7，再交给 `ImageDecoders.Default`。
- `ImagePipeline.Configuration.withDataCache(name:sizeLimit:)` + `config.makeImageDecoder = { _ in CoverImageDecoder() }`。
- 需要 Referer 的图用 `ImageRequest(urlRequest:)` 注入头；`LazyImage(request:)` 使用。
- 磁盘缓存存密文，内存缓存存解码图；滚动不重复解密。

### 9.2 HLS

- **原生直连** `PlayInfo.videoUrl`；不重写 m3u8、不做本地代理。
- AVPlayer 原生支持 AES-128 HLS。
- 若 CDN 校验 UA/Referer：用 `AVAssetResourceLoaderDelegate` + 自定义 scheme 注入 header；`cdn.authKey/authValue` 映射为 header。不要依赖私有 KVC 作为主方案。

### 9.3 正文 HTML

- SwiftSoup 清洗：去 `script/style/iframe`、事件属性、`javascript:`；`data-src` 回填；相对地址补全；删 `srcset`。
- ZMarkupParser 渲染成 `NSAttributedString`；正文图片使用默认 `ZNSTextAttachment` + URLSession（走系统代理）加载，封面仍走 Nuke。
- 用不可滚动的 `UITextView`（`UIViewRepresentable`）承载，链接走 `UITextViewDelegate`。
- M6 实现：清洗与渲染在详情加载后执行；`HTMLContentView` 用不可滚动 UITextView 自适应高度。点击大图（P2）与渲染缓存留后续。

## 10. 持久化

| 数据 | 存储 | 说明 |
|---|---|---|
| token | **Valet**（Keychain） | 不写 UserDefaults、不写日志 |
| 用户资料 | `Defaults`（Codable） | 冷启动先展示缓存，再刷新 |
| 主题 / 静音 / 音量 | `Defaults` | 立即写 |
| 收藏 / 喜欢 / 关注 | `Defaults`（`[Int]`） | 本地优先，登录后与服务端对齐 |
| 观看历史 | `Defaults`（`[WatchProgress]`） | 80 条上限，节流写 |
| 搜索历史 | `Defaults`（`[String]`） | 12 条上限 |
| 线路 base | `Defaults` | 启动时注入 APIClient |
| 图片 | Nuke 磁盘缓存 | 上限 200MB |
| 接口响应 | 不落盘 | 内存缓存按需（详情 5 分钟） |

不引 SwiftData/Core Data：数据量小、结构简单，`Defaults` + Codable 足够；以后要查询再迁。

## 11. 并发模型

- `APIClient`：actor。
- ViewModel / AppState / PlayerCoordinator：`@MainActor @Observable`。
- DTO：`Sendable`；Repository 协议方法 `async throws`。
- 每个 ViewModel 持有 `Task`，`onDisappear`/重新搜索时 `cancel()`；`Task.checkCancellation()`。
- 线路探测用 `withTaskGroup`，最多 6 并发。
- 不用 Combine；AVPlayer 时间观察用 `addPeriodicTimeObserver`，回调切 MainActor 更新 `PlayerState`。
- 不用全局事件总线；跨屏动作走 `AppState` 的显式方法。

## 12. 错误处理与可观测性

- `APIError` 在 Repository 层归一化；ViewModel 只认 `APIError`，UI 文案集中在一个 `ErrorText` 映射。
- 401：`AppState.handleUnauthorized()` 幂等处理。
- 播放错误：`AVPlayerItem.error` / `errorLog()` → `PlayerState.error` → overlay 显示，不无限转圈。
- Debug：Pulse 挂 URLSession，可看 API 请求；播放问题看 `AVPlayerItem.errorLog()`（Pulse 看不到 AVPlayer 的 HLS 请求）。
- 网络诊断：DNS、系统代理、连通性快照；可复制给维护者。

## 13. 目录结构

```
HGHub/
├─ App/
│  ├─ HGHubApp.swift
│  ├─ AppState.swift
│  ├─ AppDependencies.swift
│  ├─ RootTabView.swift
│  ├─ Route.swift
│  └─ ToastCenter.swift
├─ Core/
│  ├─ Networking/      # APIClient, EdgeEnvelope, APIError, Retry
│  ├─ Models/          # VideoCard, Paged, Detail, PlayInfo, Comment, Post, User
│  ├─ Repositories/    # Video/Post/Account/Line Repository
│  ├─ Session/         # SessionStore
│  ├─ Storage/         # Defaults keys, LocalLibrary, WatchProgress
│  ├─ Lines/           # LineStore, MirrorParser, LineProbe
│  ├─ Images/          # ImagePipeline, CoverImageDecoder, ImageBytes
│  └─ HTML/            # HTMLSanitizer, HTMLRenderer
├─ Features/
│  ├─ Home/            # HomeView, HomeViewModel
│  ├─ Feed/            # FeedScreen, FeedViewModel, FeedPager
│  │  └─ Player/       # PlayerCoordinator, PlayerState, PlayerSurface, PlayerOverlay
│  ├─ Search/          # SearchView, RankView
│  ├─ Category/        # CategoryView, ChannelView
│  ├─ Profile/
│  ├─ Settings/
│  ├─ Posts/
│  └─ Auth/
├─ DesignSystem/
└─ Resources/
```

## 14. 测试策略

| 层 | 方式 | 说明 |
|---|---|---|
| `APIClient` | `URLProtocol` stub + fixtures | 信封构造、`status==1` 解包、401、重试 |
| Models | 真实 JSON fixtures | 字段缺失/类型漂移 |
| Repositories | 注入 stub client | 路径、参数、异常映射 |
| ViewModels | 注入 fake repository | 分页、去重、错误态、取消 |
| 播放器 | 手动/集成 | AVPlayer 不适合单测；用真实 m3u8 冒烟 |
| UI | Xcode Previews + 手动 | SnapshotTesting 暂缓（依赖冲突） |

fixtures 放 `HGHubTests/Fixtures/*.json`，来源是真实请求的脱敏副本；**不提交 token、手机号、Cookie**。

## 15. 演进边界

- **现在**：单 target、MVVM + Repository。
- **变复杂时**：`Core` 拆本地 SPM 包；`Feed` 抽 `PlaybackUseCase`（续播 + 线路回退 + 预加载）；`Settings` 抽 `LineService`。
- **什么时候上 TCA**：多人协作、状态机复杂到需要可回放 action。本项目大概率不会到。
- **什么时候引 SwiftData**：需要按条件查询/迁移大量历史数据时。

## 16. ADR 索引

| ID | 决策 | 文档 |
|---|---|---|
| ADR-001 | 原生工程与 Tauri 四端并存 | [decisions.md#adr-001](decisions.md#adr-001) |
| ADR-002 | Swift 重写，不复用 Rust 内核 | [decisions.md#adr-002](decisions.md#adr-002) |
| ADR-003 | 最低 iOS 17.0 | [decisions.md#adr-003](decisions.md#adr-003) |
| ADR-004 | 分层 MVVM + Repository | [decisions.md#adr-004](decisions.md#adr-004) |
| ADR-005 | 三方库清单 | [decisions.md#adr-005](decisions.md#adr-005) |
| ADR-006 | 不引 Alamofire/TCA/Kingfisher/KSPlayer | [decisions.md#adr-006](decisions.md#adr-006) |
| ADR-007 | 导航：Tab 内 NavigationStack + fullScreenCover | [decisions.md#adr-007](decisions.md#adr-007) |
| ADR-008 | 单 AVPlayer + UICollectionView pager | [decisions.md#adr-008](decisions.md#adr-008) |
| ADR-009 | XcodeGen 管理工程 | [decisions.md#adr-009](decisions.md#adr-009) |
| ADR-010 | 自用分发，不追 App Store | [decisions.md#adr-010](decisions.md#adr-010) |
| ADR-011 | 网络走系统代理，不做 App 级代理（v1） | [decisions.md#adr-011](decisions.md#adr-011) |
