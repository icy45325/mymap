# Lumi MVP 执行计划（上架首版排期）

> MVP 范围与定位见 [`ROADMAP.md` MVP 章节](../product/ROADMAP.md#mvp--上架首版ios--纯本地--无账号)。
> 本文把 MVP 拆成可执行批次、定先后与依赖。**状态随推进更新，最后更新 2026-06-27。**
> 产品概览见 [`PRODUCT-OVERVIEW.md`](../product/PRODUCT-OVERVIEW.md)，逐条进度见 [`REQUIREMENTS.md`](../product/REQUIREMENTS.md)，**上架前遗留清单见 [`MVP-REMAINING.md`](MVP-REMAINING.md)**。

## 现状盘点（2026-06-27）

- ✅ **核心点亮回路与周边功能已落地并在真机迭代验证**：点亮 / 真实地图点选（国家→城市列表，开关式选打卡城市）/
  时间线 + 编辑（多图、通栏照片墙、多图轮播、今年统计）/ 成就（3D 水晶徽章 + 点亮庆祝 + 分享）/ 心愿单（含热门目的地预设）/
  相册导入（按城市·国家一次性去重）/ 中英阿三语 + 阿语 RTL。
- ✅ **小组件已补全（原 B1）**：「点亮战绩 / 去过的国旗」两模式，长按「编辑小组件」可切（App Intent），跟随系统语言；设置页有介绍。
- ✅ **明信片收发闭环已打通（原 B3 主体）**：明信片渲染 + 成图导出 + 二维码 + 链接（`lumi://` URL scheme + `onOpenURL`）+
  隔空投送（`.lumicard`）+ 应用内扫一扫 + 剪贴板接收，全部走统一 `PostcardInbox` 幂等去重；并有**明信片墙**收藏收到的卡。
- ✅ **额外交付（原计划外）**：护照本（封面 + 资料页 + 入境章 + 详情浮层，按国籍配色，整页放大）主体完成；个人资料（头像 / 昵称 / 国籍）；设置页反馈入口；6 枚大洲大师插画徽章。
- ⚠️ **编译 / 真机验证模式**：作者在 Mac 侧逐批编译 + 真机自测（容器内无 iOS SDK，不能编译）。多批已上手机验证并修复；
  仍**缺一次「全功能从头到尾、三语 × 机型」的系统化回归**——这是上架前的头号事项。
- 🔨 **两块仍从零**：① **变现**（无 StoreKit / RevenueCat / paywall）；② **上架准备**（开发者账号 / 元数据 / 隐私 / 截图）。

工作量图例：**S**＝半天内 · **M**＝1–3 天 · **L**＝1 周量级（含设计/调试）。

---

## 批次与顺序

### B0 · 编译验证与基线打磨 —— 🔁 持续进行
> 已从「从未编译」推进到「逐批真机验证」；剩一次系统化回归收口。

- [x] 编译跑通整分支、修编译错误（i18n catalog、真实地图、导入、小组件等，多批已修）
- [x] 主要流程真机自测：四 Tab、点亮、足迹编辑、相册导入、心愿单、小组件、明信片收发
- [ ] **上架前系统化回归**：三语（中/英/阿）× 主流机型全流程无崩溃；阿语 RTL 逐屏核对 —— 照 [`QA-REGRESSION.md`](QA-REGRESSION.md) 逐项过
- [ ] 英/阿译文校对（catalog 机翻回填项）
- [ ] 体验打磨清单收尾（空态 / 边界 / 动效 / 触感）

**产出**：可提审质量的稳定基线。**工作量 M**（视回归 bug 数）。

### B1 · 小组件补全 —— ✅ 已完成
- [x] **国旗模式小组件**：长条铺满去过国家国旗 + 统计 + 一句话（复用快照 `litCountryCodes` + `CountryInfo.flag`）
- [x] **模式可切换**：与「点亮战绩」同一小组件，App Intent 在「编辑小组件」里切模式；跟随系统语言
- [x] **设置页小组件介绍**

**文件**：`LumiWidgets/*`、`Settings/SettingsView.swift`。**已交付**。

### B2 · 徽章美术优化 —— ✅ 基本完成（可继续打磨）
- [x] 徽章视觉重做：原生**3D 水晶 / 全息**质感（替换早期 HexBadge），稀有度配色 / 锁定态对比
- [x] 蜂巢排布与点击态、点亮庆祝弹卡、徽章分享
- [x] **大洲徽章插画化**（06-27）：6 枚大洲徽章美术换成插画（`data/badge.png` 抠图透明底 → asset catalog），**替换原简版、沿用原解锁条件**；成就墙改 **3 列网格**给细节让位；点亮庆祝加半透明卡片底防混叠
- [ ] （可选）按真机观感继续微调；其余水晶徽章是否统一为插画风待定

**文件**：`Stats/`、`HolographicBadge`、`Design/Components`、`Assets.xcassets/badge_*`。**主体已交付**。

### B3 · 明信片导出 + 收发闭环 —— ✅ 主体完成
- [x] **B3.0**：URL scheme `lumi://card?t=…` + `onOpenURL` 回跳打通（去 deep-link 风险）
- [x] **B3.1 渲染**：`PostcardView` 渲染足迹 + `ImageRenderer` 导出图（手写体寄语，自动默认可改）
- [x] **B3.2 导出/分享**：`ShareLink` 分享图 + `CIQRCodeGenerator` 二维码 + AirDrop `.lumicard`
- [x] **B3.3 payload 编解码**：足迹要素编进口令 + **幂等 token** + 发送者昵称
- [x] **B3.4 接收**：扫码 / 链接 / AirDrop / 剪贴板 → 统一 `PostcardInbox` 解析 + **按 token 去重** + 接收提示 + 明信片墙
- [ ] **B3.5（增强，下一轮）**：发送可选 **3 样式 + 2 邮票**，外观随口令传达，墙按样式展示（方案已定，见 [`REQUIREMENTS.md` §9](../product/REQUIREMENTS.md)）

**文件**：`Features/Share/*`、`LumiApp`（onOpenURL）、`Lumi/Info.plist`。**主体已交付**。

### B4 · 变现 —— 🚧 代码已落地，待 ASC 配置 + 真机验证
- [x] StoreKit 2 接入：`PlusStore`（拉产品 / 购买 / 恢复 / `Transaction` 监听 / entitlement），
      **业务层只读 `isPlus`**，RevenueCat 可替换的抽象边界（见各「RC 迁移点」注释）
- [x] `Lumi.storekit` 本地测试配置（月 `com.lumi.plus.monthly` / 年 `…yearly` / 终身 `…lifetime`）
- [x] Paywall UI（`PaywallView`）：价值点 + 计划选择（月/年/终身，年付算「省 %」）+ 恢复购买 + 自动续订条款 + 隐私/条款链接
- [x] Plus 门控（首版「轻」）：**明信片导出免费带 Lumi 水印 + 标清(2x)，Plus 去水印 + 高清(3x)**；
      升级入口在 设置页 + 明信片面板水印提示条
- [ ] **RevenueCat 接入** —— 抽象层已留接口；上 Android 时替换 `PlusStore` 内部即可。**暂缓**
- [ ] **需 ICY 在 Xcode / ASC 侧做**：① Target 加 In-App Purchase 能力；② Scheme→Run→Options 选 `Lumi.storekit` 本地测试；
      ③ App Store Connect 建三个产品 + 价格分层（中东/全球）；④ 付费开发者账号；⑤ 沙盒/真机购买 + 恢复验证
- [ ] 后续门控：全部样式·邮票（待 B3.5）/ 地图皮肤

**文件**：`Features/Paywall/PlusStore.swift`、`PaywallView.swift`、`Lumi.storekit`；改 `PostcardSheet`/`PostcardView`/`SettingsView`/`LumiApp`。**工作量 L**（编码部分已完成）。

### B5 · 上架准备 —— 🚧 文案 / 法务页已起草，待 ICY 走 ASC 流程
- [x] 三语元数据（名称/副标题/关键词/描述/宣传文本/更新说明）+ 截图清单 → [`APPSTORE-LISTING.md`](APPSTORE-LISTING.md)
- [x] 隐私政策 / 使用条款 / 支持页（可托管 HTML，三语）→ [`legal/`](../legal/)（paywall 链接已指向 GitHub Pages）
- [x] App 隐私标签答案（Data Not Collected）+ 出口合规 + 年龄分级 4+ + 审核备注 + 提审清单 → [`APP-PRIVACY-AND-SUBMISSION.md`](APP-PRIVACY-AND-SUBMISSION.md)
- [ ] **ICY**：开 GitHub Pages（Settings → Pages → /docs）让三个法务页可访问
- [ ] **ICY**：付费开发者账号 + App Store Connect 建 App + 三产品 + 价格分层（中东/全球）
- [ ] **ICY**：实拍截图（6.7" + 6.1" 各套，三语 caption）+ 可选预览视频
- [ ] Info.plist 加 `ITSAppUsesNonExemptEncryption = NO`
- [ ] TestFlight 外测 → 提审

**工作量 M**（以非编码为主；文案 / 法务页已就绪）。

---

## 建议节奏（剩余路径，solo 估算，不设硬日期）

| 迭代 | 主线 | 并行 |
|------|------|------|
| **S1（当前）** | 收尾增量功能（明信片样式/邮票 B3.5、护照完善）| B0 系统化回归起步 |
| **S2** | **B4 变现**（StoreKit 2 + RevenueCat + 轻 paywall）| B5 截图/元数据/隐私页起步 |
| **S3** | B0 三语 × 机型回归收口 | B5 定价分层 + 隐私标签 |
| **S4** | TestFlight 外测 → 修问题 | 提审 |

**关键路径**：B0 回归 → B4 变现 → B5 提审。功能侧（B1/B2/B3）已基本就绪，不再阻塞上架。

---

## 上架 Gate（Definition of Done）

- [ ] 真机三语（中/英/阿）全流程无崩溃；阿语 RTL 正确。
- [x] 明信片可导出图 + 生成二维码/链接，**另一台设备打开能自动收卡**（B3 闭环已跑通）。
- [ ] （带 paywall）购买 / 恢复购买 / 条款合规可用（代码就绪，待 ASC 产品配置 + 沙盒验证）。
- [ ] App Store 元数据、隐私标签、隐私政策/支持页、定价齐备；TestFlight 通过。

---

## 待拍板

1. ✅ **已定（06-25）**：MVP 带 **轻 paywall** —— 核心集邮回路免费，Plus 卖高清导出 / 全部明信片样式·邮票 /
   额外小组件 / 地图皮肤。B4 纳入 MVP，paywall 保持轻。
2. ✅ **已定（06-25）**：徽章美术方向 —— 走原生 **3D 水晶 / 全息** 风（B2 已据此落地）。
3. ✅ **已定（06-25）**：视频上传（≤3min）**不进 MVP**，归 **Plus / 快速跟进**。
4. 🔲 **待定**：明信片样式/邮票（B3.5）是否在上架首版上线，还是首版后快速跟进？（功能已设计，可放 S1 或顺延。）

> 拍板后把对应条目状态回填 [`REQUIREMENTS.md`](../product/REQUIREMENTS.md)。
