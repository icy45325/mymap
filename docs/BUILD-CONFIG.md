# Lumi 打包 / 上架配置清单（ICY 一处看全）

> 代码里能定的我已经定了；**这份清单是你在 Xcode / Apple 开发者后台 / App Store Connect 要手动配的全部内容**。
> 按「① Xcode → ② 开发者后台 → ③ App Store Connect」顺序走。最后更新 2026-06-28。

---

## 🔴 先解决：订阅 3 个套餐看不到

**原因**：本地跑时 StoreKit 没指向测试配置文件 → `Product.products(for:)` 返回空 → paywall 一个套餐都不显示。
产品定义本身没问题（`Lumi/Lumi.storekit` 里月/年/终身三个都在，ID 与代码一致）。

**本地测试要做（每个 scheme 一次）**：
1. Xcode 顶部 **Product → Scheme → Edit Scheme…**
2. 左侧选 **Run** → 右侧 **Options** 标签
3. **StoreKit Configuration** 下拉 → 选 **`Lumi.storekit`**（在 `Lumi/Lumi.storekit`）
4. 关闭，重跑 → paywall 就能看到**月订 9.9** 一档，可走沙盒购买/恢复。

> 这个设置存在 scheme 里（属 xcuserdata，不随仓库走），所以每台机 / 每次重建 scheme 都要设一次。
> **上架的真包不靠它**——真机/审核用的是 App Store Connect 里建的真产品（见 ③）。

---

## ① Xcode（target / 签名 / 能力）

### 签名
- [ ] 选 **Lumi** target → Signing & Capabilities → 勾 **Automatically manage signing** → 选你的 **Team**
- [ ] **LumiWidgets** target 同样选 Team
- [ ] **Bundle ID 只改一处**：项目 Build Settings 搜 **`LUMI_APP_ID`**，改成你的唯一 ID（如 `com.yourname.lumi`）。
  App = `$(LUMI_APP_ID)`、Widget = `$(LUMI_APP_ID).widgets` 会**自动跟随**，不要在 target General 里直接改 Bundle ID 框（会打破前缀）。

### 能力（Capabilities，+ Capability 添加）
- [ ] **App Groups**：**两个 target 都要**勾，组名 **`group.com.lumi.v0`**（App 与小组件共享快照，**别改**，改了小组件数据不通）
- [ ] **Sign in with Apple**：加在 **Lumi** target（这一步会自动写 entitlement 并在 App ID 注册；不开登录按钮点了无反应）
- [ ] **In-App Purchase**：加在 **Lumi** target（订阅/内购必需）

### 其它
- [ ] 确认 **App Icon** 在（Assets → AppIcon，已就位）
- [ ] `Info.plist` 已含 **`ITSAppUsesNonExemptEncryption = NO`**（已加，免每次提审填出口合规）
- [ ] 相机/定位/相册用途说明已在 Build Settings 的 `INFOPLIST_KEY_NS*UsageDescription`（已就位，可按需润色文案）
- [ ] StoreKit 本地配置（见上「🔴」）

---

## ② Apple Developer 后台（App ID / 能力开通）

> 用「Automatically manage signing」时，Xcode 会在你勾能力后**自动**在 App ID 上开通；如果用手动 profile，需在 developer.apple.com 手动对齐：
- [ ] 付费 **Apple Developer Program** 账号（一切的前提）
- [ ] App ID（= 你的 `LUMI_APP_ID`）开通：**App Groups**、**Sign in with Apple**、**In-App Purchase**
- [ ] Widget 的 App ID（`...widgets`）开通 **App Groups**

---

## ③ App Store Connect（App / 内购 / 元数据）

### 建 App
- [ ] 新建 App，Bundle ID 选你的 `LUMI_APP_ID`，主语言、分类（旅游/生活）、年龄分级 **4+**

### 内购产品（**ID 必须与代码完全一致**；当前仅月订一档）
- [ ] 订阅组（Subscription Group「Lumi Plus」）下建**一档自动续订订阅**：
  - `com.lumi.plus.monthly` —— **月订**
- [ ] **定价（按地区自定，目标显示 9.9）**：美国 **$9.9/月**、中国 **¥9.9/月**、阿联酋 **AED 9.9/月**（其余地区可用 Apple 自动换算或自定）
- [ ] 填本地化显示名/描述（中/英/阿）、订阅本地化、审核截图
- [ ] 真机/沙盒账号验证：购买 → 去水印高清生效 → 杀进程重开仍 Plus → 「恢复购买」可用
> 年订 / 终身已**移除**（只留月订）；以后想加回来在这里加产品 + 代码 `PlusProduct` 加 case 即可。

### 法务页（paywall 里已链接，必须可访问）
- [ ] 开 **GitHub Pages**（仓库 Settings → Pages → 源选 `main`/分支的 `/docs`），让 `docs/legal/{privacy,terms,support}.html` 能打开
- [ ] 确认 paywall 里隐私政策/使用条款链接指向上面的线上地址

### 隐私 & 提审
- [ ] App 隐私标签：**Data Not Collected**（纯本地、无后端；Sign in with Apple 只在本机存姓名、不上传、不取邮箱 → 不算收集）
- [ ] 出口合规：靠 `ITSAppUsesNonExemptEncryption=NO`，提审时无需再填
- [ ] 截图：6.7" + 6.1" 各一套，三语 caption（文案见 [`APPSTORE-LISTING.md`](APPSTORE-LISTING.md)）
- [ ] 元数据：名称/副标题/关键词/描述/更新说明（见 `APPSTORE-LISTING.md`）
- [ ] 审核备注：说明纯本地、内购去水印、Sign in with Apple 仅本地登录态（见 [`APP-PRIVACY-AND-SUBMISSION.md`](APP-PRIVACY-AND-SUBMISSION.md)）
- [ ] **TestFlight** 外测一轮 → 提交审核

---

## 速查表：标识符

| 项 | 值 | 在哪 |
|---|---|---|
| App Bundle ID | `$(LUMI_APP_ID)`（默认 `com.lumi.v0`） | Build Settings `LUMI_APP_ID` |
| Widget Bundle ID | `$(LUMI_APP_ID).widgets` | 自动 |
| App Group | `group.com.lumi.v0` | 两个 target entitlements（**别改**） |
| 月订阅（唯一一档） | `com.lumi.plus.monthly` · 9.9/月 | 代码 + .storekit + ASC |
| URL scheme | `lumi://`（明信片回跳） | Info.plist（已配） |
| 文件类型 | `.lumicard`（AirDrop 明信片） | Info.plist（已配） |

---

## ④ 每次发版必做（新版本提示 + 本次更新）

App 内置「更新提示」与「本次更新」弹窗（零后端，详见 `AppUpdateCheck.swift` / `WhatsNewSheet.swift`）。每次发新版：
- [ ] **bump 版本号**：Xcode Build Settings `MARKETING_VERSION`（如 0.2 → 0.3）；`CURRENT_PROJECT_VERSION` +1
- [ ] **同步「本次更新」**：把 `Lumi/Features/Root/WhatsNewSheet.swift` 里 `WhatsNew.version` 改成同一版本号，并更新 `highlights`（本版亮点，三语经 `gen_xcstrings.py`）
- [ ] **App Store「更新说明」**：在 ASC 填本版更新说明（与 highlights 对应，三语）
- [ ] 说明：**首版上架前** iTunes Lookup 返回空 → App 内不弹「发现新版本」属正常；上架后旧版本用户才会收到提示
- [ ] 隐私：更新检测是 App **首处联网**（GET Apple `itunes.apple.com/lookup`，不传用户数据）→ 隐私标签仍 **Data Not Collected**；HTTPS，无需改 ATS

> 仅「上架前还差什么」的负责人分工见 [`MVP-REMAINING.md`](MVP-REMAINING.md)。完整产品路线图见 [`ROADMAP.md`](ROADMAP.md)。
