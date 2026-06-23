# Lumi v0 架构说明

本文档说明 Lumi v0 的工程结构、数据流与关键设计决策，配合需求规格 [`Lumi_v0_PRD.md`](Lumi_v0_PRD.md) 阅读。

## 1. 技术栈与约束

| 维度 | 选择 | 原因 |
|------|------|------|
| 平台 | iOS 17+ | SwiftData + MapKit `MapPolygon`（PRD §6） |
| UI | SwiftUI | 单人开发、快速迭代 |
| 持久化 | SwiftData（纯本地） | 无账号/无云同步即无需付费 Apple Developer（PRD §8） |
| 地图 | MapKit | v0 不引第三方依赖；经 `MapProvider` 抽象，可换 |
| 边界数据 | Natural Earth（离线打包） | 点亮判定不依赖网络（PRD §5.1） |

## 2. 分层

```
LumiApp                      应用入口 + SwiftData 容器（Footprint/Trip/Card）
  └─ RootTabView             底部 4 Tab：地图 / 足迹 / 成就 / 我
       ├─ MapHomeView        ① 暗夜地图 + 点屏落点 + 计数器 + FAB
       │    └─ MapProvider   底图抽象（MapKitProvider 实现）
       │    └─ Boundaries    离线 point-in-polygon + 着色多边形
       ├─ CaptureView        ② 录入明信片卡（照片/地点/心情/同行人）
       │    └─ Services       PlaceSearch · Geocoding · LocationService
       ├─ TimelineView       ③ 倒序卡片流 + 删除 + 详情
       └─ StatsView          ④ 大数字 + 各洲进度 + 徽章
  Analytics                  §9 埋点（OSLog, subsystem com.lumi.v0）
```

数据模型（`Lumi/Models/`）：

- **Footprint** —— 一次"点亮"。坐标一律存 WGS-84（`latitude`/`longitude`），`countryCode` / `subRegionCode`（UAE 酋长国）驱动着色与计数。
- **Card** —— 每个 Footprint 录入时同步建一张明信片卡（1:1，cascade 删除），为后续分享/印刷打底（PRD 设计决策）。
- **Trip** —— 行程归属容器，v0 最薄一层，为 v0.x 回顾打底。

**展示层（派生，不持久化）** —— 暗夜霓虹 v2 引入，对齐 `lumi_data_model` 字段契约：

- `CountryInfo` / `Region`（`Models/`）：`countryCode` → 国旗 emoji（区域指示符拼合）/ 中文国名（`Locale`）/ 地区分组（中东特判 + 大洲映射）。全部计算属性挂在 `Footprint` 上。
- `LumiStats` / `Badge` / `BadgeBoard` / `ConquestEntry`（`Features/Stats/Achievements.swift`）：从 `[Footprint]` 聚合徽章状态、大洲征服、概览数字与精彩瞬间。**单一计算入口**保证 地图 / 星迹 / 成就 / 我 四页口径一致。
- 取舍：徽章不落库为 @Model，规则化派生，避免 SwiftData 迁移与「徽章状态 ↔ 真实数据」不同步。解锁时间以触发里程碑的足迹 `visitedAt` 近似。

## 3. 核心数据流：点亮判定（PRD §5.1）

```
点屏落点 / 录入页确认地点
        │
        ▼  WGS-84 坐标
Boundaries.countryCode(at:)        ← 离线 point-in-polygon（事实来源，瞬时）
        │
   ┌────┴────┐
 命中国家    落公海/无匹配 → countryCode = nil（散点 pin，不崩溃，PRD §7）
   │
   ├─ countryCode == "AE" → Boundaries.emirateCode(at:) 下钻酋长国
   │
   ▼
Geocoding（CLGeocoder，需网络，best-effort）补 placeName / cityName
        │
        ▼
落库 Footprint + Card → @Query 自动刷新 → 地图着色 + 计数器跳动
```

**计数口径**：已点亮国家数 = `distinct(countryCode)`；城市数 = `distinct(cityName)`。同国多次到访不重复计数。

## 4. 关键设计决策

- **底图抽象层**：所有"点亮/落点/着色"只跟 `MapRenderState` / `MapPin` / `LitRegion` 等与底图无关的值类型打交道。换 Mapbox（海外美学）或高德（国内合规底图）只需另写一个 `MapProvider`，上层不动。
- **坐标统一 WGS-84**：业务层一律 WGS-84，是否转 GCJ-02 是"显示"的事，交给 `MapProvider.displayCoordinate`。
- **国家码以离线 Boundaries 为准**：CLGeocoder 仅补地名，避免点亮依赖网络。UAE 下钻到酋长国级（其余国家不下钻）；城市为点状打卡，不做区域着色。
- **照片只引用不拷贝**：`photoAssetIDs` 存 PhotoKit 本地标识符；失效则显示占位图，不崩溃（PRD §7）。

## 5. 边界数据

`Lumi/Resources/` 下两份精简 GeoJSON（源自 [Natural Earth](https://www.naturalearthdata.com/)，public domain）：

| 文件 | 内容 | 字段 |
|------|------|------|
| `admin0.geojson` | 110m 世界国界，173 国（剔除南极/公海） | `iso`（ISO_A2_EH）, `continent` |
| `uae_emirates.geojson` | 10m UAE admin-1，7 酋长国 | `iso`（如 `AE-DU`）, `name` |

坐标精度 4 位（≈11m），足够 v0 集邮粒度。`Boundaries` 用射线法 point-in-polygon + 包围盒剪枝；`countriesPerContinent` 由数据现算（六洲求和 = 173，与全球分母自洽）。

## 6. 构建与验证

```bash
# 标准构建（需已安装 iOS 模拟器运行时）
xcodebuild -project Lumi.xcodeproj -scheme Lumi \
  -destination 'generic/platform=iOS Simulator' build

# 若开发机无模拟器运行时：用 SDK 类型检查验证编译
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
swiftc -typecheck -parse-as-library -sdk "$SDK" -target arm64-apple-ios17.0 $(find Lumi -name '*.swift')
```

工程为手写 `project.pbxproj`（objectVersion 77，文件系统同步 group）：新增源文件放进 `Lumi/` 即自动纳入编译，资源放 `Lumi/Resources/`，无需改 pbxproj。

## 7. v0 未做（PRD §8）与待确认

- 非目标：交换日记 / AI 故事片 / 圈子 / 分享导出 / 云同步 / 推送 / 账号 / 省市级下钻 / 多媒体 / 国内合规底图。
- 待确认：`photoAssetID` 失效清理策略；Timeline 是否需要编辑（当前只删除 + 详情只读）。
