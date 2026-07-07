# Lumi BaaS 选型：Supabase vs Firebase

> 技术选型决策文档。前置结论见 [`DESIGN-accounts-and-exchange.md` §2](DESIGN-accounts-and-exchange.md#2-数据迁移本地--账号这就是可行性的关键)：
> 因 **Android 是确定目标**，账号/同步层走**跨平台 BaaS（不走 CloudKit）**。本文在两大候选间做对比并给倾向，
> 最终决策记录在 [§6](#6-决策记录)。无代码改动。

## Context

加账号那一版需要一个后端同时承担：**个人数据跨设备/跨平台同步** + **跨用户社交（好友 / IM / 共享行程 / 交换日记）**。
自建后端运维重，故选 BaaS。市面成熟且 iOS+Android 双端 SDK 完善的主要是 **Supabase** 与 **Firebase**。

---

## 1. Lumi 对 BaaS 的需求清单

| # | 需求 | 说明 |
|---|------|------|
| R1 | 跨平台 | iOS + Android 共用同一后端与数据模型 |
| R2 | Auth | Apple 登录 + Google 登录，归一到同一 user |
| R3 | 个人数据同步（离线优先） | 足迹/行程/明信片/心愿；本地仍用 SwiftData 作离线缓存 |
| R4 | 社交图谱 | 好友关系、关注、共享授权 |
| R5 | 实时 IM | 用户间发地点/店铺/明信片消息 |
| R6 | 共享记录 + 行级权限 | 共同行程 / 交换日记，按参与者授权可见 |
| R7 | 对象存储 | 明信片图、（后续）≤3min 视频 |
| R8 | 成本可控 + 低锁定 + 合规可移植 | 早期省钱、避免被单一厂商绑死、数据可迁出 |

---

## 2. 对比表

| 维度 | Supabase（Postgres） | Firebase（Firestore） |
|------|----------------------|------------------------|
| **数据模型** | 关系型 SQL，**社交图谱/多表关联天然契合**（R4/R6） | 文档型 NoSQL，关系/联表查询别扭，社交图谱需反范式建模 |
| **权限模型** | **行级安全 RLS**，按 user/参与者授权干净直接（R6 极契合） | Security Rules（函数式），可行但复杂共享授权更繁琐 |
| **离线优先 SDK** | **无内置离线同步**，需自建（已有 SwiftData 本地兜底；或接 PowerSync） | **Firestore 自带离线缓存 + 自动同步**（iOS/Android 成熟，R3 省事） |
| **实时（R5 IM）** | Realtime：Postgres 变更流 + Broadcast + Presence | 实时监听成熟、低延迟 |
| **Auth（R2）** | GoTrue，支持 Apple/Google | Firebase Auth，支持 Apple/Google，移动接入最顺 |
| **对象存储（R7）** | Supabase Storage（S3 兼容） | Cloud Storage for Firebase |
| **移动 DX** | Swift / Kotlin SDK，较年轻但够用 | iOS/Android SDK **最成熟**，文档生态庞大 |
| **成本** | 偏**固定层级**，规模化更可预测；Postgres 自带能力多 | 按读写/存储计费，**读多时规模化可能偏贵**；免费额度慷慨 |
| **锁定 / 可移植** | **开源、Postgres 标准、可自托管**，低锁定（R8 强） | Google 专有，迁出成本高 |
| **谷歌生态协同** | 无特别协同 | 与「接谷歌内容」同生态（非必需，弱加分） |
| **数据驻留 / 合规** | 可选区域 + **可自托管**，对中东/特定合规更可控 | 多区域，但托管在 Google |

---

## 3. 关键权衡

- **社交是 Lumi 的北极星**（好友/共享/交换日记/IM），而社交本质是**关系型 + 行级授权**——这正是
  **Postgres + RLS（Supabase）最擅长**的；Firestore 做复杂共享授权与关系查询会越用越别扭。
- Firebase 的最大优势是 **Firestore 内置离线 SDK**（R3 省事），但 Lumi **本来就 local-first（SwiftData 兜底）**，
  「登录后按 UUID 同步」这条路我们要自己定义同步语义，离线优势被**部分抵消**。
- **低锁定 / 可移植 / 可自托管**对一个要长期演进、且可能有地区合规诉求的产品是实在的战略价值（Supabase 占优）。
- 成本上 Supabase 的固定层级在「读多」的社交 feed 场景更可预测。

---

## 4. 倾向建议

**倾向 Supabase**，因为 Lumi 的重心是**关系型社交 + 行级权限 + 可移植**，与 Postgres/RLS 高度契合；
主要风险是**离线同步要自己搭**——但已被「SwiftData 本地优先 + 登录后按 UUID 同步」的既定架构缓解，
必要时再引入 PowerSync 等离线层。

**若团队更看重**「最快上手 + 最成熟的移动离线开箱即用 + 不想碰 SQL/RLS」→ **选 Firebase**。

> 一句话决策维度：**社交关系复杂度（偏 Supabase） vs 上手速度与离线即用（偏 Firebase）**。

---

## 5. PoC 验证（拍板前）

用 Lumi 的**真实最小社交场景**各搭一个原型对比，而非看文档拍脑袋：

1. **Auth**：Apple + Google 登录归一到一个 user。
2. **同步**：本地 SwiftData 一条足迹 → 按 UUID 上行 → 另一设备拉回（验证 R3 同步语义 + 冲突合并）。
3. **共享 + 权限**：A 建共同行程、邀 B；验证 RLS / Security Rules 让「仅参与者可见」（R6）。
4. **实时消息**：A→B 发一条「地点卡」消息，B 实时收到（R5）。
5. 记录两边的**接入工时、权限实现复杂度、预估成本曲线**。

---

## 6. 决策记录

| 日期 | 决策 | 依据 | 决策人 |
|------|------|------|--------|
| 2026-06-25 | 走跨平台 BaaS（排除 CloudKit） | Android 为确定目标 | ICY |
| _待定_ | Supabase / Firebase 最终选择 | 待 §5 PoC | — |

> 选定后回填本表，并更新 [`DESIGN-accounts-and-exchange.md`](DESIGN-accounts-and-exchange.md) §2/§7 的「BaaS」占位为具体产品。
