# 接口契约 · ios-native

> 版本：v0.2（M3 基线）
> 更新：2026-11-18
> 来源：以现有 Rust 实现 [net.rs](../src-tauri/src/net.rs)、[api.rs](../src-tauri/src/api.rs)、[media.rs](../src-tauri/src/media.rs)、[lines.rs](../src-tauri/src/lines.rs) 与 [AIRead.md](../AIRead.md) 为准。
> 目的：Swift 端按这份契约重写；**契约变了先改这里，再改代码**。

---

## 1. 基址与线路

| 项 | 值 |
|---|---|
| 默认基址 | `https://huangguoai.com` |
| 固定线路 2 | `https://huangguoai.ai` |
| 镜像发布页 | `https://huangguoai.pages.dev/`（空壳页面，真实清单在 `publish.js`） |
| 地址规整 | 仅 `http(s)` 且必须有 host；去掉结尾 `/` |
| 持久化 | 本地保存 `base`，启动时注入 `APIClient` |

**镜像解析**：抓发布页 HTML → 取 `<script src>`（缺省 `publish.js`）→ 抓 JS → 解析 `var urls = [...]` 与 `var subdomains = [...]` → 子域 × 域名做笛卡尔积 → 去重 → 上限 60 条。解析失败返回明确错误，不静默。

**探测**：`GET {url}/`，超时 8s，最多 6 条并发；只报 `ok/status/ms/error`，不自动切换。

> 不要把 CDN 域名写死成白名单：清单在 `*.tjyyjk.cn`，密钥/分片在 `tp*.qnlycc.cn`，图床 `pic.qnlycc.cn`，都可能漂移。

---

## 2. 边缘信封（所有 `/api/**` 业务请求）

### 2.1 请求

```http
POST {base}/api/edge/request
Accept: application/json
Referer: {base}/
Authorization: Bearer {token}        # 可选；登录态才带
Content-Type: application/json

{
  "method": "GET",
  "path": "/api/videos?page=1&size=10",
  "body": "",
  "content_type": ""
}
```

- `body` 是真实请求体的 **base64(JSON UTF-8)**；GET/DELETE 无 body 时为空串，`content_type` 为空串。
- 有 body 时 `content_type` 为 `application/json`。
- `path` 包含 query string，且必须与真实接口一致。
- `Referer` 固定为 `{base}/`（上游可能校验）。

POST 示例：

```json
{
  "method": "POST",
  "path": "/api/account/loginByPassword",
  "body": "eyJ1c2VybmFtZSI6Ii4uLiIsInBhc3N3b3JkIjoiLi4uIn0=",
  "content_type": "application/json"
}
```

### 2.2 响应

```json
{ "status": 1, "data": { } }
```

- `status == 1`：取 `data` 返回给上层。
- `status == 0`：抛业务错误，`msg` 即用户文案（缺省「接口返回失败」）。
- HTTP 401/403：抛 `unauthorized`（上层清会话、弹登录）。
- 其它非 2xx：抛 `http(status)`。
- 空响应体：返回 `null`（调用方按空处理）。
- 非 JSON / 解码失败：抛 `decoding`，附前 160 字符便于排查。

### 2.3 重试

- 网络错误、超时、连接失败：最多 3 次，间隔 350ms / 700ms。
- 401/403、业务错误、解码错误：**不重试**。
- 超时：总 20s，连接 10s。

---

## 3. 播放接口（唯一不走信封的例外）

```http
POST {base}/api/videos/{id}/episodes/{ep}/playback
Accept: application/json
Referer: {base}/
Authorization: Bearer {token}        # 可选
Content-Type: application/json

{}
```

> **body 必须是空 JSON `{}`**。带 id/ep 会返回「播放参数无效」；走 `/api/edge/request` 信封会返回 `{"error":"请求无法处理"}`（2026-11-17 实测）。

响应（外层含 `status/data`，与信封不同，需调用方自己解包）：

```json
{
  "status": 1,
  "data": {
    "streams": {
      "main": "https://.../xxx.m3u8?auth_key=...",
      "hevc": "https://.../xxx.m3u8?...",
      "preview": "https://.../preview.m3u8?..."
    },
    "cdn": { "authKey": "x-cdn-auth", "authValue": "..." }
  }
}
```

归一化为 App 的 `PlayInfo`：

| 字段 | 取值 |
|---|---|
| `video_url` | `streams.main` → 空则 `hevc` → 空则 `preview` |
| `video_url_hevc` | `streams.hevc` |
| `cdn` | 原样保留（可选 header） |
| `id` / `ep_num` | 入参 |
| `title` | `第{ep}集` |
| `duration` | `0`（接口不一定给，播放器以 AVPlayer 为准） |

**兜底**：playback 失败且错误不是 401 时，尝试老接口 `GET /api/videos/{id}/play?ep={ep}&page_texts=0`（走信封）；仍失败则返回 playback 的原始错误。

---

## 4. 端点清单

> 除 playback 外，全部走第 2 节信封。`auth` 列：`-` 匿名可调；`✓` 必须登录。

| # | 用途 | Method | Path | Body | auth |
|---|---|---|---|---|---|
| 1 | 登录 | POST | `/api/account/loginByPassword` | `{username,password}` | - |
| 2 | 注册 | POST | `/api/account/registerByPassword` | `{username,password,confirm_password,email?}` | - |
| 3 | 退出 | POST | `/api/account/logout` | - | ✓ |
| 4 | 当前用户 | GET | `/api/account/me` | - | ✓ |
| 5 | 首页 Feed | GET | `/api/videos?page={page}&size={size}` | - | - |
| 6 | 分类 | GET | `/api/videos?cate_id={cate}&page={page}&size={size}` | - | - |
| 7 | 榜单 | GET | `/api/ranks/{kind}`（hot/recommend/potential） | - | - |
| 8 | 搜索 | GET | `/api/search?q={urlencoded}&page=&size=` | - | - |
| 9 | 吃瓜列表 | GET | `/api/posts?page=&size=` | - | - |
| 10 | 吃瓜详情 | GET | `/api/posts/{id}` | - | - |
| 11 | 视频详情 | GET | `/api/videos/{id}` | - | - |
| 12 | 播放 | POST | `/api/videos/{id}/episodes/{ep}/playback`（**直连**） | `{}` | - |
| 13 | 评论列表 | GET | `/api/videos/{id}/comments?ep={ep}&page=&size=` | - | - |
| 14 | 发评论 | POST | `/api/videos/{id}/comments`（回复）或 `?ep={ep}`（主楼） | `{text,reply_id?}` | ✓ |
| 15 | 视频点赞 | POST/DELETE | `/api/videos/{id}/like?ep={ep}` | - | ✓ |
| 16 | 视频收藏 | POST/DELETE | `/api/videos/{id}/collect` | - | ✓ |
| 17 | 关注用户 | POST/DELETE | `/api/users/{uid}/follow` | - | ✓ |
| 18 | 帖子点赞 | POST/DELETE | `/api/posts/{id}/like` | - | ✓ |
| 19 | 帖子收藏 | POST/DELETE | `/api/posts/{id}/collect` | - | ✓ |
| 20 | 帖子评论 | GET | `/api/posts/{id}/comments?page=&size=` | - | - |

本地能力（不走上游）：`app_boot`（读本地 session + base）、`cache_clear`、`line_state`、`line_mirrors`、`line_probe`、`check_update`（GitHub API）、`open_url`（系统打开）。

### 4.1 关键业务规则

- **分类必须数字 `cate_id`**：`/api/videos?cate_id=24`。旧的 `/api/videos/category/{slug}` 已 410；`category_id` 会被忽略返回全量。
- **分页**：每页 20 条；App 首页用 `size=10`。`size/limit` 上游不一定认，按 20 处理。榜单只给前 20，不翻页。
- **退出**：即使接口失败，也清本地会话。
- **评论发送成功**：提示「审核通过后展示」，并重新拉第 1 页。
- **关注/点赞/收藏**：未登录先弹登录，不预发请求。

---

## 5. 数据模型（Swift Codable）

> 字段以 `types.ts` 为准；Swift 端用 `JSONDecoder` + `.convertFromSnakeCase`。
> 所有“可能缺/可能变类型”的字段都用可选 + 默认值，解码失败不能崩。

### 5.1 `Paged<T>`

```json
{
  "items": [],
  "pagination": { "page": 1, "pages": 3, "size": 10, "total": 25 }
}
```

### 5.2 `VideoCard`

```json
{
  "id": 117,
  "title": "…",
  "cover": "https://pic.../xxx.jpg?auth_key=…",
  "description": "…",
  "tags": ["…"],
  "score": 8.5,
  "episode_count": 20,
  "total_episodes": 20,
  "duration": "02:30",
  "hot": 12345,
  "like_count": 1,
  "collect_count": 2,
  "comment_count": 3,
  "is_finished": true,
  "is_original": 1,
  "created_at": "…",
  "last_ep_at": 0,
  "new_at": 0,
  "author": { "id": 1, "name": "…", "avatar": "…", "followers": 0 }
}
```

### 5.3 `Detail`

在 `VideoCard` 基础上增加：

```json
{
  "episodes": [{ "ep_num": 1, "title": "第1集", "duration": 120, "status": 1 }],
  "counts": { "collect": 0, "comment": 0, "hot": 0, "like": 0 },
  "author": { "id": 1, "name": "…", "is_following": false },
  "interaction": { "collected": false, "liked": false, "liked_ep": 0 },
  "video_url": "",
  "video_url_hevc": "",
  "is_finished": true,
  "is_original": 1,
  "video_type": 1,
  "duration": 0
}
```

> 老接口的 `video_url` 可能是空串；播放地址以 playback 为准。
> 实测 detail 的 `duration` 可能是字符串（如 `"820"`），Swift 用 `FlexibleDouble` 兼容数字/字符串。

### 5.4 `PlayInfo`

```json
{
  "id": 117,
  "ep_num": 3,
  "title": "第3集",
  "duration": 0,
  "video_url": "https://…m3u8?…",
  "video_url_hevc": null,
  "cdn": { "authKey": "x-cdn-auth", "authValue": "…" }
}
```

### 5.5 `CommentPage`

```json
{
  "ep": 3,
  "revision": "…",
  "reset": false,
  "items": [{
    "id": 1, "user_id": 2, "nickname": "…", "avatar": "…", "avatar_color": "#…",
    "content": "…", "text": "…", "time": "…", "created_at": "…",
    "like_count": 0, "liked": false, "reply_count": 0, "reply_id": 0,
    "reply_list": [], "is_pinned": false, "ip_region": "…"
  }],
  "pagination": { "page": 1, "pages": 1, "size": 20, "total": 0 }
}
```

> 实测评论正文同时存在 `content` 与 `text`，两者通常相同；Swift 取 `content` 优先、`text` 兜底。`reply_list` 为楼中楼，首条可直接展示；发送回复时 `reply_id` 必须用 snake_case。

### 5.6 `Post` / `User`

见 [types.ts](../src/types.ts)；Swift 端同名字段 camelCase。

---

## 6. 封面加密

| 项 | 值 |
|---|---|
| 算法 | AES-128-CBC |
| Key / IV | 与 `src-tauri/src/media.rs` 顶部常量一致；为避免扩散，不在文档中重复 |
| Padding | 上游按 NoPadding 处理；解密后若末尾是合法 PKCS#7 再去掉 |

流程：

1. 下载原始字节（带 `Referer: {base}/`，可选桌面 UA）。
2. 若 magic 已是 JPEG(`FF D8`)/PNG(`89 50 4E 47`)/GIF(`GIF8`)/WebP(`RIFF....WEBP`)，直接解码。
3. 否则 AES-CBC 解密 → 去 padding → 再按 magic 选 MIME；解不出返回错误态，不崩。

Swift 侧用 `CryptoSwift` 的 `AES(key:blockMode: CBC(iv:), padding: .noPadding)`；Nuke 侧实现 `ImageDecoding`，配置 `makeImageDecoder`（Nuke 13 的入口，不是 `imageDecoder`）。

---

## 7. HLS / 播放

- iOS 端 `<video>`/AVPlayer **直连上游 m3u8**，不经过自定义协议，不重写 playlist。
- AVPlayer 原生支持 AES-128 HLS；清单里的 key/分片由 AVFoundation 自己拉。
- 若 CDN 校验 UA/Referer 或需要 `cdn.authKey/authValue`：用 `AVAssetResourceLoaderDelegate` + 自定义 scheme 注入 header；不要把私有 KVC 当主方案。
- 失败排查顺序：`video_url` 是否为空 → 是否被改回本地协议 → `AVPlayerItem.error` / `errorLog()` → 网络（DNS/代理/CDN 可达性）。
- 不做下载、不做离线缓存、不并发预取多条（只预加载下一条）。

---

## 8. 更新检查（可选）

`GET https://api.github.com/repos/Minireel/HGhub/releases/latest`
- 比较 `tag_name` 与当前 `MARKETING_VERSION` 的数字段；`v1.2.0 > 1.1.9`。
- 404 表示还没发 Release，按“无更新”处理。
- 只展示，不自动下载/安装。

---

## 9. fixtures

放 `HGHubTests/Fixtures/`，从真实请求脱敏后保存。2026-11-17 已落盘两份（走系统代理抓取，`auth_key`/`authValue` 已替换为 `REDACTED`）：

| 文件 | 来源 | 用途 | 状态 |
|---|---|---|---|
| `feed_page1.json` | `/api/videos?page=1&size=10` | Feed 解码（10 条 / 179 页） | ✅ 已落盘，单测覆盖 |
| `playback_117_3.json` | playback 117/3 | Playback 归一化（streams.main） | ✅ 已落盘 |
| `video_detail_117.json` | `/api/videos/117` | Detail 解码（42 集 / 字符串 duration） | ✅ 已落盘，单测覆盖 |
| `comments_117_3.json` | comments 117/3 | 评论解码（5 条 / 54 总 / 楼中楼） | ✅ 已落盘，单测覆盖 |
| `posts_page1.json` | `/api/posts?page=1` | 吃瓜列表 | 待 M6 |
| `post_detail_1.json` | `/api/posts/1` | 正文 HTML | 待 M6 |
| `line_state.json` | 本地 | 线路 UI | 待 M5 |
| `error_business.json` | 任意 `status:0` | 错误映射 | 待 M1 |

**不提交**：token、Cookie、手机号、`Authorization`、带签名的完整 CDN 直链（保留域名与路径结构即可）。

---

## 10. 上游变更记录

| 日期 | 变更 | 影响 |
|---|---|---|
| 2026-11-17 | 播放改 `POST /api/videos/{id}/episodes/{ep}/playback`，body `{}`，响应 `streams.main` | 老 `video_url` 为空串；必须换接口 |
| 2026-11-18 | Detail 的 `duration` 为字符串；评论正文同时有 `content` / `text` | 模型兼容字符串数字；评论取 `content` 优先 |
| 2026-11-17 | 分类改数字 `cate_id`；`/api/videos/category/{slug}` 410 | 频道写 24/25/26/27；空频道隐藏 |
| 2026-11-17 | iOS WebView 的 `<video>` 不经过 WKURLSchemeHandler | 原生工程无此问题；但证明 HLS 可直连 |
| 持续 | CDN 域名漂移 | 线路切换 + 不硬编码域名 |

> 每次发现上游变化，先在本表加一行，再改代码与 fixtures。

---

## 11. 代理与网络排查

### 11.1 结论

- **原生端不内置代理配置**：`URLSession` / CFNetwork 自动读取系统代理，和 Safari 行为一致。
- **macOS 系统代理**：`scutil --proxy` 查看；当前环境为 `HTTP/HTTPS/SOCKS 127.0.0.1:7890`。
- **iOS 模拟器**：复用 macOS 的系统代理。2026-11-17 实测 Feed 200、Playback 200、封面 200。
- **iOS 真机**：Wi-Fi → 配置代理 → 手动 → 服务器填 Mac 的局域网 IP（不是 `127.0.0.1`）、端口 7890；如系统提示本地网络权限，允许。
- **`curl` 不读系统代理**：裸 `curl https://huangguoai.com/` 会超时，容易误判“站点挂了”。排查必须加 `-x http://127.0.0.1:7890`，或走 DoH。
- **AVPlayer/HLS**：M2 真机验证是否走系统代理；若不走，用 `AVAssetResourceLoaderDelegate` 自定义 scheme 注入，不依赖私有 KVC。
- **App 级代理（v1 不做）**：如果以后需要不依赖系统代理，给 `URLSessionConfiguration` 设置 `connectionProxyDictionary`；AVPlayer 仍需系统代理或 resource loader。

### 11.2 排查命令

```bash
# 看系统代理
scutil --proxy

# 验证上游可达（必须显式带代理）
curl -x http://127.0.0.1:7890 -I https://huangguoai.com/

# 验证 Feed 信封
curl -x http://127.0.0.1:7890 https://huangguoai.com/api/edge/request \
  -H 'Content-Type: application/json' -H 'Referer: https://huangguoai.com/' \
  -d '{"method":"GET","path":"/api/videos?page=1&size=10","body":"","content_type":""}'

# 验证 Playback（直连、空 body）
curl -x http://127.0.0.1:7890 \
  -H 'Content-Type: application/json' -H 'Referer: https://huangguoai.com/' \
  -d '{}' https://huangguoai.com/api/videos/117/episodes/3/playback
```

### 11.3 应用内验证

- `HGHubUITests/M0SmokeUITests` 有 3 个 UI 测试：
  - `testContractCheckOpens`：自检页可打开；
  - `testFeedLoadsThroughSystemProxy`：点 Feed 并等待 `✅ items=...`；
  - `testPlaybackLoadsThroughSystemProxy`：点 Playback 并等待 `✅ url=...`。
- 这三个测试依赖系统代理；代理关闭时会失败，属于网络环境问题，不是代码回归。
