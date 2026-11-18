# HGhub iOS Native

HGhub 的**纯原生 iOS 客户端**（SwiftUI + AVPlayer）。它与仓库根目录的 Tauri 四端（Windows / macOS / Android / iOS-WebView）**并存**：原生工程只交付 iOS，不替换、不改动 `src/` 与 `src-tauri/`。

| 项 | 值 |
|---|---|
| 目标系统 | iOS 17.0+ |
| 语言 / 框架 | Swift 6、SwiftUI、Observation、AVFoundation、async/await |
| 工程生成 | XcodeGen（`project.yml` 是唯一工程配置源，`.xcodeproj` 不入库） |
| 当前阶段 | **M2 完成：首页 + 竖滑 Feed + AVPlayer 播放器 + 续播** |
| 使用性质 | 个人学习 / 自用，不商用、不上架（见根目录 LICENSE） |

## 文档索引

先读文档，再改代码。所有实现决策以文档为准；代码与文档不一致时，先改文档再改代码。

| 文档 | 内容 | 什么时候看 |
|---|---|---|
| [需求规格](docs/requirements.md) | 目标/非目标、功能需求 ID、非功能需求、验收标准 | 接需求、判断“要不要做” |
| [架构设计](docs/architecture.md) | 分层、模块职责、数据流、导航、播放器、网络、并发、测试 | 改代码前 |
| [开发计划](docs/development-plan.md) | M0–M7 里程碑、任务清单、质量门禁、风险、进度 | 每次开工前 / 收工后 |
| [接口契约](docs/api-contract.md) | 边缘信封、鉴权、端点、播放例外、封面加密、线路 | 调接口、排查“打不开/不能播” |
| [决策记录](docs/decisions.md) | ADR：为什么原生、为什么不用 Tauri 内核、为什么选这些库 | 想推翻某个决定时 |

## 快速开始

```bash
# 1. 生成工程（首次 / 改过 project.yml 后）
brew install xcodegen          # 已安装可跳过
cd ios-native
xcodegen generate

# 2. 打开工程
open HGHub.xcodeproj

# 3. 模拟器编译
xcodebuild -project HGHub.xcodeproj -scheme HGHub \
  -destination 'generic/platform=iOS Simulator' build

# 4. 跑单测（换成你本机已有的模拟器名）
xcodebuild -project HGHub.xcodeproj -scheme HGHub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# 5. 真机（自用签名）
#    Xcode → HGHub target → Signing & Capabilities → 选自己的 Team
#    免费 Apple ID 的 provisioning 只有 7 天，到期重新安装
```

**M0 已验证**：XcodeGen 生成工程、10 个 SPM 依赖解析（Nuke / SwiftSoup / ZMarkupParser / ZNSTextAttachment / CryptoSwift / Valet / Defaults / AlertToast / Pulse / swift-syntax）、模拟器构建、**7 个单测 + 3 个 UI 测试**通过；App 启动见 4 Tab + M0 自检入口；通过 macOS 系统代理实测 Feed 200（10 条 / 179 页）、Playback 200（streams.main）、封面下载 + AES 解密得到 JPEG。启动截图见 [docs/m0-launch.png](docs/m0-launch.png)。

**M1 已验证**：DesignSystem（颜色/按钮/Chip/Avatar/空态/骨架）、每 Tab `NavigationStack` + `Route`、Session 启动恢复、`LocalLibrary`（收藏/喜欢/关注/观看历史/搜索历史，80/12 上限）、`LineStore`（固定 2 条 + 持久化 + 地址校验）、设置/线路选择/我的/登录壳；**15 个单测 + 5 个 UI 测试**通过。

**M2 已验证**：首页两列 Feed 分页、`UICollectionView` 竖滑分页、单 `AVPlayer` HLS 播放（系统代理实测起播）、单击/双击/长按/横滑/边缘手势、进度/倍速/静音/全屏、选集/评论入口、Nuke 封面、按历史续播；**21 个单测 + 11 个 UI 测试**通过。

**网络说明**：iOS 的 `URLSession`/CFNetwork 自动读取系统代理；模拟器复用 macOS 系统代理（当前 `127.0.0.1:7890`），真机需在 Wi-Fi 设置里把 HTTP 代理指向 Mac 的局域网 IP。`curl` 不读系统代理，裸 `curl` 会误判“站点不可达”，排查时用 `curl -x http://127.0.0.1:7890 ...`。详见 [接口契约 § 代理](docs/api-contract.md#11-代理与网络排查)。

## 目录

```
ios-native/
├─ project.yml                 # XcodeGen 工程定义（唯一配置源）
├─ docs/                       # 需求 / 架构 / 计划 / 契约 / ADR
├─ HGHub/
│  ├─ App/                     # HGHubApp、AppState、RootTabView、Route、依赖组装
│  ├─ Core/                    # 网络、模型、仓库、会话、存储、线路、图片、HTML
│  ├─ Features/                # 按页面分：Home/Feed/Search/Category/Profile/...
│  ├─ DesignSystem/            # 颜色、字体、通用组件
│  └─ Resources/               # Assets、图标
├─ HGHubTests/                 # 契约 fixtures + 单元测试
├─ HGHubUITests/               # UI 冒烟
├─ ACKNOWLEDGEMENTS.md         # 三方库许可与致谢
└─ README.md
```

## 与 Tauri 版的关系

- **协议层照抄**：边缘信封、播放接口、封面 AES、线路规则都以 Tauri 版为参照实现（见 [接口契约](docs/api-contract.md)）。
- **代码不复用**：不搬 Rust、不搬 React；iOS 端是独立的 Swift 实现。
- **Tauri 版仍是参照实现**：行为对齐时，以根目录 `src/`、`src-tauri/` 的现有实现和 [AIRead.md](../AIRead.md) 为准。
- **互不影响**：原生工程新增目录，Tauri 的 `pnpm build` / `tauri build` 流程不变。

## 许可

原生客户端与 HGhub 主项目一致，适用根目录 [LICENSE](../LICENSE)（PolyForm Noncommercial 1.0.0）。三方库许可见 [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)。
