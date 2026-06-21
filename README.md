# Lumi v0 — 世界点亮

在地图上「点亮」去过的地方的个人旅行记录 App。iOS 17+ / SwiftUI · SwiftData · MapKit，纯本地、单用户、无账号。规格见 [`docs/Lumi_v0_PRD.md`](docs/Lumi_v0_PRD.md)。

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
  Models/                    Footprint · Trip · Card（@Model）
  Design/Tokens.swift        暗夜 + 琥珀设计令牌
  Map/                       MapProvider 抽象层 + MapKitProvider 实现
  Features/Map/MapHomeView   世界地图主页（核心页）
```

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
