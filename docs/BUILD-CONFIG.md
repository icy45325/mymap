# Lumi 打包 / 上架操作手册（按顺序照做）

> 代码里能定的都定了；**这份是你在 Xcode / Apple 开发者后台 / App Store Connect 要手动配的全部内容**。
> **从上往下一步步做**即可。✅=已具备；🔴=阻塞，必须过。付费开发者账号**已开通**。最后更新 2026-06-29。
> 配套：发版前验收 [`ACCEPTANCE.md`](ACCEPTANCE.md)，上架材料分工 [`MVP-REMAINING.md`](MVP-REMAINING.md)，路线图 [`ROADMAP.md`](ROADMAP.md)。

---

## 第 0 步 · 前提
- [x] 付费 **Apple Developer Program** 账号（已开通）

## 第 1 步 · Xcode 签名 + Bundle ID
- [ ] 选 **Lumi** target → Signing & Capabilities → 勾 **Automatically manage signing** → 选你的 **Team**
- [ ] **LumiWidgets** target 同样选 Team
- [ ] **Bundle ID 只改一处**：项目 Build Settings 搜 **`LUMI_APP_ID`**，改成你的唯一 ID（如 `com.yourname.lumi`）
  - App = `$(LUMI_APP_ID)`、Widget = `$(LUMI_APP_ID).widgets` 会**自动跟随**；**别**在 target General 直接改 Bundle ID 框（会打破前缀）

## 第 2 步 · Xcode 能力（+ Capability）
> 用「Automatically manage signing」时，勾能力后 Xcode 会**自动**在 developer.apple.com 的 App ID 上开通对应能力——无需手动去后台配（除非你用手动 profile）。
- [ ] **App Groups**：**两个 target 都勾**，组名 **`group.com.lumi.v0`**（App 与小组件共享快照，**别改**）
- [ ] **Sign in with Apple**：加在 **Lumi** target（否则登录按钮点了无反应）
- [ ] **In-App Purchase**：加在 **Lumi** target（订阅必需）
- [ ] 顺带确认：**App Icon** 已就位（Assets → AppIcon ✅）；`Info.plist` 含 `ITSAppUsesNonExemptEncryption=NO` ✅；相机/定位/相册用途说明在 Build Settings `INFOPLIST_KEY_NS*UsageDescription` ✅

## 第 3 步 · 本地看到订阅（StoreKit 配置）
> 不配这步，本地跑 paywall 一个套餐都不显示（`Product.products(for:)` 返回空）。产品定义本身没问题（`Lumi/Lumi.storekit` 里月订一档，ID 与代码一致）。
- [ ] **Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration** 选 **`Lumi.storekit`**
- [ ] 重跑 → paywall 应显示**月订 9.9** 一档，可走沙盒购买 / 恢复
> 这设置存在 scheme（属 xcuserdata，不随仓库走）→ **每台机/每次重建 scheme 都要设一次**。上架真包不靠它（用 ASC 真产品，见第 5 步）。

## 第 4 步 · 真机自测 + 系统化回归
- [ ] 连真机跑一遍核心流程；按 [`ACCEPTANCE.md`](ACCEPTANCE.md) **三语 × 机型**逐项过（🔴 重点：报告分享首次出图、订阅状态同步、入境章方式、「我的世界」本地化、多图翻页）
- [ ] 沙盒账号验证内购：购买 → 去水印高清生效 → 杀进程重开仍 Plus → 「恢复购买」可用

## 第 5 步 · App Store Connect：建 App + 内购
- [ ] 新建 App：Bundle ID 选你的 `LUMI_APP_ID`，主语言、分类（旅游/生活）、年龄分级 **4+**
- [ ] 订阅组「Lumi Plus」下建**一档自动续订订阅**，ID **必须与代码一致**：`com.lumi.plus.monthly`（月订）
- [ ] 定价（按地区自定，目标显示 9.9）：美 **$9.9/月**、中 **¥9.9/月**、阿联酋 **AED 9.9/月**（其余地区 Apple 自动换算或自定）
- [ ] 填订阅本地化显示名/描述（中/英/阿）+ 审核截图
> 年订 / 终身已移除（只留月订）；以后要加回来：ASC 加产品 + 代码 `PlusProduct` 加 case。

## 第 6 步 · 法务页（GitHub Pages）
- [ ] 仓库 Settings → Pages → 源选分支的 `/docs` → 让 `docs/legal/{privacy,terms,support}.html` 能在线打开
- [ ] 确认 paywall 里隐私政策 / 使用条款链接指向上面的线上地址（代码已指向 `icy45325.github.io/mymap/legal/...`）

## 第 7 步 · 隐私 / 元数据 / 截图
- [ ] App 隐私标签：**Data Not Collected**（纯本地、无后端；Sign in with Apple 只在本机存姓名、不上传、不取邮箱；更新检测只 GET Apple 公共接口、不传用户数据）
- [ ] 出口合规：靠 `ITSAppUsesNonExemptEncryption=NO`，提审无需再填
- [ ] 截图：6.7" + 6.1" 各一套，三语 caption（文案见 [`APPSTORE-LISTING.md`](APPSTORE-LISTING.md)）
- [ ] 元数据：名称/副标题/关键词/描述/更新说明（见 `APPSTORE-LISTING.md`）
- [ ] 审核备注：纯本地、内购去水印、Sign in with Apple 仅本地登录态（见 [`APP-PRIVACY-AND-SUBMISSION.md`](APP-PRIVACY-AND-SUBMISSION.md)）

## 第 8 步 · TestFlight → 提审
- [ ] Archive 上传 → **TestFlight** 外测一轮（含两台机验证明信片收发 / 往来头条）
- [ ] 提交审核

---

## 速查表：标识符
| 项 | 值 | 在哪 |
|---|---|---|
| App Bundle ID | `$(LUMI_APP_ID)`（默认 `com.lumi.v0`） | Build Settings `LUMI_APP_ID` |
| Widget Bundle ID | `$(LUMI_APP_ID).widgets` | 自动 |
| App Group | `group.com.lumi.v0` | 两个 target entitlements（**别改**） |
| 月订阅（唯一一档） | `com.lumi.plus.monthly` · 9.9/月 | 代码 + `.storekit` + ASC |
| URL scheme | `lumi://`（明信片回跳） | Info.plist ✅ |
| 文件类型 | `.lumicard`（AirDrop 明信片） | Info.plist ✅ |
| IG 分享 | `instagram` / `instagram-stories` 查询 | Info.plist `LSApplicationQueriesSchemes` ✅ |

---

## 每次发版必做（新版本提示 + 本次更新）
App 内置「更新提示」与「本次更新」弹窗（零后端，见 `AppUpdateCheck.swift` / `WhatsNewSheet.swift`）。每发新版：
- [ ] **bump 版本号**：Build Settings `MARKETING_VERSION`（如 0.2→0.3）；`CURRENT_PROJECT_VERSION` +1
- [ ] **同步本次更新**：`WhatsNewSheet.swift` 里 `WhatsNew.version` 改成同号 + 更新 `highlights`（三语经 `gen_xcstrings.py`）
- [ ] **ASC 更新说明**：填本版更新说明（与 highlights 对应，三语）
- [ ] 说明：**首版上架前** iTunes Lookup 返回空 → 不弹「发现新版本」属正常；上架后旧版本用户才会收到提示
