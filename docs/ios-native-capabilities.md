# Lumi · iOS 原生能力待办（纪要）

> 性质：探索性 backlog，不是承诺排期。记录「集邮 / 怀念 / 地图 / 共创」定位下值得接的 iOS 系统能力，
> 供 v0.x 及以后取用。优先级见文末「落阶段」。配合 [ROADMAP.md](ROADMAP.md) 阅读。

## 0. 最高杠杆基础设施：App Intents

iOS 27 起 **App Intents 是 Siri 调用第三方 App 的唯一方式**（SiriKit 已废弃），且小组件也通过
App Intents 定制 / 动态换样式。把「点亮一个足迹」「查看战绩」做成 App Intent，**一份代码同时喂给
Siri / Spotlight / 小组件 / 快捷指令 / 锁屏按钮**。即便 v0.x 也值得早接，是基础设施而非锦上添花。

## ① 让「战绩」无处不在（集邮 / 成就）
- **主屏 / 锁屏小组件**：迷你点亮地图，或「已点亮 9 国 · 全球 5%」计数器，不开 App 也能炫。
- **StandBy 横屏待机**：充电时把点亮地图当床头夜灯——集邮 + 怀念两头沾。
- **Live Activity / 灵动岛**：旅行中实时显示「本次旅程已点亮 3 城」（iOS 27 竖横屏均可见）。
- **Apple Watch 复杂功能**：表盘点亮数，抬腕即见。
- **控制中心 / 锁屏 Action Button**：一键「点亮这里」。

## ② 让「记」几乎零摩擦（降录入门槛）
- **Siri + App Intents**：「嘿 Siri，点亮这里」直接落足迹；entity schema 可把内容贡献进 Spotlight 语义索引。
- **分享扩展（Share Extension）**：相册 / 地图里选张照片 → 分享到 Lumi → 自动变足迹。
- **CLVisit / 显著位置**：系统级到访检测，到地半自动提示「要点亮吗」，比全程 GPS 轻、本地隐私。
- **ValueRepresentation → PlaceDescriptor**：把地点导出成系统认识的 PlaceDescriptor，待点亮清单一键导航。

## ③ 让回忆主动找上门（怀念）
- **「去年今日」小组件 + 通知**：延迟回路的钩子。
- **Journaling Suggestions API**：系统把地点 / 照片 / 活动打包成「可写入建议」，天然契合「记一句此刻心情」。
- **Foundation Models（iOS 27，端上 LLM）**：Swift 原生调用本地模型，把「地点+照片+心情」织成旅行小记 /
  旁白——隐私不出端、省后端成本。直接接「AI 故事片」主线。

## ④ 把系统地图能力用足
- **Look Around 街景**：足迹详情回看当地街景。
- **MapKit Snapshotter**：离线把点亮地图渲染成静态图，喂小组件 / 明信片卡 / 分享海报。

## ⑤ 用系统能力放大「一起」（共创 / 亲子）
- **SharePlay**：两人 / 一家人实时一起翻「交换日记」、同步看故事片。
- **CloudKit 共享库（CKShare）**：家庭共建地图，零自建后端实现共享（注意属付费层能力）。
- **PencilKit**：iOS 27 增强手写识别（端上 29 种语言）+ 可编程擦除——孩子在明信片卡上涂鸦 / 手写。
- **iMessage 贴纸 / 录音**：聊天发「我点亮了迪拜」卡片，或把孩子语音贴在足迹旁。

## ⑥ 系统搜索 / 输出
- **Spotlight 语义搜索**：用 IndexedEntity 把足迹进系统搜索，「搜‘迪拜’就出你的足迹」。
- **ImageRenderer / ShareLink / AirPrint**：卡片渲染成图分享，或走打印接实体旅行书。

---

## 落阶段（优先级）

| 阶段 | 接什么 | 理由 |
|------|--------|------|
| **v0.x（早做）** | App Intents「点亮这里」+ 一个主屏/锁屏小组件 ✅ *(已落地，待真机验证，见 [widget-app-intent-setup.md](widget-app-intent-setup.md))*；「去年今日」待做 | 纯本地、几乎不增后端负担，却立刻有「系统级存在感」，杠杆最高 |
| **内容阶段** | Journaling Suggestions + Foundation Models 故事片 + StandBy 回放 | 接「AI 故事片 / 怀念」主线 |
| **社交阶段** | SharePlay + CloudKit 共享 + 好友 | 放大「一起」，但需自建/付费层与合规 |

## 合规与气质提醒
- ⚠️ **儿童安全 / 年龄分级**：Apple 对含社交功能的 App 自 **2026 年中**起有新的儿童安全与年龄分级问卷要求。
  做好友 + 亲子前务必核对这条。
- 🔒 **隐私即卖点**：CLVisit、Foundation Models 端上推理、CloudKit 私有库本身都隐私友好，与
  「个人 / 家庭记忆」定位同气质，可作为卖点而非纯技术细节。

---

*纪要记录于 dogfood 阶段；具体能力的最新 API 形态以接入时复核 Apple 文档为准。*
