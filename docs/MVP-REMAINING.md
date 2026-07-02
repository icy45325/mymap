# Lumi MVP 遗留事项（上架前清单）

> 上架首版**还差什么**集中一页。**打包/后台逐项怎么配见 [`BUILD-CONFIG.md`](BUILD-CONFIG.md)**。
> 逐批排期见 [`MVP-PLAN.md`](MVP-PLAN.md)，逐条台账见 [`REQUIREMENTS.md`](REQUIREMENTS.md)。
> 图例：✅ 完成 · 🚧 进行中 · 🔲 未开始。最后更新 **2026-07-02**。

## 一句话现状

功能侧（点亮回路 / 时间线 / 成就+统计报告 / 心愿单 / 相册导入 / 小组件 / 明信片收发+样式邮票+**节日限定章** / 护照 / 三语徽章 / Sign in with Apple 登录）**已就绪**，代码全部在分支 `claude/project-docs-progress-xncg1m`。
付费开发者账号**已开通**（B1✅）。**关键路径只剩 3 件**：① 真机系统化回归 + 复验（见 [`ACCEPTANCE.md`](ACCEPTANCE.md) 与下方「本轮新增待验收」）→ ② **能力/变现配置**（Xcode 能力 + StoreKit + ASC 终身买断一档，见下「🔴」/`BUILD-CONFIG.md`）→ ③ 截图/元数据/法务页 + 提审。

> **变现模型已定：终身会员（早鸟）一次性买断**，`com.lumi.plus.lifetime` @9.9（USD/CNY/AED），**非订阅、不自动续费**，解锁后续所有功能迭代。`Lumi.storekit` 已改为 Non-Consumable。
> **App Group 已从 `group.com.lumi.v0`（全球被占用、描述文件不支持）改为 `group.com.lumi.fun`**——两个 target 的 Capability 都要勾它、去掉旧的。

---

## 🔴 当前最容易卡住的：StoreKit 看不到内购

代码与 `Lumi.storekit` 都没问题，是 **scheme 没指向 StoreKit 配置**。
本地：Edit Scheme → Run → Options → **StoreKit Configuration = `Lumi.storekit`**。
上架：在 App Store Connect 建同 ID 的**终身买断（非消耗型）**内购。**完整步骤见 [`BUILD-CONFIG.md`](BUILD-CONFIG.md) 顶部**。

---

## A. 代码 / 文档侧（我能做）

| # | 事项 | 状态 | 说明 |
|---|------|------|------|
| A1 | 明信片样式/邮票 | ✅ | 3 样式（复古/现代/插画）+ 邮票（空运/陆运/海运），随口令传达、墙按样式呈现 |
| A2 | 护照本完善 | 🚧 | 整页放大/资料页已做；可继续：入境章逐国暗纹 |
| A3 | 英/阿译文校对 | 🚧 | 已机检：374 条全有三语、格式符一致、无漏译（仅品牌名 en==ar）；母语级阿语润色仍建议人过一遍 |
| A4 | 体验打磨收尾 | 🚧 | 触感反馈已全面铺开（切Tab/点亮/收发卡/心愿/导入/选择/置顶/登录登出，19 处）；空态已确认一致；剩动效细节可继续 |
| A7 | 新版本提示 + 本次更新弹窗 | ✅ | iTunes Lookup 检测 + What's New（零后端），见 `ROADMAP.md` |
| A8 | 分享到 Instagram（Feed 高清）| ✅ | 明信片/报告/徽章；个性化展示台（小组件双尺寸+护照封面占位）|
| A5 | `ITSAppUsesNonExemptEncryption=NO` | ✅ | 已写进 `Lumi/Info.plist` |
| A6 | 徽章美术 | ✅ | 15 枚三语插画徽章（中/英/阿各一版）+ 名字对齐图上印字 |

## B. 必须 ICY 操作——账号 / 后台 / 实拍（详见 `BUILD-CONFIG.md`）

| # | 事项 | 状态 |
|---|------|------|
| B1 | 付费 Apple 开发者账号 | ✅ 已开通 |
| B2 | Xcode 能力：App Groups(两 target) + **Sign in with Apple** + In-App Purchase | 🔲 |
| B3 | scheme 设 StoreKit Configuration（本地看到套餐） | 🔲 |
| B4 | App Store Connect 建 App + **终身买断（非消耗型）**一档 `com.lumi.plus.lifetime` @9.9（USD/CNY/AED）+ 价格分层 | 🔲 |
| B5 | 沙盒/真机购买 + 恢复购买验证 | 🔲 |
| B6 | 开 GitHub Pages 托管法务页（paywall 已指向） | 🔲 |
| B7 | 截图（6.7"/6.1" 三语）+ 元数据 | 🔲 |
| B8 | TestFlight → 提审（隐私 Data Not Collected，4+） | 🔲 |

## C. 质量关——上架前必过（合作）

| # | 事项 | 状态 |
|---|------|------|
| C1 | **三语 × 机型系统化回归**（照 `QA-REGRESSION.md`） | 🔲 头号 |
| C2 | 本批验收（见 `ACCEPTANCE.md`） | 🔲 |
| C3 | 英文/中文系统语言已修复（zh-Hans 根因），清装复验一次 | ⚠️ 待复验 |

---

## ⭐ 本轮新增 / 变更（代码已入库，⚠️ **全部待真机 Clean Build 验收**）

> 均在分支 `claude/project-docs-progress-xncg1m`。Linux 端无法编译，需 ICY 在 Mac 上 Clean Build（改了 entitlements 需删机重装）逐项确认。

| # | 变更 | 关键验收点 |
|---|------|-----------|
| N1 | **App Group 改 `group.com.lumi.fun`**（旧 `.v0` 全球被占用） | 两 target 勾新 group、删旧的；点亮后小组件计数即时 +1 |
| N2 | **变现改终身会员（早鸟一次性买断）** `com.lumi.plus.lifetime` @9.9，非订阅 | Paywall 文案/CTA、设置页「终身会员·早鸟」、购买+恢复 |
| N3 | 明信片二维码中心 logo 改实心白底遮挡 | 相机扫码 + 相册识别都能收到 |
| N4 | **自己发自己收**：接收区分来源（剪贴板被动跳过自分享；扫码/链接主动可收） | 自己寄自己扫码能收；真去重不重复收 |
| N5 | 明信片正面显示相册新选照片（修 coverAssetID=nil 清空 bug） | 选相册图→正面正常显示 |
| N6 | 明信片朝向三分：宽>高取16:9 / 宽<高取3:4 / 近方1:1（邮票在底） | 三种比例图各发一张看版式 |
| N7 | 寄语输入框字体与卡面一致；邮戳仅收件人可见 | 输入区字体=卡面；寄出前无戳，收到才有 |
| N8 | **节日限定章**（6 枚线条贴图，按足迹地区+寄出日期窗口匹配，仅收件人可见） | 中东/中国/欧美足迹调到对应节日日期收卡看章 |
| N9 | **分享图正反并排**：竖版左右（左正/右背）、横版上下 + 霓虹底 + Lumi 标 | 竖/横各分享一张看布局；Plus 去标 |
| N10 | 首页 highlights 点击进足迹详情（返回回主页） | 点精彩瞬间→详情→返回 |
| N11 | Me 页顶部统计行去掉；明信片墙加数量统计 | 我的页顶部、明信片墙顶部 |
| N12 | Awards：去 UN 统计数、标题+分享同行居中、模块间距/小标题字号统一、去徽章置顶 | 成就页整体版式 |
| N13 | Footprints 顶部年份去千分位（2,025→2025） | 星迹页年份卡 |

---

## 明确**不进** MVP 首版（已拍板）

- 真账号 / 云端 / 跨设备同步、真好友系统（首版纯本地；Sign in with Apple 仅本地登录态，云端留 v1，需后端）。
- 服务端可更新内容（徽章/样式/邮票远程下发）→ 评估留档（[`MVP-PLAN.md`](MVP-PLAN.md) 末），已改用「新版本提示 + 本次更新弹窗」轻方案（✅ 已实现）。
- 视频上传 / 明信片送达统计 / RevenueCat / 地图皮肤 → 后续。

## 待你拍板 / 待做的小项

1. **新版本检测提示 + 「本次更新」弹窗 + 触觉反馈** —— ✅ 已实现并入库（详见 [`ROADMAP.md`](ROADMAP.md) §MVP 打磨）。
2. 反馈是否要门控登录（**不建议**，会降低反馈量）。
3. **本批所有功能改动待真机复验**（见 `ACCEPTANCE.md` 累积各轮 + 上方「⭐ 本轮新增 N1–N13」），这是收尾前的头号事项。

> 📍 **MVP 之后的所有产品方向**（自定义图标/地图皮肤、电子·实体相册/视频、IG·TikTok 分享、3D 地图、社交/关注/索要明信片、行程规划、POI 推荐等）已统一汇总到 [`ROADMAP.md`](ROADMAP.md)。
