#!/usr/bin/env node
/**
 * 把仓库里跟踪的 iOS 图标同步进生成的 iOS 工程。
 *
 * 与 scripts/sync-android-icons.mjs 同理：`src-tauri/gen/` 不入库，
 * `tauri ios init` 只写模板默认图标，不会读 `src-tauri/icons/ios/`。
 * 只拷 AppIcon-*.png，模板的 Contents.json 保持原样（里面的文件名
 * 与 `tauri icon` 生成的命名一致，直接覆盖同名文件即可）。
 *
 * 用法：
 *   node scripts/sync-ios-icons.mjs
 *   （tauri.ios.conf.json 的 beforeBuildCommand 已自动调用，一般不用手动跑）
 */
import { cpSync, existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = join(root, "src-tauri", "icons", "ios");
const dest = join(root, "src-tauri", "gen", "ios", "App", "App", "Assets.xcassets", "AppIcon.appiconset");

if (!existsSync(src)) {
  console.log(`[icons] 跳过：缺少 ${src}`);
  process.exit(0);
}
if (!existsSync(dest)) {
  console.log("[icons] 跳过：gen/ios 还没生成（先跑 tauri ios init）");
  process.exit(0);
}

for (const name of readdirSync(src)) {
  if (!name.endsWith(".png")) continue;
  cpSync(join(src, name), join(dest, name), { force: true });
}
console.log(`[icons] iOS 图标已同步 → ${dest}`);
