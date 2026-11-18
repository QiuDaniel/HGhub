# M7 回归清单

> 自动化部分由 `xcodebuild test` 覆盖；标 **真机** 的项目必须在自用设备上按 [install.md](install.md) 验收。

## 1. 工程与构建

- [ ] `cd ios-native && xcodegen generate` 成功
- [x] `xcodebuild build`（generic iOS Simulator）成功
- [x] 单元测试 44 个 / 23 suites 通过
- [x] UI 测试 23 个通过
- [x] `.xcodeproj`、`Package.resolved` 未入库
- [x] 根目录 `src/`、`src-tauri/` 未改动，Tauri 构建不受影响

## 2. 启动 / 外观 / 图标

- [x] `HGHub/Info.plist` 显式存在，版本绑定 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`
- [x] `UIBackgroundModes = [audio]`
- [x] AppIcon 1024 + `UILaunchScreen` 生成
- [ ] 真机桌面图标/启动画面确认
- [x] 深色/浅色主题切换并持久化

## 3. 播放

- [x] Feed 竖滑、单击暂停、双击点赞门禁、长按 2x、横滑进度、边缘亮度/音量
- [x] 单 AVPlayer、切条、按历史续播、选集/评论/详情
- [x] 播放错误文案、重试按钮
- [ ] 真机锁屏控制（播放/暂停/拖动/±10s）
- [ ] 真机 Now Playing 标题/进度
- [ ] 真机 AirPlay 选设备
- [ ] 真机 PiP 进入/退出/回前台恢复
- [ ] 真机后台音频持续播放
- [ ] 真机 AirPods/蓝牙切换、来电打断恢复

## 4. 网络 / 线路

- [x] 系统代理下 Feed/Playback/搜索/分类/榜单/详情/评论/帖子
- [x] 固定线路切换并持久化
- [x] 发布页镜像解析（最多 60）、单项/全部探测
- [x] 网络诊断快照可复制
- [ ] 真机 Wi-Fi 代理（Mac 局域网 IP）验证
- [ ] 弱网/断网：重试 3 次、错误态、切线路恢复

## 5. 账号 / 数据

- [x] 登录/退出/Keychain 会话/401 清会话
- [x] 收藏/喜欢/关注/历史/搜索历史
- [x] 我的页收藏/历史回填，点击续播
- [x] 清缓存保留登录/收藏/历史
- [x] 检查更新无 Release / 有新版本展示
- [ ] 真机真实账号登录后跨启动恢复

## 6. 吃瓜

- [x] 列表分页、详情正文、图片/链接、HTML 清洗
- [x] 帖子点赞/收藏/评论登录门禁
- [ ] 真机长正文滚动与图片加载性能
- [ ] VoiceOver 抽查正文链接/图片

## 7. 无障碍 / 动态字体

- [x] 主要按钮有 label/identifier
- [x] 历史行合并朗读
- [ ] 真机 VoiceOver 抽查 Feed 控件、设置、评论、详情
- [ ] 系统最大动态字体下关键页面不截断

## 8. 签名 / 安装

- [ ] Xcode 选择个人 Team
- [ ] Bundle ID 冲突时修改
- [ ] 真机安装并信任开发者
- [ ] 7 天到期重签说明已阅读

## 9. 结果记录

| 日期 | 设备/系统 | 结果 | 备注 |
|---|---|---|---|
| 2026-11-18 | iPhone 17 Pro 模拟器 / iOS 26.2 | 自动化通过 | 44 单测 + 23 UI；真机项待验收 |
