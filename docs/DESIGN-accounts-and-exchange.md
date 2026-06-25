# Lumi 设计：账号体系 · 数据迁移 · 交换日记/明信片 · IM 分享

> 性质：方向性设计文档（v0.x → v2 的「记忆 / 共创」主线）。配合 [`ROADMAP.md`](ROADMAP.md)、
> [`ios-native-capabilities.md`](ios-native-capabilities.md)、[`REQUIREMENTS.md`](REQUIREMENTS.md) 阅读。
> 本文不含代码改动；评审通过后按 [§7 落阶段](#7-落阶段与-roadmap-对齐) 拆任务回填 REQUIREMENTS。

## Context（为什么写这篇）

产品北极星在竞品最弱的「**记忆 / 共创**」象限——完整形态 = 交换日记 + 明信片 + 好友共享 + AI 故事片。
但此前文档只在阶段级（ROADMAP v0.x/v1/v2）点到，**账号体系、本地→账号的数据迁移、交换日记/明信片、
用户间 IM 分享（含把谷歌地图店铺分享进来）这几块从未细化**。这几块强耦合（交换 / IM 都依赖「身份」），
故合并设计。

**核心约束**：v0 现状是 **纯本地、单用户、无账号、免费自签**（profile 7 天过期，无后端）。
本文的第一性问题就是 ICY 提的那句——

> 「VIP 版先上架时没有用户体系、数据只存本地，之后再迭代加用户体系、把本地数据存成一个用户，可行吗？」

---

## 1. 总原则：本地优先（Local-first），账号后置 —— ✅ 可行且推荐

**结论：完全可行，而且是业界主流的稳妥路径**（Things、Bear、很多笔记/记录类 App 都这么走）。
先上「纯本地」版本验证集邮回路，再迭代加账号 + 同步，**老用户的本地数据无损「认领」为他的云端账号**。

可行的前提是「**现在就为将来留好缝**」——几处零成本的向前兼容动作（见 [§6](#6-现在就该做的向前兼容动作)），
否则加账号时会被迫做痛苦的 schema 迁移。下面两节先把「迁移」和「身份」讲透。

---

## 2. 数据迁移：本地 → 账号（这就是可行性的关键）

**现状**：SwiftData 本地库；四个模型 `Footprint / Trip / Card / Wish` 都有稳定主键
`@Attribute(.unique) var id: UUID`。稳定 UUID 是迁移的好底子（记录身份不会变）。

迁移有两条路，**推荐分层组合**：

### 方案 A —— SwiftData + CloudKit 私有库（推荐用于「个人数据」）
原理：给 `ModelContainer` 配 `cloudKitDatabase`，SwiftData 自动把本地库镜像进用户 **iCloud 私有库**，
跟 Apple ID 走，**零自建后端**。老用户首次登录 iCloud 后，本地已有数据自动上行同步——**数据无损、对用户无感**。

> ⚠️ **关键约束（必须现在就知道）**：SwiftData + CloudKit 镜像有硬性要求：
> - **不支持 `@Attribute(.unique)`** —— 当前 4 个模型全用了 `.unique id`，开 CloudKit 前**必须去掉**，
>   改成「应用层按 UUID 去重」。
> - 所有属性需**可选或带默认值**；关系需**可选**。
> - 这条决定了「上架前是否就把模型改成 CloudKit 友好」，强烈建议在加同步前做一次 schema spike（见 §6/验证）。

### 方案 B —— 自建 / BaaS 后端（用于「跨用户社交 / IM」）
个人数据走 A，但**好友、IM 消息、跨用户共享**这类 CloudKit 不擅长的，需要后端（自建或 Supabase/Firebase）。
迁移方式：本地导出 → 上传 → 服务端按 UUID 认领归属到 user。

### 推荐组合
| 数据 | 归属 | 通道 |
|------|------|------|
| 个人足迹 / 行程 / 明信片 / 心愿 | 本人 | CloudKit 私有库（方案 A） |
| 好友关系 / IM 消息 / 推荐流 | 跨用户 | 后端 / BaaS（方案 B，社交阶段才上） |
| 共同行程 / 交换日记 | 双方 | CKShare（轻）或后端 |

**迁移落地步骤**（加账号那一版）：① schema 改 CloudKit 友好（去 `.unique` 等）→ ② 接 Sign in with Apple →
③ 开 CloudKit 私有库，本地数据自动上行 → ④（社交阶段）把需要共享的实体投到后端并按 UUID 认领。

---

## 3. 账号体系（身份层）

- **主身份推荐 Sign in with Apple**：零摩擦、隐私友好、与「个人/家庭记忆」气质一致、Apple 审核友好
  （一旦提供任何第三方登录，Apple 要求必须同时提供 Apple 登录）。
- **渐进式身份**：匿名本地用户（上架首版）→ 可选登录 → 登录即「认领」本地数据并开启同步。**登录永远是可选项**，
  不挡住纯本地使用，保住 local-first 体验。
- **归属抽象**：引入「当前用户 / `ownerID`」概念；纯本地阶段恒等于一个匿名本地用户，加账号后替换为真实 user id。
- **付费门槛**：CloudKit / 推送 / 后端都需 **付费 Apple Developer Program**（v0 免费自签到此为止）。

---

## 4. 交换日记 / 明信片（Exchange & Postcard）

**已有打底**（v0 就埋好的）：`Trip`（行程容器，足迹可归属）、`Card`（明信片，1:1 Footprint，
可缓存导出图 + 多模板 `midnight/passport/minimal`）、设计令牌 `accentRose`（标注用途「情感/交换日记」）。

分三个由轻到重的台阶，**前两阶不需要账号即可上线**：

1. **单机明信片导出（先做，纯本地）**：`Card` → `ImageRenderer` 渲染成图 → `ShareLink` 分享 /
   `AirPrint` 打印 / 发 iMessage。把「点亮成果」变成社交货币，零后端。
2. **共同行程（需身份）**：双人/多人共享一个 `Trip`——用 **CKShare**（CloudKit 共享，零自建后端）
   或后端共享。模型补充：`Trip` 增 `ownerID` / `participants`。
3. **交换日志（仪式感，需身份+通道）**：同一行程下双方**各自先写**心情 → 行程结束后**互相解锁**对方的日志
   （「先封存、后交换」的仪式）。模型补充：`DiaryEntry`（per user per trip，先本地后同步）。

---

## 5. IM 即时通讯 / 内容分享（ICY 说的「接 IM」）

**目标**：用户间在 App 内分享「旅行地点 / 好吃的店铺」；并能把**谷歌地图上的店铺直接分享进 Lumi**，
形成「外部内容 → 自己收藏 → 转发好友」的闭环。

两类分享，技术依赖差异很大：

### a. 外部内容导入（依赖低、价值高 —— 建议早做）
- **iOS Share Extension**：在谷歌地图 App 里点「分享」某店铺 → 选 Lumi → 拿到分享的 URL / 地点信息 →
  解析成地点卡（坐标 / 名称 / 类别），可直接「点亮 / 加心愿 / 转发」。
- **纯客户端即可实现，不需后端**，与现有「相册按位置生成足迹」「真实地图点亮」一脉相承。
- 注意：解析谷歌分享链接要走 ToS 合规（优先解析 share URL / 系统 PlaceDescriptor，谨慎用 Places API）。

### b. App 内 IM 消息（依赖高 —— 社交阶段）
- 好友间发送「地点卡 / 店铺卡 / 明信片」消息，需要 **好友图谱 + 消息通道**。CloudKit 不适合实时 IM →
  需要后端 / BaaS。
- **过渡方案（不自建）**：先用 **iMessage（MSMessages 扩展 / ShareLink + deep link）** 做「半 IM」——
  把卡片发到系统聊天里，对方点 deep link 回跳 Lumi 直接「加心愿 / 点亮 / 查看」。先验证分享意愿，再决定是否自建实时 IM。
- **闭环**：所有分享卡片携带 **deep link / universal link**，对方一点即落地到对应动作。

### 合规
UGC + 社交必带**举报 / 屏蔽 / 拉黑**，且触发 Apple **2026 年中**起的儿童安全与年龄分级问卷
（见 [`ios-native-capabilities.md`](ios-native-capabilities.md) 合规提醒）。

---

## 6. 现在就该做的「向前兼容」动作（低成本，避免将来返工）

即便首版纯本地，这几件几乎零成本，却能让将来加账号 / 同步 / 分享平滑很多：

1. **保留稳定 UUID 主键**（已有 ✓）。
2. **评估去掉 `@Attribute(.unique)`**：4 个模型都用了，是 CloudKit 的硬冲突项；改为应用层按 UUID 去重。
3. **新增字段一律可选 / 带默认值，关系可选**（CloudKit 友好），从现在的新模型就遵守。
4. **抽象「当前用户 / `ownerID`」**：现在恒为匿名本地用户，加账号时只换实现。
5. **明信片走 `ImageRenderer` + `ShareLink`**：分享/导出不依赖账号，可最早上线。
6. **预留 deep link / URL scheme**：分享卡片回跳的基础设施，Share Extension 与 IM 都要用。

---

## 7. 落阶段（与 ROADMAP 对齐）

| 能力 | 阶段 | 需后端？ | 依赖 |
|------|------|---------|------|
| 明信片导出 / 打印 / 发 iMessage | v0.x | 否 | `Card` + ImageRenderer/ShareLink |
| 谷歌店铺 Share Extension 导入 | v0.x | 否 | Share Extension + 地点解析 + deep link |
| Schema 改 CloudKit 友好（去 `.unique`/全可选） | v1 前置 | 否 | 一次性迁移 spike |
| Sign in with Apple + 个人数据 CloudKit 同步 + 本地认领 | v1 | iCloud | 付费 Developer Program |
| 共同行程 / 交换日志 | v1 | CKShare 或后端 | 身份 + `Trip.participants` + `DiaryEntry` |
| 好友图谱 + App 内 IM 消息 | v2 | 是 | 后端/BaaS + 合规（举报/年龄分级） |
| 推荐旅行地 / 推荐 traveler | v2 | 是 | 后端 + 内容/关系数据 |

---

## 8. 开放问题 / 待定

- **CloudKit 还是自建/BaaS？** CloudKit = 零后端、隐私、但仅 Apple 生态、IM 弱；后端 = 跨平台 + IM 灵活、
  但要运维与合规。**是否要 Android / Web 基本决定这个选择**。建议：个人数据 CloudKit，社交/IM 用后端，混合。
- **谷歌内容合规**：优先「接收 share URL / 系统地点」而非直连 Places API；商用条款需复核。
- **VIP 变现与账号的关系**：纯本地版如何收费？账号上线后权益如何承接？（与本文身份层相关，单列商业设计。）
- **交换日记的「仪式」边界**：先写后换 / 是否可撤回 / 是否限同一行程，需产品定义。

---

## 验证 / 下一步

1. 本文为设计文档，**无代码改动**；评审通过后按 §7 拆任务并回填 [`REQUIREMENTS.md`](REQUIREMENTS.md)
   对应的 💡 条目（社交/共享、推荐/行程、交换日志）。
2. 两个**早期技术验证（PoC）**，验证后再决定排期：
   - **Schema spike**：把模型改成「去 `.unique` + 全可选」并开 CloudKit 私有库，验证本地数据无损上行同步。
   - **Share Extension PoC**：从谷歌地图 App 分享一个店铺 → Lumi 接住并解析成地点卡。
