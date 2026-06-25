# Lumi MVP 执行计划（上架首版排期）

> MVP 范围与定位见 [`ROADMAP.md` MVP 章节](ROADMAP.md#mvp--上架首版ios--纯本地--无账号)。
> 本文把 MVP 拆成可执行批次、定先后与依赖。状态随推进更新。

## 现状盘点（开工前的事实）

- ✅ **大部分 MVP 功能已写**：点亮 / 真实地图点选 / 时间线+编辑 / 成就 / 心愿单 / 相册导入 /
  点亮计数 & 去年今日小组件 / 中英阿三语。
- ⚠️ **但这些改动从未在 Xcode 编译 / 真机验证过**（i18n、真实地图、导入、心愿单、小组件等多批）。**这是头号风险**。
- 🔨 **三块是从零**：① 明信片渲染 + 导出 + 口令/二维码分享（`Card` 仅持久化，无任何 UI）；
  ② 变现（无 StoreKit / RevenueCat / paywall）；③ deep link / URL scheme（无 `onOpenURL`、无 URL types）。
- ✅ App 图标已做；`CountryInfo.flag` 国旗 emoji 可复用于国旗小组件。

工作量图例：**S**＝半天内 · **M**＝1–3 天 · **L**＝1 周量级（含设计/调试）。

---

## 批次与顺序

### B0 · 编译验证与基线打磨 —— 🥇 最先做，阻塞一切
> 先让整条分支真机跑通，再加新功能；否则在未验证地基上叠加只会放大问题。

- [ ] Xcode 打开、`⌘B` 编译整分支，修所有编译错误（重点：i18n 的 `.localized`/catalog、真实地图、导入）
- [ ] 真机冒烟：四 Tab、点亮、足迹编辑、相册导入、心愿单、小组件；**切系统语言中/英/阿，验证 RTL**
- [ ] 校对英/阿译文（catalog 未匹配键回填；阿语语序）
- [ ] 已实现功能体验打磨清单（空态 / 边界 / 动效 / 触感）

**产出**：一个能在真机稳定跑的基线。**工作量 M**（视 bug 数）。

### B1 · 小组件补全 —— 快速见效，独立
- [ ] **国旗模式小组件**：展示去过国家国旗集合，最多 5 个（复用快照 `litCountryCodes` + `CountryInfo.flag`；
      新增一个 widget 或在现有族里加模式）
- [ ] **设置页小组件介绍**：设置页加引导（如何添加、各模式说明）

**文件**：`LumiWidgets/*`、`Settings/SettingsView.swift`。**工作量 S–M**。

### B2 · 徽章美术优化 —— 独立，偏设计
- [ ] `HexBadge` 视觉重做（稀有度配色 / 质感 / 锁定态对比）
- [ ] 蜂巢排布与点击态微调

**文件**：`Stats/`（HexBadge、StatsView）。**工作量 M**（需先定美术方向）。

### B3 · 明信片导出 + 口令/二维码分享 —— 🧱 MVP 最大特性，从零
> 自传播的核心。先做 spike 去 deep-link 的风险，再做渲染与收发闭环。

- [ ] **B3.0 spike**：universal link / URL scheme + `onOpenURL`/`onContinueUserActivity` 回跳通路打通
      （A 生成链接 → B 点开命中 handler）。**先行去风险。**
- [ ] **B3.1 渲染**：`PostcardView`（按 `Card.templateID` 渲染足迹）+ `ImageRenderer` 导出图
- [ ] **B3.2 导出/分享**：`ShareLink` 分享图 / 存相册 / `AirPrint`；`CIQRCodeGenerator` 生成二维码
- [ ] **B3.3 payload 编解码**：足迹要素编进 link（+ **幂等 token** 防重复 + 发送者昵称；封面图压缩内嵌或对端重渲染）
- [ ] **B3.4 接收**：解析 link → 自动建足迹/卡 + **按 token 去重** + 接收提示

**文件**：新 `Features/Postcard/`、App 层 URL 处理、`Info.plist`（URL types / associated domains）。**工作量 L**。

### B4 · 变现 —— ✅ MVP 即带「轻 paywall」（已定）
- [ ] StoreKit 2 接入 + 商店产品配置（Lumi Plus 月/年 + 终身买断）
- [ ] **RevenueCat 接入**（跨平台 entitlement，为 Android 打底）
- [ ] Plus 门控：高清导出 / 全部明信片模板 / 国旗等额外小组件 / 地图皮肤
- [ ] Paywall UI + **恢复购买** + 自动续订条款

**文件**：新 `Features/Paywall/`、purchase 服务层。**工作量 L**。**决策**：见下「待拍板」。

### B5 · 上架准备 —— 中段起并行，最后收尾
- [ ] 付费 Apple Developer Program + App Store Connect 建 App
- [ ] 截图（中/英/阿 × 机型）+ 预览；本地化元数据（标题/关键词/描述 三语）
- [ ] 隐私营养标签（纯本地 + 相册权限）+ **隐私政策页 / 支持页 URL**
- [ ] 定价分层（中东 / 全球）
- [ ] TestFlight 外测 → 提审

**工作量 M**（以非编码为主）。

---

## 建议节奏（4 个迭代，solo 估算，不设硬日期）

| 迭代 | 主线 | 并行 |
|------|------|------|
| **S1** | B0 编译验证 + 基线打磨 | 起 B3.0 deep-link spike |
| **S2** | B3.1/B3.2 明信片渲染 + 导出 | B1 小组件 + B2 徽章美术（快速见效） |
| **S3** | B3.3/B3.4 分享 + 接收闭环 | B5 截图/元数据起步 |
| **S4** | B4 变现（若带 paywall）| B5 收尾 → TestFlight → 提审 |

**关键路径**：B0 → B3 → B5（提审）。B1/B2/B4 围绕关键路径填空。

---

## 上架 Gate（Definition of Done）

- 真机三语（中/英/阿）全流程无崩溃；阿语 RTL 正确。
- 明信片可导出图 + 生成二维码/链接，**另一台设备打开能自动收卡**（B3 闭环跑通）。
- （若带 paywall）购买 / 恢复购买 / 条款合规可用。
- App Store 元数据、隐私标签、隐私政策/支持页、定价齐备；TestFlight 通过。

---

## 待拍板

1. ✅ **已定（2026-06-25）**：MVP 带 **轻 paywall** —— 核心集邮回路免费，Plus 卖高清导出 / 全部明信片模板 /
   国旗等额外小组件 / 地图皮肤。B4 纳入 MVP，但 paywall 保持轻。
2. 🔲 **徽章美术方向**：仍需你给风格参考，否则 B2 难落地。
3. ✅ **已定（2026-06-25）**：视频上传（≤3min）**不进 MVP**，归 **Plus / 快速跟进**（MVP 后随即做）。

> 拍板后把对应条目状态回填 [`REQUIREMENTS.md`](REQUIREMENTS.md)。
