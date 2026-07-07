# v1.1 设计 —— 轻互动「Lumi 邮局」（明信片站内直投）

> 分支：`claude/v1.1-lumi-post`（基于 MVP 1.0 提审预留分支 `claude/mvp-1.0-submission` 切出）。
> 目标：把 MVP 的带外收发升级为**站内直投**，服务成本 $0 起、零运维；为 v1.2 账号打地基。
> 版本定位见 [`ROADMAP.md` v1.1 节](../product/ROADMAP.md)。

## 1. 目标与非目标

**目标**
- 寄明信片可直达对方收件箱（输入/选择对方「Lumi 邮箱号」），无需复制口令。
- 旅友码：往来的人升级为地址簿，点头像直寄。
- 送达回执：发件方看到「已送达 ✓」。
- 带外通道（QR / 链接 / AirDrop）**全部保留**——离线与陌生人分享场景。

**非目标（明确不做）**
- ❌ 推送通知（进 App / 下拉刷新轮询即可；推送留 v1.2+）
- ❌ 账号 / 密码 / 邮箱注册（v1.2 才引入，届时匿名信箱原地绑定升级）
- ❌ 消息 / IM / 在线状态（v2）

## 2. 技术选型：Supabase Free + **零 Auth 能力模型**

比对结论（详见 ROADMAP v1.1 节）：Supabase 免费档（500MB DB / 1GB Storage / 每月 5M REST 请求量级），
**不引入 GoTrue 登录**——用「能力密钥」模型进一步减配：

- 每台设备首次启用时通过 RPC 创建一个信箱，获得两个码：
  - **`box_id`（邮箱号，公开）**：形如 `LUMI-7F3K9Q`，给别人用来寄；
  - **`read_token`（读取密钥，私密）**：64 位随机，只存本机 Keychain/UserDefaults，谁持有谁能读该信箱。
- 客户端只允许调 **RPC 函数**（撤销对表的直接读写），不需要行级用户身份 → 不需要 Auth 服务。
- v1.2 升级路径：登录后把 `box_id` 绑定到 auth 用户（一条 `alter` + 认领 RPC），邮箱号与往来关系无损保留。

**为何不用 CloudKit**：Android 是确定目标，CloudKit 通道是断头路。
**为何不用匿名 Auth**：能力密钥已满足"只有我能读我的信箱"，少一个依赖面（GoTrue 限流/会话刷新都省了）。

## 3. 数据模型（Postgres / Supabase SQL）

```sql
-- 信箱
create table mailbox (
  box_id      text primary key,              -- "LUMI-XXXXXX"（服务端生成，无歧义字母表）
  read_token  text not null,                 -- 随机 64 hex（服务端生成，仅创建时返回一次）
  created_at  timestamptz not null default now()
);

-- 信件（明信片 payload 复用 MVP 口令编码 LUMI1:base64，含压缩封面 ≤ ~100KB）
create table mail (
  id          bigint generated always as identity primary key,
  to_box      text not null references mailbox(box_id),
  from_box    text,                          -- 可选：发件人邮箱号（用于回执/往来）
  payload     text not null check (length(payload) < 150000),
  delivered   boolean not null default false,
  created_at  timestamptz not null default now()
);
create index on mail (to_box, delivered);

-- 收紧权限：anon 只能调 RPC
revoke all on mailbox, mail from anon;
```

**RPC（security definer，anon 可执行）**

| 函数 | 入参 | 行为 |
|------|------|------|
| `create_mailbox()` | — | 生成 box_id + read_token，插入并**返回两码**（唯一一次） |
| `send_mail(p_to, p_from, p_payload)` | 邮箱号/发件号/载荷 | 校验 to_box 存在 + 载荷限长 + **每箱每日限量（如 200 封）** → insert |
| `fetch_mail(p_box, p_token)` | 邮箱号+读取密钥 | 校验 token → 返回未删信件；**顺手置 delivered=true** |
| `check_delivered(p_box, p_token, p_ids)` | 发件校验 | 返回自己寄出信件的送达状态（按 from_box=p_box 校验） |
| `purge_old()`（pg_cron 每日） | — | 删除 created_at > 30 天的 mail（容量护栏） |

## 4. 客户端（iOS）

- **配置开关**：`Info.plist` 增 `LumiPostURL` / `LumiPostAnonKey` 两键；**空 = 功能整体隐藏**（提审预留分支
  永不配置即保持纯本地；v1.1 分支配置后功能亮起）。
- **服务层** `Lumi/Services/LumiPost.swift`（已落地）：URLSession 直调 PostgREST RPC（无 SDK 依赖，
  不动 SPM/pbxproj）；`identity`（两码）JSON 存 UserDefaults；全部接口在未配置时 no-op。
  `send_mail` 返回信件 id（bigint）→ 客户端记本地台账 `lumi.post.sentLedger`（footprint → [mailID]），
  送达确认进终态缓存 `lumi.post.deliveredIDs` 不再重复查询。
- **UI 接线（已落地）**：
  1. ✅ 明信片墙顶部「我的 Lumi 邮箱号」卡（复制 / 分享 / 一键开通；空态也露出）；
  2. ✅ `PostcardSheet` mini 行增「直寄」→ `DirectSendSheet`（输入邮箱号 / 从往来的人快选）→ `send_mail`，
     成功后 `markShared` 防自弹 + 往来的人记 boxID；
  3. ✅ 明信片墙下拉刷新 / 进页 + App 启动与回前台 `fetch_mail` → 走现有 `PostcardInbox.handle(text:)`（幂等去重复用）；
  4. ✅ 「往来的人」存对方邮箱号（`PostcardContact.boxID`），头像带 ✉ 角标，直寄弹窗内点选即填；
  5. ✅ 足迹详情「已送达 ✓ / 已寄出 · 等待送达」（`check_delivered`，多封显示 n/m）。

## 5. 安全 / 成本 / 滥用护栏

- 读取靠 `read_token`（50+ bit 随机）＝能力密钥；邮箱号公开可寄不可读。
- `send_mail` 限载荷 150KB + 每箱每日限量；30 天 TTL 清理；免费档容量可支撑数万活跃。
- anon key 暴露在客户端是 Supabase 设计内行为（权限已收敛到仅 RPC）。
- 成本：$0（Free）→ 项目 7 天无请求会暂停（上线有真实流量即不会）→ 增长后 Pro $25/mo。

## 6. 上线与分支策略

- `claude/mvp-1.0-submission`：**提审预留冻结**，只收验收 bug 修复；修复后择机 cherry-pick/merge 进 v1.1 分支。
- `claude/v1.1-lumi-post`：v1.1 全部开发；MVP 审核通过后作为 1.1 版本提交。

**接入进度（2026-07-07）**
- ✅ Supabase 项目已建：`https://brxpnharduwacnqkarkr.supabase.co`；`LumiPostURL` 已入 `Lumi/Info.plist`
  （只有 URL 没有 key 时 `isEnabled=false`，功能仍隐藏——半配置是安全态）。
- ⬜ ICY：SQL Editor 整段粘贴执行 [`lumi-post-schema.sql`](lumi-post-schema.sql)
  （建两表 + 4 RPC + 收权限；全新项目直接跑，无需 drop；可选：启用 pg_cron 后执行文件尾注释的 30 天 TTL）。
- ⬜ ICY：把 **anon public** key 发来（Dashboard → Settings → API → Project API keys → `anon` `public`）
  → 补进 Info.plist `LumiPostAnonKey`，功能即亮起。anon key 可公开进客户端（见 §5）。
- ⬜ 双机验收（§7）。提审分支永不配置两键，不受影响。

## 7. 验收要点（真机，双机或双模拟器）

1. A 机启用 → 生成邮箱号；B 机输入 A 的邮箱号寄卡 → A 下拉刷新收到（照片/邮票/节日章原样）。
2. B 机足迹详情显示「已送达 ✓」。
3. 未配置 URL/key 的构建：所有直投 UI 隐藏，带外收发一切如旧。
4. 错误路径：邮箱号不存在 → 友好提示；断网 → 可重试；重复拉取不重复入库（token 幂等）。
