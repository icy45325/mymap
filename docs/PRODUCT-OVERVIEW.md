# Lumi · 产品概览（Product Overview）

> 一份「一眼看懂 Lumi 是什么、能做什么」的概览。逐条需求与进度见
> [`REQUIREMENTS.md`](REQUIREMENTS.md)，阶段蓝图见 [`ROADMAP.md`](ROADMAP.md)，产品规格见
> [`Lumi_v0_PRD.md`](Lumi_v0_PRD.md)。最后更新：2026-07-05。

## 一句话定位

**Lumi —— 把你去过的地方点亮成一张星图的旅行足迹应用。**
iOS 原生（SwiftUI + SwiftData + MapKit），首版纯本地、无账号，跟随系统的**中 / 英 / 阿**三语（阿语 RTL）。

## 产品介绍

每个人都有一串走过的路，但它们散落在相册和记忆里，很少被认真看见。Lumi 把「去过」这件事变成一个有仪式感的动作：在地图上**点亮**一个国家或城市，它就成为你星图上的一颗星，汇成一条可以回看的时间线、一面成就墙、一本护照本。

Lumi 不做后台 GPS 自动记录——**点亮是手动的、是有意识的纪念**。你也可以从相册一键找回去过的地方：读取照片的位置信息，自动按国家 / 城市归纳成足迹。

除了「自己看」，Lumi 还想承载人与人之间的连接：把一段足迹做成一张**明信片**，用二维码、链接或隔空投送寄给朋友，对方在 App 里即可收下，收进自己的明信片墙。围绕明信片已长出一套**收集体系**：基础 / 地区 / 典藏三层邮票、节日限定章、收件人才能看到的邮局邮戳，全部收进「收集图鉴」。后续再延展账号、好友与共同行程。

**给谁用**：爱旅行、爱记录、在意仪式感与情感连接的人；以及想把「去过多少地方」可视化、可分享的人。

## 核心功能

| # | 功能 | 一句话 | 现状 |
|---|------|--------|------|
| 1 | 地图点亮 | 真实地图上点国家 / 城市即点亮，记录年份，展示世界进度 | ✅ |
| 2 | 星迹时间线 | 按年份回看所有足迹，顶部「今年 N 国 M 城」统计；详情页通栏照片墙 + 多图轮播 | ✅ |
| 3 | 相册找回足迹 | 读照片定位，按城市 / 国家去重，一键把历史去过的地方补成足迹 | ✅ |
| 4 | 成就 / 徽章墙 | 去过的国家 / 城市 / 大洲解锁徽章，添加足迹即弹点亮庆祝，可分享 | ✅（美术打磨中） |
| 5 | 主屏小组件 | 「点亮战绩 / 去过的国旗」两种模式，长按可切；跟随系统语言 | ✅ |
| 6 | 明信片分享 | 3 种样式 + **三层邮票**（基础 / 地区·点亮解锁 / 典藏·Plus）+ 节日限定章（±5 天窗口）+ 收件人可见邮戳；成图（正反并排）/ 链接 / 二维码 / 隔空投送，对方扫码即收 | ✅ |
| 7 | 护照本 | 按国籍真实配色生成护照，封面 + 资料页 + 入境章（**交通方式三态**：航空/陆路/海运，可改）+ 详情**逐国地标暗纹**，可翻阅 | ✅ |
| 8 | 心愿单 | 想去但还没去的地方；可搜索、地图点选，或从「热门目的地」预设一键添加 | ✅ |
| 9 | 个人资料 | 上传头像、设昵称、选国籍；护照本与个人页据此展示 | ✅ |
| 10 | 收集图鉴 | 邮票 / 邮戳 / 节日章成册（36 件），解锁态全派生；点击看放大图与使用规则 | ✅ |
| 11 | 统一主题 & Plus | 终身会员（早鸟 9.9 买断）：主题色（高亮+地图+App 图标整套）/ 主屏小组件 / 典藏邮票 / 明信片去水印高清 | ✅ |

> 状态图例：✅ 已交付　🚧 进行中 / 部分完成　📋 待办　💡 提案。完整台账见 [`REQUIREMENTS.md`](REQUIREMENTS.md)。

## 正在做 / 下一步（节选）

- **真机系统化回归 + 提审**：三语 × 机型照 `QA-REGRESSION.md` 过一遍，Xcode 能力 / ASC 内购配置 / 截图后提审（头号）。🚧
- **阿语母语级润色**：机检已过，建议母语者通读。🚧
- **邮票商店化**：更多国家典藏票、限时上新（首批 14 枚已并入会员权益）。💡
- **v1.1 轻互动「Lumi 邮局」**（上架后首个更新）：明信片站内直投 + 旅友码 + 送达回执——Supabase 免费档 + 匿名身份，$0 起零运维；同一项目直接长成 v1.2 账号底座。📋
- **v1.2 账号 + 同步**：匿名身份原地升级，跨平台 BaaS。📋

## 不做什么（v0 的克制）

- ❌ 后台 GPS 自动记录（与「手动点亮」的哲学冲突）
- ❌ 账号 / 云同步（首版纯本地；账号与跨平台同步走 BaaS，后续上）
- ❌ 视频 / 多媒体（v0 刻意限单图，后续放开）

## MVP 与变现

- **MVP（上架首版）**：纯本地、无账号，聚焦「核心点亮回路 + 明信片分享 + 三语」，变现走**轻 paywall**。详见 [`ROADMAP.md` MVP 章节](ROADMAP.md#mvp--上架首版ios--纯本地--无账号)。
- **变现（已定）**：**终身会员 · 早鸟一次性买断 9.9**（USD/CNY/AED，非订阅，`com.lumi.plus.lifetime`），解锁后续所有迭代；已落地权益 = 典藏邮票 14 枚 / 统一主题（含 App 图标）/ 主屏小组件 / 明信片去水印高清。装饰内购方向并入会员权益，后续可扩独立邮票商店。详见 [`DESIGN-monetization.md`](DESIGN-monetization.md)。
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
