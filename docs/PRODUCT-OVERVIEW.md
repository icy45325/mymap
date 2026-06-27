# Lumi · 产品概览（Product Overview）

> 一份「一眼看懂 Lumi 是什么、能做什么」的概览。逐条需求与进度见
> [`REQUIREMENTS.md`](REQUIREMENTS.md)，阶段蓝图见 [`ROADMAP.md`](ROADMAP.md)，产品规格见
> [`Lumi_v0_PRD.md`](Lumi_v0_PRD.md)。最后更新：2026-06-27。

## 一句话定位

**Lumi —— 把你去过的地方点亮成一张星图的旅行足迹应用。**
iOS 原生（SwiftUI + SwiftData + MapKit），首版纯本地、无账号，跟随系统的**中 / 英 / 阿**三语（阿语 RTL）。

## 产品介绍

每个人都有一串走过的路，但它们散落在相册和记忆里，很少被认真看见。Lumi 把「去过」这件事变成一个有仪式感的动作：在地图上**点亮**一个国家或城市，它就成为你星图上的一颗星，汇成一条可以回看的时间线、一面成就墙、一本护照本。

Lumi 不做后台 GPS 自动记录——**点亮是手动的、是有意识的纪念**。你也可以从相册一键找回去过的地方：读取照片的位置信息，自动按国家 / 城市归纳成足迹。

除了「自己看」，Lumi 还想承载人与人之间的连接：把一段足迹做成一张**明信片**，用二维码、链接或隔空投送寄给朋友，对方在 App 里即可收下，收进自己的明信片墙。后续会延展出账号、好友、共同行程与装饰内购（邮票 / 邮戳收集）。

**给谁用**：爱旅行、爱记录、在意仪式感与情感连接的人；以及想把「去过多少地方」可视化、可分享的人。

## 核心功能

| # | 功能 | 一句话 | 现状 |
|---|------|--------|------|
| 1 | 地图点亮 | 真实地图上点国家 / 城市即点亮，记录年份，展示世界进度 | ✅ |
| 2 | 星迹时间线 | 按年份回看所有足迹，顶部「今年 N 国 M 城」统计；详情页通栏照片墙 + 多图轮播 | ✅ |
| 3 | 相册找回足迹 | 读照片定位，按城市 / 国家去重，一键把历史去过的地方补成足迹 | ✅ |
| 4 | 成就 / 徽章墙 | 去过的国家 / 城市 / 大洲解锁徽章，添加足迹即弹点亮庆祝，可分享 | ✅（美术打磨中） |
| 5 | 主屏小组件 | 「点亮战绩 / 去过的国旗」两种模式，长按可切；跟随系统语言 | ✅ |
| 6 | 明信片分享 | 足迹做成明信片 → 成图 / 链接 / 二维码 / 隔空投送；对方扫码即收，收进明信片墙 | ✅ |
| 7 | 护照本 | 按国籍真实配色生成护照，封面 + 个人信息页 + 入境章，可翻阅 | 🚧 |
| 8 | 心愿单 | 想去但还没去的地方；可搜索、地图点选，或从「热门目的地」预设一键添加 | ✅ |
| 9 | 个人资料 | 上传头像、设昵称、选国籍；护照本与个人页据此展示 | ✅ |

> 状态图例：✅ 已交付　🚧 进行中 / 部分完成　📋 待办　💡 提案。完整台账见 [`REQUIREMENTS.md`](REQUIREMENTS.md)。

## 正在做 / 下一步（节选）

- **明信片样式 + 邮票**：发送时可选 3 种样式 + 2 种邮票，外观随口令传给接收方，明信片墙按样式呈现（方案已定，全 SwiftUI 原生绘制）。🚧
- **护照本完善**：入境章详情页 + 各国风格暗纹底纹。💡
- **选城市流程**：点完国家可继续选城市（可跳过）。📋

## 不做什么（v0 的克制）

- ❌ 后台 GPS 自动记录（与「手动点亮」的哲学冲突）
- ❌ 账号 / 云同步（首版纯本地；账号与跨平台同步走 BaaS，后续上）
- ❌ 视频 / 多媒体（v0 刻意限单图，后续放开）

## MVP 与变现

- **MVP（上架首版）**：纯本地、无账号，聚焦「核心点亮回路 + 明信片分享 + 三语」，变现走**轻 paywall**。详见 [`ROADMAP.md` MVP 章节](ROADMAP.md#mvp--上架首版ios--纯本地--无账号)。
- **方向**：Plus 订阅 + 装饰内购（邮票 / 邮戳 / 节日章收集）。详见 [`DESIGN-monetization.md`](DESIGN-monetization.md)。
- **跨平台**：已确定要做 Android，账号 / 同步层因此选**跨平台 BaaS（非 CloudKit）**，两端复用。详见 [`DESIGN-baas-selection.md`](DESIGN-baas-selection.md)。

## 技术基调

- **平台**：iOS 17+，SwiftUI + SwiftData（`@Model` / `@Query`）+ MapKit。
- **数据**：足迹坐标一律存 WGS-84；国家归属用离线 point-in-polygon 解析；单一共享 `LumiStore`。
- **小组件**：WidgetKit + App Group 快照（App 在数据变更时写快照、刷新时间线）。
- **本地化**：String Catalog（`.xcstrings`），源语言中文，英 / 阿三语。

## 文档地图

| 文档 | 内容 |
|------|------|
| [`PRODUCT-OVERVIEW.md`](PRODUCT-OVERVIEW.md) | 本文：产品概览 + 核心功能 |
| [`REQUIREMENTS.md`](REQUIREMENTS.md) | 逐条需求台账 + 进度（单一事实源）|
| [`ROADMAP.md`](ROADMAP.md) | 阶段级蓝图 + MVP 范围 |
| [`MVP-PLAN.md`](MVP-PLAN.md) | MVP 执行批次与进度 |
| [`Lumi_v0_PRD.md`](Lumi_v0_PRD.md) | v0 产品需求规格 |
| [`APPSTORE-LISTING.md`](APPSTORE-LISTING.md) | App Store 上架文案（三语）+ 截图清单 |
| [`APP-PRIVACY-AND-SUBMISSION.md`](APP-PRIVACY-AND-SUBMISSION.md) | App 隐私标签 + 提审清单 |
| [`QA-REGRESSION.md`](QA-REGRESSION.md) | 提审前真机回归测试脚本（三语 × 全路径）|
| [`legal/`](legal/) | 隐私政策 / 使用条款 / 支持页（可托管 HTML，三语）|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 工程架构 |
| [`DESIGN-accounts-and-exchange.md`](DESIGN-accounts-and-exchange.md) | 账号体系 / 数据迁移 / 交换日记·明信片 / IM 分享 |
| [`DESIGN-monetization.md`](DESIGN-monetization.md) | 变现设计（Plus / 装饰内购）|
| [`DESIGN-baas-selection.md`](DESIGN-baas-selection.md) | 跨平台 BaaS 选型 |
| [`ios-native-capabilities.md`](ios-native-capabilities.md) | iOS 系统能力设想 |
| [`widget-app-intent-setup.md`](widget-app-intent-setup.md) | 小组件 App Intent 配置 |
