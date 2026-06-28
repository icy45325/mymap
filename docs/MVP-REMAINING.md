# Lumi MVP 遗留事项（上架前清单）

> 上架首版**还差什么**集中一页。**打包/后台逐项怎么配见 [`BUILD-CONFIG.md`](BUILD-CONFIG.md)**。
> 逐批排期见 [`MVP-PLAN.md`](MVP-PLAN.md)，逐条台账见 [`REQUIREMENTS.md`](REQUIREMENTS.md)。
> 图例：✅ 完成 · 🚧 进行中 · 🔲 未开始。最后更新 **2026-06-28**。

## 一句话现状

功能侧（点亮回路 / 时间线 / 成就+统计报告 / 心愿单 / 相册导入 / 小组件 / 明信片收发+样式邮票 / 护照 / 三语徽章 / Sign in with Apple 登录）**已就绪**。
**关键路径只剩 3 件**：① 系统化回归（质量）→ ② **变现/能力配置**（StoreKit + ASC，见下「🔴」）→ ③ 上架材料 & 提审。

---

## 🔴 当前最容易卡住的：订阅看不到 3 个套餐

代码与 `Lumi.storekit` 都没问题，是 **scheme 没指向 StoreKit 配置**。
本地：Edit Scheme → Run → Options → **StoreKit Configuration = `Lumi.storekit`**。
上架：在 App Store Connect 建同 ID 的三个产品。**完整步骤见 [`BUILD-CONFIG.md`](BUILD-CONFIG.md) 顶部**。

---

## A. 代码 / 文档侧（我能做）

| # | 事项 | 状态 | 说明 |
|---|------|------|------|
| A1 | 明信片样式/邮票 | ✅ | 3 样式（复古/现代/插画）+ 邮票（空运/陆运/海运），随口令传达、墙按样式呈现 |
| A2 | 护照本完善 | 🚧 | 整页放大/资料页已做；可继续：入境章逐国暗纹 |
| A3 | 英/阿译文校对 | 🔲 | catalog 机翻回填项需母语者过一遍（阿语为主） |
| A4 | 体验打磨收尾 | 🔲 | 空态/边界/动效/触感统一 |
| A5 | `ITSAppUsesNonExemptEncryption=NO` | ✅ | 已写进 `Lumi/Info.plist` |
| A6 | 徽章美术 | ✅ | 15 枚三语插画徽章（中/英/阿各一版）+ 名字对齐图上印字 |

## B. 必须 ICY 操作——账号 / 后台 / 实拍（详见 `BUILD-CONFIG.md`）

| # | 事项 | 状态 |
|---|------|------|
| B1 | 付费 Apple 开发者账号 | 🔲 |
| B2 | Xcode 能力：App Groups(两 target) + **Sign in with Apple** + In-App Purchase | 🔲 |
| B3 | scheme 设 StoreKit Configuration（本地看到套餐） | 🔲 |
| B4 | App Store Connect 建 App + 三内购产品（月/年/终身）+ 价格分层 | 🔲 |
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

## 明确**不进** MVP 首版（已拍板）

- 真账号 / 云端 / 跨设备同步、真好友系统（首版纯本地；Sign in with Apple 仅本地登录态，云端留 v1，需后端）。
- 服务端可更新内容（徽章/样式/邮票远程下发）→ 评估留档（[`MVP-PLAN.md`](MVP-PLAN.md) 末），改用「新版本提示」轻方案（待做）。
- 视频上传 / 明信片送达统计 / RevenueCat / 地图皮肤 → 后续。

## 待你拍板 / 待做的小项

1. **新版本检测提示**（轻方案，替代服务端内容更新）—— 已设计未落地，要不要进首版？
2. 反馈是否要门控登录（**不建议**，会降低反馈量）。
