/**
 * 从 .env.local / .env.development 读取 VITE_MP_WEIXIN_APPID，写入 manifest.json
 * 并在已存在的 dist 里同步 project.config.json（避免仍为 touristappid）
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const out = {};
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    out[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return out;
}

const env = {
  ...loadEnvFile(path.join(root, '.env.development')),
  ...loadEnvFile(path.join(root, '.env.local')),
};

const appId = (env.VITE_MP_WEIXIN_APPID || '').trim();
const manifestPath = path.join(root, 'src', 'manifest.json');

if (!appId) {
  console.log(
    '[apply-weixin-appid] 未配置 VITE_MP_WEIXIN_APPID，将使用微信开发者工具游客模式（touristappid）',
  );
  console.log(
    '  复制 .env.local.example 为 .env.local，填入公众平台的小程序 AppID 后重新编译',
  );
  process.exit(0);
}

if (!/^wx[a-f0-9]{16}$/i.test(appId)) {
  console.warn(
    `[apply-weixin-appid] AppID 格式可疑（应为 wx 开头 18 位）: ${appId}`,
  );
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
manifest.appid = appId;
if (!manifest['mp-weixin']) manifest['mp-weixin'] = {};
manifest['mp-weixin'].appid = appId;
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
console.log('[apply-weixin-appid] 已写入 src/manifest.json:', appId);

const distConfigs = [
  path.join(root, 'dist', 'dev', 'mp-weixin', 'project.config.json'),
  path.join(root, 'dist', 'build', 'mp-weixin', 'project.config.json'),
];

for (const cfgPath of distConfigs) {
  if (!fs.existsSync(cfgPath)) continue;
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  cfg.appid = appId;
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
  console.log('[apply-weixin-appid] 已同步', cfgPath);
}
