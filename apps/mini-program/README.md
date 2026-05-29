# MATCHit 微信小程序（uni-app Vue3）

与现有 **Go API** 共用后端，Flutter App 可并行维护。

## 技术栈

- uni-app 3 + Vue 3 + TypeScript + Vite
- Pinia 状态管理
- 对接现有 `/api/v1/*` REST + WebSocket 私信

## 快速开始

```bash
cd apps/mini-program
npm install
npm run dev:mp-weixin
```

用 **微信开发者工具** 打开：`apps/mini-program/dist/dev/mp-weixin`

**先启动后端**（否则会出现 `ERR_CONNECTION_REFUSED` / `bootstrap failed`）：

```powershell
powershell -File backend\start-backend-local.ps1
```

开发者工具：**详情 → 本地设置 → 不校验合法域名、web-view、TLS…**

### 环境变量

`.env.development`：

```
VITE_API_BASE_URL=http://127.0.0.1:8080
VITE_SKIP_WECHAT_LOGIN=true
```

真机需 **备案 HTTPS 域名** + 微信公众平台配置 request / socket 合法域名。

## 功能进度

| 模块 | 状态 |
|------|------|
| 游客登录兜底 | ✅ |
| 手机号登录 | ✅ |
| 微信 code 登录 | ⏳ 需后端 `/auth/wechat-login` |
| Feed | ✅ |
| 帖子详情 + 申请加入 | ✅ |
| 私信 WS | ✅ |
| 发布 / 个人页 | ✅ 简版 |

## Tab

首页 | 消息 | 私信 | 我 — 发布为首页右下角 **+** 按钮
