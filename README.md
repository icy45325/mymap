# Lumi v0 — 世界点亮

在地图上「点亮」去过的地方的个人旅行记录 App。iOS 17+ / SwiftUI · SwiftData · MapKit，纯本地、单用户、无账号。

> UI 主题：**暗夜霓虹 v2（Dot-Matrix）** —— 粉/紫/橙霓虹渐变 + 衬线大标题 + 玻璃拟态，
> 对齐设计原型 `lumi_style1_v2_dotmatrix.html`。四个 Tab：地图 / 星迹 / 成就 / 我。

文档：
- [需求规格 PRD（原始构想）](docs/Lumi_v0_PRD.md) — v0 功能规格说明 v0.2
- [架构说明](docs/ARCHITECTURE.md) — 分层、数据流、设计决策、构建验证
- [路线图 Roadmap](docs/ROADMAP.md) — v0.x / v1 / v2 分阶段规划与依赖
- [需求与进度跟踪](docs/REQUIREMENTS.md) — 逐条需求台账 + 交付状态
- [MVP 执行计划](docs/MVP-PLAN.md) — 上架首版批次拆解、顺序与上架 Gate
- [设计：账号体系 / 迁移 / 交换日记 / IM 分享](docs/DESIGN-accounts-and-exchange.md) — 社交与共创主线细化设计
- [设计：VIP 变现 × 账号](docs/DESIGN-monetization.md) — 免费/付费切分、计费基础设施、账号化承接
- [选型：BaaS（Supabase vs Firebase）](docs/DESIGN-baas-selection.md) — 跨平台后端对比与决策记录

## 里程碑

| MS | 内容 | 状态 |
|----|------|------|
| **M1** | 工程骨架 + 暗夜地图渲染 + 点屏落点（落库 + pin 显示） | ✅ |
| **M2** | Capture 录入页（照片/地点/心情/同行人）+ 反向地理编码 + 埋点 | ✅ |
| **M3** | Natural Earth 边界 + point-in-polygon + 国家/UAE 酋长国着色 | ✅ |
| **M4** | Timeline 时间轴 + 删除 + 底部 TabBar | ✅ |
| **M5** | Stats 成就页（大数字 + 洲进度 + 徽章） | ✅ |

边界数据：`Lumi/Resources/admin0.geojson`（Natural Earth 110m 国界，175 国）+
`uae_emirates.geojson`（10m UAE admin-1，7 酋长国），坐标精度 4 位。
point-in-polygon 已用已知坐标离线验证（Abu Dhabi→AE-AZ、Dubai→AE-DU、Paris→FR、公海→nil）。

## 工程结构

```
Lumi/
  LumiApp.swift              应用入口 + SwiftData 容器
  Models/                    Footprint · Trip · Card（@Model）+ CountryInfo / Region（派生展示字段）
  Design/Tokens.swift        暗夜霓虹设计令牌（nPink/nPurple/… + neon 渐变）
  Design/Components.swift     霓虹组件：六边形徽章 · 环形进度 · 进度条 · 分段器
  Map/                       MapProvider 抽象层 + MapKitProvider 实现（霓虹着色）
  Features/Map/MapHomeView   世界地图主页（核心页）· HUD + 精彩瞬间 + FAB
  Features/Map/DotMatrixMap  可选沉浸模式：点阵光点世界地图（程序生成，右上角按钮进入）
  Features/Timeline/         星迹时间轴 + 明信片详情
  Features/Stats/            成就页 + Achievements（派生徽章/大洲征服/统计）
  Features/Profile/          「我」本地档案页
```

**展示字段全部派生、不新增持久化**：`flag`（国旗 emoji）/ `countryName`（中文国名）/
`region`（地区分组）由 `countryCode` 实时计算；徽章 / 大洲征服 / 概览数字由 `LumiStats`
聚合 `[Footprint]` 得到，永远与真实点亮数据一致。地理判定仍走离线 point-in-polygon（§5.1）。

底图通过 `MapProvider` 协议抽象：v0 用 `MapKitProvider`，将来换 Mapbox / 高德只换实现，上层不动。

## 构建

```bash
xcodebuild -project Lumi.xcodeproj -scheme Lumi \
  -destination 'generic/platform=iOS Simulator' build
```

> 开发机若未安装 iOS 模拟器运行时（CoreSimulator），无法跑模拟器，但可用 SDK 类型检查验证编译：
> ```bash
> SDK=$(xcrun --sdk iphoneos --show-sdk-path)
> swiftc -typecheck -parse-as-library -sdk "$SDK" -target arm64-apple-ios17.0 $(find Lumi -name '*.swift')
> ```
