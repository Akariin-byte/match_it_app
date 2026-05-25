# MATCHit 注册 / 登录流程

> 开发验证码：`000000`（`SMS_MOCK=true`）  
> 在线预览 Mermaid：复制下方代码块到 https://mermaid.live

---

## 1. 总览流程图

```mermaid
flowchart TD
    Start([打开 App]) --> Choice{用户选择}

    Choice -->|先逛逛| G1[POST /auth/guest-login]
    G1 --> G2[返回游客 JWT is_guest=true]
    G2 --> Feed1[进入首页 Feed 橙色游客横幅]

    Choice -->|手机号登录/注册| P1[输入 11 位手机号]
    P1 --> P2[POST /auth/phone-status]
    P2 --> P3{手机号已注册?}

    P3 -->|是| L1[显示欢迎回来和昵称 隐藏昵称框]
    P3 -->|否| R1[显示昵称选填 留空自动生成游客名]

    L1 --> S1[POST /auth/send-code scene=login]
    R1 --> S2[POST /auth/send-code scene=bind]

    S1 --> Code[输入验证码 000000]
    S2 --> Code

    Code --> Submit{提交时分支}

    Submit -->|已注册| Login[POST /auth/login]
    Submit -->|欢迎页新号| Reg[POST /auth/register]
    Submit -->|游客弹窗绑定| Bind[POST /auth/bind-phone 需游客 Token]

    Login --> OK[返回 JWT + refreshToken is_guest=false]
    Reg --> OK
    Bind --> OK

    OK --> Save[flutter_secure_storage 存 Token]
    Save --> Feed2[进入首页 右上角头像 菜单退出]

    Feed1 --> GuestBind{游客点登录/注册?}
    GuestBind -->|是| Sheet[LoginBottomSheet 带游客 Token]
    Sheet --> P1

    Feed2 --> Logout[POST /auth/logout]
    Logout --> Clear[清本地 Token]
    Clear --> Feed1
```

---

## 2. 三条测试用例

```mermaid
flowchart LR
    subgraph A[用例1 先逛逛]
        A1[guest-login] --> A2[游客 Feed]
    end

    subgraph B[用例2 老号登录]
        B1[phone-status 已注册] --> B2[send-code login]
        B2 --> B3[login]
    end

    subgraph C[用例3 新号注册]
        C1[phone-status 未注册] --> C2[send-code bind]
        C2 --> C3[register 昵称可空]
        C3 --> C4[随机 游客XXXXXX]
    end
```

---

## 3. 时序图（欢迎页注册）

```mermaid
sequenceDiagram
    participant U as 用户
    participant App as Flutter
    participant API as Go API
    participant DB as PostgreSQL

    U->>App: 输入手机号
    App->>API: POST /auth/phone-status
    API->>DB: 查 phone
    DB-->>API: registered=false
    API-->>App: 未注册 显示昵称选填

    U->>App: 获取验证码
    App->>API: POST /auth/send-code scene=bind
    API-->>App: 200 mock 000000

    U->>App: 验证码 + 空昵称 提交
    App->>API: POST /auth/register
    API->>DB: 创建用户 is_guest=false
    DB-->>API: username=游客836405
    API-->>App: token + user
    App->>App: secure_storage 保存
    App-->>U: 进入首页
```

---

## 4. API 清单

| API | 方法 | 鉴权 | 作用 |
|-----|------|------|------|
| `/api/v1/auth/guest-login` | POST | 无 | 按 device_id 创建/查找游客 |
| `/api/v1/auth/phone-status` | POST | 无 | 查手机号是否已注册，返回 username |
| `/api/v1/auth/send-code` | POST | 无 | 发验证码 scene=bind 或 login |
| `/api/v1/auth/register` | POST | 无 | 欢迎页新手机号注册，昵称可空 |
| `/api/v1/auth/login` | POST | 无 | 已注册手机号登录 |
| `/api/v1/auth/bind-phone` | POST | 游客 JWT | 游客绑手机升级；已注册号则直接登录 |
| `/api/v1/auth/refresh` | POST | 无 | refresh_token 续期 |
| `/api/v1/auth/logout` | POST | 任意 JWT | 退出，吊销 token |
| `/api/v1/me` | GET | 任意 JWT | 当前用户信息 |

---

## 5. 前端分支逻辑（PhoneAuthForm）

| 条件 | 调用 API |
|------|----------|
| phone-status → 已注册 | `login` |
| 欢迎页 + 未注册 | `register` |
| 游客弹窗 + 未注册 | `bind-phone`（需游客 Token） |
| 先逛逛 | `guest-login` |

---

## 6. UI 状态

| 状态 | is_guest | 首页表现 |
|------|----------|----------|
| 游客 | true | 橙色「游客模式」+ 登录/注册 |
| 已登录 | false | 右上角头像，菜单退出 |

---

## 7. 如何导出为图片

1. 打开 https://mermaid.live  
2. 复制上面任意 ` ```mermaid ` 代码块内容粘贴  
3. 右上角 **Actions → PNG / SVG** 下载  

或在 Cursor 里打开本文件，安装 Mermaid 预览插件后导出。
