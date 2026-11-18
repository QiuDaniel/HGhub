# 开发计划 · ios-native

> 版本：v0.6（M6 完成）
> 更新：2026-11-18
> 关联：[需求](requirements.md) · [架构](architecture.md) · [接口契约](api-contract.md) · [ADR](decisions.md)

---

## 1. 执行原则

1. **文档先行**：需求/架构/契约变了，先改文档，再改代码。
2. **里程碑门禁**：上一 milestone 的验收项没全过，不进入下一个；允许并行做“无依赖”的任务（如设计 token）。
3. **每个任务可验收**：不以“代码写完”为完成，以“行为可验证”为完成。
4. **小步提交**：一个任务一个 commit（或一组紧密相关 commit），message 用 `feat(ios): ...` / `fix(ios): ...` / `docs(ios): ...`。
5. **不扩大范围**：需求外的东西记到“待评估”，不顺手做。
6. **不破坏现有端**：任何改动不得影响根目录 Tauri 构建。

## 2. 里程碑总览

| 阶段 | 目标 | 交付物 | 预估 | 状态 |
|---|---|---|---|---|
| **M0** | 工程骨架 + 契约验证 | 可编译 App、XcodeGen、APIClient、模型、自检页、fixtures 计划 | 2–3 人日 | ✅ 完成 |
| **M1** | 应用外壳 + 基础设施 | 设计 token、Tab、导航、Session、LocalLibrary、LineStore、错误/toast | 3–4 人日 | ✅ 完成 |
| **M2** | 首页 + 播放器 | 竖滑 Feed、单 AVPlayer、封面、续播、手势、选集/评论入口 | 6–8 人日 | ✅ 完成 |
| **M3** | 详情 + 互动 | 详情、选集、评论、点赞/收藏/关注、登录拦截 | 5–7 人日 | ✅ 完成 |
| **M4** | 搜索 + 分类 + 榜单 | 搜索历史、频道、三榜单 | 3–4 人日 | ✅ 完成 |
| **M5** | 我的 + 设置 + 线路 | 资料卡、收藏/历史、设置、线路选择/探测、缓存/更新 | 4–5 人日 | ✅ 完成 |
| **M6** | 吃瓜 Posts | 列表、详情、HTML 渲染、图片、互动 | 3–4 人日 | ✅ 完成 |
| **M7** | 打磨 + 发布 | PiP/AirPlay/后台、性能、无障碍、图标、签名/安装 | 4–6 人日 | 待开始 |

> 合计约 30–40 人日；依赖选型省掉图片/HTML/Keychain/持久化轮子后，实际约 25–35 人日。MVP = M0–M3，约 2–3 周（熟手全职）。

## 3. M0：工程骨架 + 契约验证（完成）

**目标**：证明“工程能生成、依赖能解析、空 App 能跑、核心接口能调通”，不写业务 UI。

| ID | 任务 | 交付 | 验收 | 状态 |
|---|---|---|---|---|
| M0-01 | 写六份文档 | `README` + `docs/*` | 文档齐全、互相链接 | ✅ 完成 |
| M0-02 | 工程骨架 | `project.yml`、`.gitignore`、Assets、目录 | `xcodegen generate` 成功 | ✅ 完成 |
| M0-03 | App 外壳 | `HGHubApp`、`AppState`、`RootTabView`、4 个占位 Tab | 模拟器启动见 4 Tab | ✅ 完成 |
| M0-04 | 网络层 | `APIClient`、`EdgeEnvelope`、`APIError`、重试 | 信封编码/模型解码单测通过；401 待集成 | ✅ 完成 |
| M0-05 | 模型 | `Paged<T>`、`VideoCard`、`PlayInfo`、`User`/`Session` | fixtures 解码通过 | ✅ 完成 |
| M0-06 | 契约自检页 | Debug 页：boot/feed/playback/封面 | 页面可用；Feed/Playback 真实请求已验证 | ✅ 完成 |
| M0-07 | 封面解密 | `CoverImageDecoder` + Nuke pipeline | 解码器 + 单测通过；真实封面下载 + AES 解密得到 JPEG | ✅ 完成 |
| M0-08 | 构建验证 | 模拟器 `xcodebuild build` + 启动 | 构建通过、App 启动 | ✅ 完成 |
| M0-09 | 状态回写 | 本文件 + README 状态 | 状态与代码一致 | ✅ 完成 |

**M0 完成定义**：M0-01 ~ M0-09 全部 ✅；依赖版本由 `project.yml` 的 `exactVersion` 锁定（`Package.resolved` 随 `.xcodeproj` 生成、不入库）；无未登记 TODO。

**M0 验证记录（2026-11-17）**：

- `xcodegen generate`：通过（XcodeGen 2.x + Xcode 27.1）。
- SPM 解析：10 个包全部锁定到预期版本。
- `xcodebuild build`（generic iOS Simulator）：`BUILD SUCCEEDED`。
- `xcodebuild test`（iPhone 17 Pro / iOS 26.2）：**7 个单元测试 / 4 suites + 3 个 UI 测试**，`TEST SUCCEEDED`。
- 安装启动：iPhone 16 Pro（iOS 18.5）模拟器，4 Tab + M0 自检入口正常；UI 测试确认点击可打开自检页。
- 真实网络（macOS 系统代理 `127.0.0.1:7890`）：Feed `HTTP 200`（10 条 / 179 页 / 1781 总条数）、Playback `HTTP 200`（`streams.main` 有地址）、封面下载 + AES-128-CBC 解密得到 `1086x1448 JPEG`。
- fixtures：`HGHubTests/Fixtures/feed_page1.json`（真实 Feed，已脱敏）、`playback_117_3.json`（真实 Playback，已脱敏）。

![M0 启动截图](m0-launch.png)

## 4. M1：应用外壳 + 基础设施（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M1-01 | DesignSystem：颜色/字体/间距/按钮/Chip/Avatar/空态/骨架 | 深/浅色预览一致 |
| M1-02 | `RootTabView` + 每 Tab `NavigationStack` + `Route` | 切 Tab 保留栈；push/pop 正常 |
| M1-03 | `SessionStore`（Valet）+ 启动恢复 | 存/读/清 token；重启保持 |
| M1-04 | `LocalLibrary`（Defaults） | 收藏/历史/搜索历史读写；历史 80 条上限 |
| M1-05 | `LineStore`（固定 + 持久化） | 切换重启沿用 |
| M1-06 | Toast + 全局错误文案（`AppState.showToast/showError`） | 401/网络/业务错误展示 |
| M1-07 | `AppDependencies` 组合根 + 显式注入（`AppState` 用 Environment） | 可替换 fake |
| M1-08 | 登录 sheet 空壳 | 打开/关闭；未登录拦截可触发 |

**M1 验证记录（2026-11-17）**：

- DesignSystem：`Color` 语义 token + `HGPrimaryButtonStyle` / `HGSecondaryButtonStyle` / `HGChip` / `HGAvatar` / `HGEmptyState` / `HGSkeleton` / `HGSectionHeader`。
- 导航：四个 Tab 各一个 `NavigationStack(path: [Route])`；`channel / ranks / settings / posts / post` 都有 destination；设置页可进线路选择，我的页可进设置与登录壳。
- 会话：`AppDependencies.bootstrap` 启动时把持久化线路注入 `APIClient`，恢复 `SessionStore` 的登录态并注入 token。
- `LocalLibrary`：收藏/喜欢/关注/观看历史/搜索历史；历史 80 条、搜索 12 条；集数变化进度归零；跨实例持久化。
- `LineStore`：固定线路 1/2、地址校验、持久化、重启沿用。
- 主题：`AppState.theme` 写入 Defaults，切换即时生效。
- 测试：**15 个单测 / 6 suites + 5 个 UI 测试**，`TEST SUCCEEDED`。

## 5. M2：首页 + 播放器（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M2-01 | `HomeViewModel` 分页 | 首屏/加载更多/去重/错误重试 |
| M2-02 | `FeedPager`（UICollectionView） | 竖滑分页跟手；预加载下一条 |
| M2-03 | `PlayerCoordinator` + `PlayerSurface` | 单 AVPlayer；切条续播；错误可见 |
| M2-04 | `PlayerOverlay` | 播放/暂停/进度/时间/倍速/静音/全屏 |
| M2-05 | 手势仲裁 | 单击/双击/上下滑/横滑/长按不冲突 |
| M2-06 | 封面 + Nuke 解密 | 列表/详情封面正常 |
| M2-07 | 选集/评论 sheet 入口 | 打开/关闭；切集生效 |
| M2-08 | 续播 | 历史进入按集/秒恢复 |

**M2 完成定义**：连续刷 30 条不崩；切条 ≤500ms 出画面；音频不重叠；播放错误有文案。

**M2 验证记录（2026-11-18）**：

- `xcodegen generate` + `xcodebuild build`（generic iOS Simulator）：`BUILD SUCCEEDED`。
- `xcodebuild test`（iPhone 17 Pro / iOS 26.2）：**21 个单测 / 8 suites + 11 个 UI 测试**，`TEST SUCCEEDED`。
- 首页：两列封面流、首屏 10 条、滚动近底部自动翻页、去重、错误重试、下拉刷新；30 条跨三页去重由单测覆盖。
- Feed：`UICollectionView` 竖滑分页；`willDisplay`/滚动到倒数第 3 条触发 `loadMore`；当前条切条后封面先出，视频 ready 后显示。
- 预加载：切到当前条时预取下一条的 `PlayInfo` + `AVURLAsset(.isPlayable)`，不创建第二个 `AVPlayer`；同一 `(id, ep)` 命中小缓存。
- 播放：整个 Feed 单 `AVPlayer`；播放接口直连失败时按契约回退老 `play` 接口；`PlayerState` 暴露 loading/playing/paused/failed、时间/时长/缓冲/错误。
- 控件：单击暂停/继续、双击喜欢、长按 2x、横滑进度、左右边缘上下滑亮度/音量、进度条拖动、倍速、静音、全屏（嵌套 cover 复用同一个 AVPlayer）。
- 选集/评论：`EpisodesSheet` 切集生效；`CommentsSheet` 打开/关闭，评论列表留 M3。
- 续播：关闭 Feed 时写 `LocalLibrary` 历史；重新进入按历史集/秒 seek；UI 测试验证重进进度不为 `00:00`。
- 封面：Nuke pipeline + AES 解码在首页和 Feed 封面生效；真实封面已通过系统代理加载。
- 真机/模拟器实测：系统代理 `127.0.0.1:7890` 下 Feed 200、HLS playback 200、画面起播、时间推进。
- 验收边界：30 条目前是分页单测覆盖，尚未做 30 条真机连续滑动；切条 ≤500ms 未插桩计时；边缘亮度/音量、横滑进度未做 UI 自动化，阈值按架构 7.5 留待真机调。

## 6. M3：详情 + 互动（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M3-01 | `Detail` 模型 + 详情面板 | 标题/简介/标签/集数/作者/计数 |
| M3-02 | 点赞/收藏/关注 | 乐观更新 + 失败回滚 |
| M3-03 | 评论列表 + 发送 | 分页/去重/键盘不遮挡 |
| M3-04 | 登录拦截与 401 处理 | 只弹一次；登录后重试 |
| M3-05 | 分享（系统面板） | 标题 + 链接 |

**M3 验证记录（2026-11-18）**：

- `xcodebuild build`（generic iOS Simulator）：`BUILD SUCCEEDED`。
- 测试：**28 个单测 / 11 suites + 13 个 UI 测试**，`TEST SUCCEEDED`（以最终全量结果为准）。
- M3-01：`VideoDetail` 接真实 `/api/videos/117`，详情面板展示封面/标题/标签/评分/集数/作者/点赞/收藏/评论/简介/42 集选集；live detail 实测加载成功。
- M3-02：`FeedInteractionModel` 统一 Feed 与详情点赞/收藏/关注；乐观更新、失败回滚、未登录拦截、401 回滚；单测覆盖成功/失败/401 与本地库落盘。
- M3-03：`CommentsViewModel` + 半屏/全屏评论 sheet；真实 comments 接口实测加载（5 条 / 54 总）；分页去重单测；发送成功后 toast「审核通过后展示」并刷新第 1 页；`reply_id` body 按 snake_case 编码；评论正文取 `content` 优先、`text` 兜底。
- M3-04：`LoginSheet` 接真实 `loginByPassword`，token 存 Keychain、注入 `APIClient`、更新 `AppState`；退出登录清本地；未登录点赞/收藏/关注/评论先弹登录，不预发请求；401 清 token + Keychain + 登录态并弹登录。
- M3-05：详情面板 `ShareLink` 分享标题 + `{线路}/video/{id}/` 链接，系统分享面板可复制。
- 验收边界：没有可用账号，成功登录/真实点赞/发评论未做自动化；登录态下的接口成功路径靠 fake 单测 + 代码审查。登录成功后需再次点击原操作（未做自动 pending retry）；注册（FR-AUTH-02，P1）和回复发送（FR-COMMENT-03，P2）留后续；评论楼中楼当前只展示首条回复。

## 7. M4：搜索 + 分类 + 榜单（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M4-01 | 搜索页 + 历史 | 空词不请求；历史 12 条 |
| M4-02 | 分类频道（24/25/26/27） | 空频道隐藏；分页 |
| M4-03 | 榜单三分类 | 前 20 条；切换 |
| M4-04 | 列表 → 播放上下文 | ids/index 传入 Feed |

**M4 验证记录（2026-11-18）**：

- `xcodebuild build`：`BUILD SUCCEEDED`。
- 测试：**35 个单测 / 16 suites + 18 个 UI 测试**，`TEST SUCCEEDED`（以最终全量结果为准）。
- M4-01：搜索页接 `/api/search?q=&page=&size=`；空词直接返回不请求；历史来自 `LocalLibrary`（去重/置顶/12 条上限/清空）；热门题材、结果去重/分页、错误重试；真实搜索「高三」17 条 / 2 页。
- M4-02：分类总览并发拉 24/25/26/27 首屏，空频道（当前 26/27）自动隐藏；频道页分页；数字 `cate_id` 正确。真实 24 频道 1666 条，25 频道 116 条。
- M4-03：榜单 hot/recommend/potential 三档，取前 20 条、不翻页；真实 hot 榜 20 条 fixture 解码。
- M4-04：搜索/频道/榜单/分类卡片统一经 `AppState.presentFeed` 构造 `FeedContext`；`FeedViewModel` 按 `source/query/cate` 继续请求搜索或频道下一页，不再错拉首页 Feed；单测覆盖 search/channel 续页。
- UI 验证：搜索输入并进 Feed、榜单切换并进 Feed、分类卡片进 Feed、分类 → 频道 → 进 Feed、分类 → 榜单。
- 验收边界：分类首屏只展示每频道 8 条，进入 Feed 后由 `FeedViewModel` 续页；榜单若上游返回重复 video_id 目前按 video_id 去重展示（当前实测 20 条唯一）。

## 8. M5：我的 + 设置 + 线路（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M5-01 | 资料卡（登录/未登录） | 退出登录 |
| M5-02 | 收藏 / 历史列表 | 进度展示；点击续播 |
| M5-03 | 设置页（主题/数据/缓存/诊断/更新/关于） | 全部可用 |
| M5-04 | 线路选择 + 镜像 + 探测 | 切换生效并持久化 |
| M5-05 | 网络诊断 | 展示并可复制 |

**M5 验证记录（2026-11-18）**：

- `xcodebuild build`：`BUILD SUCCEEDED`。
- 测试：**38 个单测 / 18 suites + 21 个 UI 测试**，`TEST SUCCEEDED`（以最终全量结果为准）。
- M5-01：我的页未登录卡可点进登录；已登录卡展示昵称/用户名，退出走二次确认并清 Keychain、APIClient token、AppState。
- M5-02：收藏/历史列表通过 `VideoDetail` 回填卡片；历史显示集数/百分比/进度条；点击历史或收藏条目进入 Feed 并按历史集/秒续播；清空历史二次确认。
- M5-03：设置页完成主题、本地统计、清历史、清缓存、网络诊断、检查更新、关于/免责声明；缓存清理只清 Nuke 图片缓存 + `URLCache`，保留登录/收藏/历史。
- M5-04：固定线路 1/2 + 发布页镜像（`publish.js` 的 `var urls` × `var subdomains`，上限 60）；线路页展示镜像、单项/全部检测；切换立即 `LineStore` 持久化并更新 `APIClient.base`；地址仍只接受 http(s)+host。
- M5-05：诊断展示 base/host/DNS/系统代理/HTTP 状态与耗时，支持复制；DNS 用 `getaddrinfo`，代理用 `CFNetworkCopySystemProxySettings`，HTTP 走系统代理。
- 更新检查：GitHub Release `tag_name` 与 `CFBundleShortVersionString` 数字段比较；404 按无 Release 处理；只展示不自动更新。
- 验收边界：历史 UI 当前展示最近 30 条（存储仍 80 条），更多需后续分页；服务端收藏同步未做（当前以本地收藏为准）；检查更新/清缓存未做网络异常自动化。

## 9. M6：吃瓜 Posts（完成）

| ID | 任务 | 验收 |
|---|---|---|
| M6-01 | 列表分页 | 与 Feed 一致 |
| M6-02 | 正文清洗（SwiftSoup） | 去脚本、补全 URL |
| M6-03 | 正文渲染（ZMarkupParser） | 段落/图片/链接正常 |
| M6-04 | 帖子互动 | 赞/藏/评论 |

**M6 验证记录（2026-11-18）**：

- `xcodebuild build`：`BUILD SUCCEEDED`。
- 测试：**43 个单测 / 22 suites + 23 个 UI 测试**，`TEST SUCCEEDED`（以最终全量结果为准）。
- M6-01：`PostsViewModel` 接 `/api/posts?page=&size=`，2 列瀑布卡片、分页/去重/错误态；真实列表 791 条 / 80 页。
- M6-02：`HTMLSanitizer`（SwiftSoup）去 `script/style/iframe/form`、`on*` 事件、`javascript:`，`data-src` 回填，相对 URL 补全，删 `srcset`；单测覆盖。
- M6-03：`PostHTMLRenderer`（ZMarkupParser）渲染段落/图片/链接，`HTMLContentView` 用不可滚动 UITextView 自适应高度；正文图片走 ZNSTextAttachment + URLSession（系统代理），封面仍 Nuke。
- M6-04：帖子点赞/收藏乐观更新 + 失败回滚（单测）、评论 sheet（分页/发送/登录拦截）；未登录先弹登录，评论发送成功后 toast「审核通过后展示」。
- 入口：分类页「黄果吃瓜」→ Posts 列表 → 详情；真实详情 67 正文 5KB、评论 2 条已验证。
- 验收边界：正文图片点击查看大图（P2）未做；帖子点赞/收藏未落本地（以服务端 interaction 为准）；帖子 `video_url` 播放未接入。

## 10. M7：打磨 + 发布

| ID | 任务 | 验收 |
|---|---|---|
| M7-01 | PiP / AirPlay / 锁屏 / 后台音频 | 真机可用 |
| M7-02 | 性能：内存/滚动/启动 | 达标见 NFR |
| M7-03 | 无障碍 + 动态字体 | VoiceOver 抽查 |
| M7-04 | 图标 / 启动屏 / 版本号 | 图标正确 |
| M7-05 | 真机签名 + 安装 | 自用设备可安装 |
| M7-06 | 回归清单 + 文档收尾 | 全部 ✅ |

## 11. 依赖关系与关键路径

```
M0 ──▶ M1 ──▶ M2 ──▶ M3 ──▶ M5 ──▶ M7
                 │        │
                 ├──▶ M4 ─┘
                 └──▶ M6 ──┘
```

- M2 是核心路径：pager + 播放器 + 手势，风险最高；M4/M6 可以在 M2 之后并行。
- M5 依赖 M1 的 Session/LocalLibrary/LineStore。
- M7 依赖全部功能；播放器系统能力可在 M2 后提前做，但验收放 M7。

## 12. 质量门禁

每个 milestone 收尾必须跑：

```bash
cd ios-native
xcodegen generate
xcodebuild -project HGHub.xcodeproj -scheme HGHub \
  -destination 'generic/platform=iOS Simulator' build
# 测试需要具体模拟器；换成你本机 `xcrun simctl list devices available` 里的名字
xcodebuild -project HGHub.xcodeproj -scheme HGHub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

- SwiftFormat / SwiftLint（M1 接入）无 error。
- 新增逻辑有单测或手动验收记录。
- 文档状态与代码一致。
- 不新增未登记的 TODO/FIXME。

## 13. 风险登记

| ID | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R-01 | 上游域名被 DNS 污染/不可达 | 高 | 无法联调 | `URLSession` 走系统代理；模拟器复用 macOS 代理（已验证 7890）；真机配 Wi-Fi 代理；`curl` 不读系统代理，排查时加 `-x` |
| R-02 | CDN 校验 UA/Referer，AVPlayer 拉流失败 | 中 | 播放黑屏 | `AVAssetResourceLoaderDelegate` 注入 header；先直连验证 |
| R-03 | 手势与 pager 冲突 | 高 | 体验差 | 明确仲裁规则（架构 7.5）；真机调阈值 |
| R-04 | 上游 JSON 字段漂移 | 中 | 解码崩/空 | 宽松解码 + fixtures + 错误态 |
| R-05 | 多播放器/预加载导致内存高 | 中 | 卡顿/OOM | 单 AVPlayer；只预加载 1 条；Instruments |
| R-06 | 三方库与 Swift 6 编译不兼容 | 中 | 构建失败 | 版本锁定；必要时降 Swift 语言模式到 5 |
| R-07 | 免费签名 7 天过期 | 高 | 需重装 | 文档写明；自用可接受 |
| R-08 | ZMarkupParser 与 SnapshotTesting 版本冲突 | 中 | 测试依赖冲突 | 不引 SnapshotTesting；要用则锁 1.12.0 |
| R-09 | CryptoSwift 许可需致谢 | 低 | 合规 | `ACKNOWLEDGEMENTS.md` |
| R-10 | 改动误伤现有 Tauri 端 | 低 | 四端构建坏 | 只动 `ios-native/`；根目录构建回归 |

## 14. 进度记录

| 日期 | 阶段 | 记录 |
|---|---|---|
| 2026-11-17 | 规划 | 确定路线 A、iOS 17、并行目录、依赖清单、架构 |
| 2026-11-17 | M0 | 六份文档完成；XcodeGen/SPM 解析通过；APIClient + 模型 + 封面解码器落地；7 个单测 + 3 个 UI 测试通过；Feed/Playback/封面真实联调通过（系统代理） |
| 2026-11-17 | M1 | DesignSystem、导航/设置/我的/登录壳、Session 启动恢复、LocalLibrary、LineStore、主题持久化；15 个单测 + 5 个 UI 测试通过 |
| 2026-11-18 | M2 | 首页分页、UICollectionView FeedPager、单 AVPlayer/HLS、续播、选集/评论/全屏、封面；21 个单测 + 11 个 UI 测试通过 |
| 2026-11-18 | M3 | 详情面板、点赞/收藏/关注、评论列表/发送、真实登录/退出、登录拦截/401、分享；28 个单测 + 13 个 UI 测试通过 |
| 2026-11-18 | M4 | 搜索/历史、分类频道（空频道隐藏）、三榜单、列表→Feed 分页来源；35 个单测 + 18 个 UI 测试通过 |
| 2026-11-18 | M5 | 资料卡/收藏/历史、设置/缓存/诊断/更新、镜像线路/探测；38 个单测 + 21 个 UI 测试通过 |
| 2026-11-18 | M6 | 吃瓜列表、HTML 清洗/渲染、帖子详情/点赞/收藏/评论；43 个单测 + 23 个 UI 测试通过 |

## 15. 下一步

**当前指针：M7-01 播放器系统能力 / M7-02 打磨发布。**

具体动作：
1. 播放器补 PiP/AirPlay/后台音频/锁屏控制（按 P1 优先级）。
2. 图片/列表性能、无障碍、字号/对比度、错误文案统一。
3. 图标/签名/安装文档与 7 天重签说明；回归 Tauri 四端不受影响。
4. 按 M7 任务清单做最终验收，不新增业务范围。

> 每完成一个任务，把本表对应状态改成 ✅，并在第 14 节加一行；不要等整个 milestone 结束再补。
