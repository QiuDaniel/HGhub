# 三方库与致谢

本工程使用以下开源软件。版本以 [project.yml](project.yml) 的 `exactVersion` 为准；升级时同步更新本文件。

| 库 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| [Nuke](https://github.com/kean/Nuke)（含 NukeUI） | 13.2.3 | MIT | 图片下载、缓存、解码；封面 AES 解密钩子 |
| [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) | 1.10.0 | zlib 风格（见下） | AES-128-CBC 封面解密 |
| [Valet](https://github.com/square/Valet) | 5.1.1 | Apache-2.0 | Keychain 存储 token |
| [Defaults](https://github.com/sindresorhus/Defaults) | 9.0.9 | MIT | 主题、收藏、历史等轻量持久化 |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | 2.14.4 | MIT | HTML 清洗、相对地址补全 |
| [ZMarkupParser](https://github.com/ZhgChgLi/ZMarkupParser) | 2.0.2 | MIT | HTML → NSAttributedString |
| [ZNSTextAttachment](https://github.com/ZhgChgLi/ZNSTextAttachment) | 1.2.0 | MIT | 正文 `<img>` 异步 attachment |
| [AlertToast](https://github.com/elai950/AlertToast) | 1.3.9 | MIT | Toast / HUD |
| [Pulse](https://github.com/kean/Pulse)（DEBUG） | 5.2.3 | MIT | 网络请求日志 |

系统框架：SwiftUI、Foundation、AVFoundation、AVKit、UIKit、Observation、Security 等，归 Apple 所有。

## CryptoSwift 致谢（许可证要求）

> This product includes software developed by the "Marcin Krzyzanowski" (http://krzyzanowskim.com/).

CryptoSwift 的许可证要求在产品文档中保留上述致谢；本文件即为该致谢。

## 说明

- 所有库均为宽松许可（MIT / Apache-2.0 / zlib 风格），与本项目 PolyForm Noncommercial 1.0.0 不冲突。
- 不使用 GPL/AGPL 依赖；不引入广告、统计、短视频 SDK。
- 若新增依赖，必须同时更新本文件与 [ADR-005](docs/decisions.md#adr-005-三方库清单)。
