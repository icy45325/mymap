# 「点亮这里」App Intent + 主屏小组件 · 接线与验证

> v0.x 第一个 iOS 系统能力落地（见 [ios-native-capabilities.md](ios-native-capabilities.md) §0 / ①）。
> 代码已写好并接进工程文件；因 CI 容器无 Xcode，**首次需在 Xcode 打开跑一次**确认签名与 capability。

## 这次加了什么

| 区域 | 文件 | 作用 |
|------|------|------|
| 共享层 | `LumiShared/LumiSnapshot.swift` | App↔小组件 的派生快照（App Group UserDefaults）。纯 Foundation，**同时编进两个 target**。 |
| App | `Lumi/LumiStore.swift` | 进程级共享 `ModelContainer`，App 与 Intent 共用同一实例。 |
| App | `Lumi/Intents/LightUpHereIntent.swift` | 「点亮这里」App Intent：定位→反解→落 `Footprint`(+`Card`)→刷新小组件。 |
| App | `Lumi/Intents/LumiShortcuts.swift` | `AppShortcutsProvider`，注册系统快捷指令 / Siri 短语。 |
| App | `Lumi/Intents/WidgetSync.swift` | 把足迹聚合成 `LumiSnapshot` 写 App Group 并刷新时间线（点亮 / 启动统一出口）。 |
| 小组件 | `LumiWidgets/*` | 扩展 target：`LitCountWidget`（点亮计数）+ `OnThisDayWidget`（去年今日），均支持 small / medium / 锁屏 rectangular & inline。 |
| 共享层 | `LumiShared/LumiSnapshot.swift` | 快照含 `memories`（精简回忆），供「去年今日」按日期匹配。 |
| Entitlements | `Lumi/Lumi.entitlements`、`LumiWidgets/LumiWidgets.entitlements` | App Group `group.com.lumi.v0`。 |

标识约定：App `com.lumi.v0` · 小组件 `com.lumi.v0.widgets` · App Group `group.com.lumi.v0`。

## 工程文件已接好的部分（`project.pbxproj`）

- 新 `LumiWidgets` app-extension target（含 Debug/Release 配置、Info.plist、entitlements）。
- App target 增加「Embed Foundation Extensions」拷贝阶段 + 对小组件的依赖。
- `LumiShared` 同步组挂在 **App 与小组件两个 target** 下（共享快照源码）。
- 两个 target 的 `CODE_SIGN_ENTITLEMENTS` 指向各自 entitlements。

## 首次在 Xcode 必做的 3 步验证

1. **打开工程**：`Lumi.xcodeproj` 应出现 `Lumi` 与 `LumiWidgets` 两个 target，编译无 “cannot find … in scope”。
   - 若小组件报找不到 `LumiSnapshot`：在 `LumiShared/LumiSnapshot.swift` 的 File Inspector 勾上 `LumiWidgets` 的 Target Membership（多 target 共享同步组的兜底）。
2. **App Groups capability**：两个 target 的 Signing & Capabilities 里都应有 App Group `group.com.lumi.v0`（自动签名首次会向账号注册该组，点一下确认即可）。
3. **跑真机/模拟器**：
   - 主屏长按 → 加 “Lumi · 点亮战绩” 与 “Lumi · 去年今日” 小组件（small / medium）。
     - 「去年今日」需库里有**往年同一天附近（±4 天）**的足迹才显示内容，否则是鼓励性空态；可临时改一条足迹的日期到去年今日来验证。
   - 设置 › 控制中心 或锁屏，加「点亮这里」按钮；或对 Siri 说「用 Lumi 点亮这里」。
   - 点亮后小组件计数应随之 +1（`WidgetSync` 已在点亮 / 启动时刷新）。

## 设计取舍（备查）

- **小组件读快照、不读 SwiftData**：扩展是独立沙盒进程，直接读主库要把库迁进 App Group + 处理并发；v0 用「主 App 写一份极小派生快照」更稳，口径仍走 `LumiStats`（不另立统计）。
- **Intent 在 App target、共用 `LumiStore.shared`**：未开 `openAppWhenRun` 时系统在后台拉起 App 进程执行，单例容器保证写入即时反映到主界面 `@Query`。
- **刷新策略 `.never`**：计数变更由主 App 主动 `reloadTimelines(ofKind:)` 触发，不让小组件空转耗系统预算。
