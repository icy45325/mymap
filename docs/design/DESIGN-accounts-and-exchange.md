# Lumi 设计：账号体系 · 数据迁移 · 交换日记/明信片 · IM 分享

> 性质：方向性设计文档（v0.x → v2 的「记忆 / 共创」主线）。配合 [`ROADMAP.md`](../product/ROADMAP.md)、
> [`ios-native-capabilities.md`](../release/ios-native-capabilities.md)、[`REQUIREMENTS.md`](../product/REQUIREMENTS.md) 阅读。
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

> 🧭 **平台决策（已定，ICY 2026-06-25）**：**Android 是确定目标，短期先 iOS**。这直接决定了同步/账号层
> 选型——**不要走 CloudKit**。CloudKit 仅 Apple 生态，上 Android 时个人数据无法跨过去，会被迫做**第二次迁移**。
> 因此账号层一步到位选**跨平台后端（BaaS）**；CloudKit 仅作「若永远 iOS-only」的备选，此处不采用。

迁移有两条路；鉴于上面的平台决策，**采用方案 B**：

### 方案 A —— SwiftData + CloudKit 私有库（❌ 不采用，仅记录）
给 `ModelContainer` 配 `cloudKitDatabase` 即可零后端同步个人数据，跟 Apple ID 走、对用户无感。
**但仅 Apple 生态**，与「要做 Android」冲突，故不选。

> ⚠️ 附带知识点：SwiftData + CloudKit 镜像**不支持 `@Attribute(.unique)`** 且要求字段全可选。
> **由于我们不走 CloudKit，这条硬约束对本项目不成立** —— 当前 4 个模型的 `.unique id` 可以保留。
> （详见 [§6](#6-现在就该做的向前兼容动作) 对该点的最终处理。）

### 方案 B —— 跨平台后端 / BaaS（✅ 采用）
个人数据 + 跨用户社交/IM 都走一套跨平台后端（如 **Supabase**＝Postgres+实时+Auth，关系型社交图谱友好；
或 **Firebase**＝Firestore 实时 + 与谷歌生态协同）。iOS / Android 共用同一后端与数据模型。
迁移方式：本地导出 → 上传 → 服务端**按稳定 UUID 认领**归属到 user，**数据无损**。

### 推荐组合
| 数据 | 归属 | 通道 |
|------|------|------|
| 个人足迹 / 行程 / 明信片 / 心愿 | 本人 | BaaS（私有，按 user 隔离） |
| 好友关系 / IM 消息 / 推荐流 | 跨用户 | BaaS（实时通道） |
| 共同行程 / 交换日记 | 双方 | BaaS（共享记录 + 权限） |

**迁移落地步骤**（加账号那一版）：① 接 BaaS Auth（见 §3）→ ② 首次登录把本地 SwiftData 导出、按 UUID
上传认领 → ③ 之后本地 ↔ 后端双向同步（SwiftData 仍作离线缓存，local-first 体验不变）→ ④ 同一套后端
直接支撑 Android 端。**无 CloudKit、无二次迁移。**

---

## 3. 账号体系（身份层）

- **跨平台身份走 BaaS Auth**（因要支持 Android）：统一 user id 由后端签发，iOS / Android 共用。
- **登录方式**：iOS 端提供 **Sign in with Apple**（Apple 规定：只要提供第三方登录就必须同时提供 Apple 登录）+
  **Google 登录**（天然跨平台，且与「接谷歌内容」协同）；Android 端以 Google 登录为主。后端把这些 OAuth 身份
  归一到同一 user。
- **渐进式身份**：匿名本地用户（上架首版）→ 可选登录 → 登录即「认领」本地数据并开启同步。**登录永远是可选项**，
  不挡住纯本地使用，保住 local-first 体验。
- **归属抽象**：引入「当前用户 / `ownerID`」概念；纯本地阶段恒等于一个匿名本地用户，加账号后替换为真实 user id。
- **付费门槛**：上架 / 推送需 **付费 Apple Developer Program**（v0 免费自签到此为止）；后端另计托管成本。

---

## 4. 交换日记 / 明信片（Exchange & Postcard）

**已有打底**（v0 就埋好的）：`Trip`（行程容器，足迹可归属）、`Card`（明信片，1:1 Footprint，
可缓存导出图 + 多模板 `midnight/passport/minimal`）、设计令牌 `accentRose`（标注用途「情感/交换日记」）。

分三个由轻到重的台阶，**前两阶不需要账号即可上线**：

1. **单机明信片导出 + 口令/二维码「自动接收」（先做，纯本地，无后端）** —— *ICY 2026-06-25 提案*
   - **导出**：`Card` → `ImageRenderer` 渲染成图 → `ShareLink` 分享 / `AirPrint` 打印 / 发 iMessage。
   - **发送方**：把明信片内容编码成一段**分享口令 / universal link**，可「复制链接」或「下载二维码图」，
     走任意渠道（微信/iMessage/相册）发给对方。
   - **接收方**：对方**在 App 内打开该链接**（或粘贴口令 / 扫码）→ App 解码 → **自动接收并存入明信片收藏**。
   - **payload 设计**：明信片字段（地点 / 日期 / 心情 / 模板 / 封面图引用）编码进链接；体积大的封面图先压缩内嵌，
     或仅传「足迹要素」让对方端重渲染。携带发送者昵称与一个**幂等 token**（避免重复接收）。
   - **闭环演进**：此为「**带外传输（out-of-band）**」雏形——先靠用户手动转发链接打通；待 §5 的 IM 上线后，
     同一 payload 改为**站内直接投递**，无需复制粘贴，真正闭环。**先本地、后系统内**正是 ICY 设想的顺序。
2. **共同行程（需身份）**：双人/多人共享一个 `Trip`——用 **CKShare**（CloudKit 共享，零自建后端）
   或后端共享。模型补充：`Trip` 增 `ownerID` / `participants`。

**台阶 2.5 —— 交换日记·带外版 ✅（2026-07-10 已落地，把台阶 3 的仪式感提前到零后端）**
   - **协议**：新口令前缀 `LUMID1:` + base64(JSON)：
     `{v, token(幂等), pairID(配对码), diaryID, title, sender, senderBox?, sealedAt, entries:[{d,t,m?}]}`；
     整本日记（仅文字+心情 emoji）一次性随口令交换，复用明信片四通道
     （剪贴板口令 / 二维码 / lumi://diary 链接+AirDrop `.lumicard` / **Lumi 邮局直投**——mail 表 payload
     本就是不透明字符串，**服务端零改动**）。旧版 App 对新前缀视而不见，干净向后兼容。
   - **状态机（纯本地）**：`draft →(封存,需≥1条,不可撤销)→ sealed →(寄出)→ sentAt`；
     对方口令任意时刻到达都先落 `partnerToken`（**密封壳**，不解码展示）；
     `可拆开 = 已封存 && 有壳`，「拆开」是显式仪式动作 → `exchangedAt`。
     `pairID` 配对：发起方口令带 pairID → 收件方零配置建本 → 寄回自动命中，往返只需一次确认。
   - **模型**：`ExchangeDiary` + `DiaryEntry`（`Lumi/Models/ExchangeDiary.swift`，纯增量轻量迁移；
     留 `tripID` 钩子待台阶 2 绑 `Trip`）。对方条目不落库，从壳现解码。
   - **接受的取舍**：①封存是**产品约定而非密码学保证**（口令 base64 明文，不上密钥交换）；
     ②照片不随口令传（体积会击穿二维码 2953B 上限；QR 通道限口令 ≤2800 字符，超限走复制/邮局），
     照片留在各自本机，站内版（台阶 3）走存储桶再补。
   - **v2 增量（2026-07-10 二次对齐）**：
     ①**从足迹发起**——一个足迹=一段旅程，旅伴（companions）就在足迹上；足迹详情「与旅伴交换日记」
       预填标题/旅伴（默认全选），`ExchangeDiary.footprintID` 关联旅途（列表卡片显示国旗/地点/日期）；
     ②**多人群本**——`DiaryPartner`（名字/邮箱号/密封壳/拆开时间）一对多；**同一 sealToken 全员互寄**，
       payload 带 `others` 名单让收件端零配置建全组（过滤自己）；壳按人落、**逐人拆**，全拆完置 exchangedAt；
       旧 1:1 字段惰性迁移（`DiaryStore.migrateIfNeeded`）；
     ③**人员信息=本地联系人按名弱关联**——旅伴/伙伴名命中「往来的人」带出真头像+邮箱号，
       未命中用首字母默认头像（`PersonAvatar`）。**不依赖好友关系**；v2 账号后联系人补 userID 平滑升级。

3. **交换日志（站内版，需身份+通道）**：带外版基础上升级——照片随日记走存储桶、云端保管与推送提醒；
   同一行程绑定 `Trip`。模型 `DiaryEntry` 已在带外版落地，届时加同步列即可。

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
（见 [`ios-native-capabilities.md`](../release/ios-native-capabilities.md) 合规提醒）。

---

## 6. 现在就该做的「向前兼容」动作（低成本，避免将来返工）

即便首版纯本地，这几件几乎零成本，却能让将来加账号 / 同步 / 分享平滑很多：

1. **保留稳定 UUID 主键**（已有 ✓）—— 将作为后端记录的 remote id，迁移认领的锚点。
2. **`@Attribute(.unique)` 可保留**：因不走 CloudKit（见 §2），其「不支持 unique」的约束对本项目不成立，
   4 个模型现状无需改动。
3. **抽象「当前用户 / `ownerID`」**：现在恒为匿名本地用户，加账号时只换实现。
4. **可同步实体预留 `updatedAt` / 软删除标记**：双向同步与冲突合并的基础（本地优先合并）。
5. **明信片走 `ImageRenderer` + `ShareLink` + 分享口令/二维码**：分享/导出/接收不依赖账号，可最早上线
   （见 §4 的「口令/二维码自动接收」流程）。
6. **预留 deep link / universal link / URL scheme**：明信片接收、Share Extension、IM 回跳都要用。

---

## 7. 落阶段（与 ROADMAP 对齐）

| 能力 | 阶段 | 需后端？ | 依赖 |
|------|------|---------|------|
| 明信片导出 / 打印 / 发 iMessage | v0.x | 否 | `Card` + ImageRenderer/ShareLink |
| 明信片口令/二维码「自动接收」 | v0.x | 否 | universal link + payload 编解码 + 幂等 token |
| 谷歌店铺 Share Extension 导入 | v0.x | 否 | Share Extension + 地点解析 + deep link |
| BaaS Auth（Apple/Google 登录）+ 个人数据同步 + 本地认领 | v1 | **是（BaaS）** | 选型 Supabase/Firebase + 本地导出认领 |
| 共同行程 / 交换日志 | v1 | 是（BaaS） | 身份 + `Trip.participants` + `DiaryEntry` |
| 好友图谱 + App 内 IM 消息 | v2 | 是（BaaS 实时） | 合规（举报/年龄分级） |
| Android 客户端 | v2 | 共用同一 BaaS | 复用后端与数据模型 |
| 推荐旅行地 / 推荐 traveler | v2 | 是 | 后端 + 内容/关系数据 |

---

## 8. 开放问题 / 待定

- ~~CloudKit 还是 BaaS？~~ **已定**：因 Android 是确定目标，账号/同步层走**跨平台 BaaS**，不走 CloudKit（见 §2）。
- **BaaS 选 Supabase 还是 Firebase？** 对比与倾向见 [`DESIGN-baas-selection.md`](DESIGN-baas-selection.md)（倾向 Supabase，待 PoC 拍板）。
- **谷歌内容合规**：优先「接收 share URL / 系统地点」而非直连 Places API；商用条款需复核。
- **VIP 变现 × 账号**：纯本地如何收费、账号化后权益如何承接，见 [`DESIGN-monetization.md`](DESIGN-monetization.md)。
- **VIP 变现与账号的关系**：纯本地版如何收费？账号上线后权益如何承接？（与本文身份层相关，单列商业设计。）
- **交换日记的「仪式」边界**：先写后换 / 是否可撤回 / 是否限同一行程，需产品定义。

---

## 验证 / 下一步

1. 本文为设计文档，**无代码改动**；评审通过后按 §7 拆任务并回填 [`REQUIREMENTS.md`](../product/REQUIREMENTS.md)
   对应的 💡 条目（社交/共享、推荐/行程、交换日志）。
2. **早期技术验证（PoC）**，验证后再决定排期：
   - **明信片口令/二维码自动接收 PoC**：A 设备生成 universal link/二维码 → B 设备打开自动收卡（纯本地、无后端，可最先做）。
   - **Share Extension PoC**：从谷歌地图 App 分享一个店铺 → Lumi 接住并解析成地点卡。
   - **BaaS 同步 spike**（加账号前）：选定 Supabase/Firebase，验证「本地 SwiftData 按 UUID 导出认领 + 双向同步」，
     并确认同一后端可被 Android 复用。
