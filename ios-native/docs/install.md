# 安装与签名（自用）

> 目标：把自己的 iPhone 装上 `ios-native/HGHub`，不经过 App Store。
> 免费 Apple ID 的 provisioning 只有 **7 天**，到期需要在 Xcode 重新安装。

## 1. 环境

- macOS + Xcode（本项目在 Xcode 27.1 / iOS 26 模拟器验证）
- 已安装 XcodeGen：`brew install xcodegen`
- iPhone 系统 **iOS 17.0+**
- 真机网络需要能访问上游：在 iPhone Wi-Fi 设置里配置 HTTP 代理到 Mac 的局域网 IP:7890（不是 `127.0.0.1`）

## 2. 生成工程

```bash
cd ios-native
xcodegen generate
open HGHub.xcodeproj
```

`HGHub.xcodeproj` 不入库；`project.yml` 是唯一工程配置源。

## 3. 选择签名 Team

1. Xcode 左侧选中 `HGHub` target → **Signing & Capabilities**
2. 勾选 **Automatically manage signing**
3. Team 选自己的 Apple ID（没有则 Xcode → Settings → Accounts 登录）
4. Bundle Identifier 默认 `com.hghub.native`；如果冲突，改成 `com.<你的名字>.hghub`，并同步 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`

免费账号的限制：

- 每 7 天需要重新签名/安装
- 最多 3 个 App、最多 10 个 App ID
- 不能使用 Push、Background Modes 之外的受限能力；本项目只声明 `UIBackgroundModes = audio`

## 4. 真机运行

1. iPhone 用数据线连接 Mac，解锁并点“信任”
2. Xcode 顶部 destination 选择你的 iPhone
3. `Cmd+R`
4. 首次运行如提示“不受信任的开发者”：iPhone 设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID
5. 打开 App；如果网络打不开，先确认 iPhone Wi-Fi 代理指向 Mac 的局域网 IP:7890

## 5. 后台音频 / PiP / AirPlay

- `project.yml` 的 `HGHub/Info.plist` 已声明 `UIBackgroundModes = audio`
- 播放器侧边栏提供 AirPlay；支持 PiP 的设备会显示画中画按钮
- 锁屏/控制中心使用 `MPRemoteCommandCenter` + Now Playing；实际后台切换、锁屏控制需要真机验收
- 如果 Xcode 提示 signing capability 缺失，不要手动删 `UIBackgroundModes`；它只是 plist 声明，不需要付费账号的额外 entitlement

## 6. Release 归档（可选，自用）

```bash
xcodebuild -project HGHub.xcodeproj -scheme HGHub \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/HGHub.xcarchive archive
```

免费账号通常只能用 Debug 直接安装；Release/Ad Hoc 分发需要付费开发者账号。

## 7. 常见问题

| 现象 | 处理 |
|---|---|
| `No signing certificate` | Xcode → Settings → Accounts 登录 Apple ID；target 选 Team |
| 安装后 7 天打不开 | 免费签名过期，重新 `Cmd+R` 覆盖安装 |
| 真机网络超时 | Wi-Fi 代理指向 Mac 局域网 IP:7890；不是 `127.0.0.1` |
| 后台播放被系统暂停 | 确认 Info.plist 有 `UIBackgroundModes = audio`，且播放器 `AVAudioSession` 为 `.playback` |
| AirPlay 按钮无设备 | 同一 Wi-Fi、设备支持 AirPlay；模拟器不代表真机行为 |
| PiP 按钮不出现 | `AVPictureInPictureController.isPictureInPictureSupported()` 为 false；真机/系统版本相关 |

> 本项目仅个人学习/自用，不商用、不上架；所有内容来自上游站点，客户端不存储、不分发内容。
