# App 隐私标签 + 提审清单（B5）

> 把 App Store Connect 提审需要的答案与材料集中在此。配合 [`APPSTORE-LISTING.md`](APPSTORE-LISTING.md)（文案/截图）
> 与 [`legal/`](legal/)（隐私/条款/支持页）使用。最后更新 2026-06-27。

## 1. App 隐私「营养标签」（App Privacy）

**结论：Data Not Collected（不收集任何数据）。** Lumi 纯本地、无账号、无自有服务器、无第三方分析/广告 SDK，
诊断仅本地 OSLog（不上报）。在 ASC「App 隐私」问卷中：

- **Do you or your third-party partners collect data from this app?** → **No, we do not collect data**。

> 说明用数据（不被「收集」，因为不离开设备 / 不上传给我们）：
> - **照片**：仅在设备上读取定位生成足迹、选图作封面；不拷贝、不上传。
> - **位置**：仅用于地图点亮当前定位；不后台追踪、不上传。
> - **相机**：仅本地扫明信片二维码。
> - **购买**：由 Apple/StoreKit 处理，开发者不接触支付信息。
> - **地图/搜索/地理编码**：经 Apple Maps，由 Apple 按其隐私处理，我们不接收。

若审核追问，统一口径：**这些数据用于设备端功能，不被开发者收集、存储或共享。**

## 2. 权限用途字符串（已在工程，复核三语）

| 权限 | Key | 用途文案（应保证三语，跟随 catalog/Info） |
|------|-----|------|
| 照片 | `NSPhotoLibraryUsageDescription` | 读取照片位置以自动生成足迹，并把你选的照片作为足迹封面（照片不离开设备）|
| 位置 | `NSLocationWhenInUseUsageDescription` | 在地图上定位你的当前位置以点亮足迹 |
| 相机 | `NSCameraUsageDescription` | 扫描朋友明信片的二维码以接收 |

> ⚠️ 确认这三条用途字符串**面向用户、具体、非营销**；阿语/英语版本齐全（审核会按设备语言看到对应文案）。

## 3. 出口合规（Export Compliance）

- App 仅使用 HTTPS / Apple 提供的标准加密（Maps、StoreKit），**不含自有非豁免加密**。
- 在 Info.plist 增加 **`ITSAppUsesNonExemptEncryption = NO`**（可用 build setting
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` 或写进 `Lumi/Info.plist`）。
- 这样每次提交不再被问出口合规问题。

## 4. 年龄分级（Age Rating）

问卷全部选 **None / 无**（无暴力、无成人内容、无赌博、无用户生成内容的公开社交…），结果 **4+**。
> 注：明信片是点对点私享、无公开 UGC 流，不触发社交内容分级。一旦未来上「交换日记 / IM 公开内容」，需重做分级问卷（见 monetization §7）。

## 5. 内购 & 审核备注（App Review Notes）

- **无需登录**：App 纯本地，审核无需账号；备注里写明 “No account or login required.”
- **Lumi Plus 内购**：三个产品 `com.lumi.plus.monthly / .yearly / .lifetime`；首版门控＝**明信片导出去水印 + 高清**。
  审核测试路径：任意足迹 →「邮寄明信片」→ 面板底部「升级」→ 购买后水印消失、导出高清。
- **明信片接收演示**（审核常会问点对点怎么测）：备注写明
  “Postcards transfer peer-to-peer (QR / link / AirDrop). To test on one device: open a footprint → Mail postcard → Copy link → paste into Safari → it opens Lumi and shows ‘received’.”
- **恢复购买**：升级页右上角「恢复购买」。

**建议 Review Notes 文本（英文，直接贴）**
```
- No account or login is required; the app is fully local.
- Lumi Plus unlocks watermark-free, high-resolution postcard export.
  To test: open any footprint → "Mail postcard" → tap "Upgrade" at the
  bottom of the sheet → purchase → the watermark disappears and export is HD.
- Postcards transfer peer-to-peer (QR / link / AirDrop), no server.
  To test on a single device: open a footprint → Mail postcard → Copy link →
  paste into Safari → it opens Lumi and shows the "received" prompt.
- Restore Purchases is at the top-right of the upgrade screen.
```

## 6. GitHub Pages 托管（隐私/条款/支持页）

1. 仓库 **Settings → Pages → Build and deployment → Deploy from a branch**。
2. 选分支（合并到默认分支后选它）+ **`/docs` 目录** → Save。
3. 几分钟后可访问：
   - 隐私：`https://icy45325.github.io/mymap/legal/privacy.html`
   - 条款：`https://icy45325.github.io/mymap/legal/terms.html`
   - 支持：`https://icy45325.github.io/mymap/legal/support.html`
4. 这三个 URL 已写进 paywall（隐私/条款）与 ASC（隐私/支持）。**确认开通后能打开**再提审。

## 7. 提审前检查清单（Definition of Done）

**工程 / 能力**
- [ ] Target 加 **In-App Purchase** 能力；ASC 建三个产品 + 价格分层（中东/全球）+ 订阅组。
- [ ] Info.plist：`ITSAppUsesNonExemptEncryption = NO`。
- [ ] 三条权限用途字符串面向用户、三语齐全。
- [ ] 真机/沙盒：购买 → 解锁去水印高清 → 杀进程重开仍 Plus → 「恢复购买」可用。
- [ ] 系统化回归：中/英/阿 × 主流机型全流程无崩溃；阿语 RTL 逐屏核对（见 [`MVP-PLAN.md` B0](MVP-PLAN.md)）。

**ASC 素材**
- [ ] 名称 / 副标题 / 关键词 / 描述 / 宣传文本 三语（[`APPSTORE-LISTING.md`](APPSTORE-LISTING.md)）。
- [ ] 截图 6.7" + 6.1" 各一套（6 张，三语 caption）；可选预览视频。
- [ ] App 隐私问卷＝Data Not Collected；年龄分级 4+。
- [ ] 隐私政策 URL + 支持 URL（GitHub Pages）可访问。
- [ ] App Review Notes（§5 文本）。

**流程**
- [ ] 付费 Apple Developer Program + App Store Connect 建 App（bundle id 对齐 `com.lumi.v0`）。
- [ ] TestFlight 外测一轮 → 修问题 → 提审。

## 8. 待办（非本批，归后续）

- 营销主页 / Landing（可选，提升关键词与信任）。
- ar 版《使用条款》补全（当前 terms.html 为中英；隐私/支持已三语）。
- 装饰内购（邮票/皮肤）上线后，更新隐私标签（仍 Data Not Collected）与文案。
