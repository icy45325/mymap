# 徽章源图（按语言分）

把你的徽章图放这里，我会抠图（去灰底→透明）并按语言生成进 `Lumi/Assets.xcassets`。
App 会**按系统语言**自动挑对应语言版本；缺某个语言就回退到现有那张，不会空白或崩溃。

## 放图方式（推荐：每种语言一张拼图）

每种语言放**一张 3×2 的六连拼图**，文件名用语言代码：

| 文件 | 语言 |
|------|------|
| `zh.png` | 中文 |
| `en.png` | 英文 |
| `ar.png` | 阿拉伯语 |

**布局必须一致**（和最初那张一样），顺序为：

```
┌──────────┬──────────┬──────────┐
│  亚洲     │  非洲     │  欧洲     │   ← 第 1 排
│  asia     │  africa   │  europe   │
├──────────┼──────────┼──────────┤
│  大洋洲   │  美洲     │  南极洲   │   ← 第 2 排
│  oceania  │  americas │antarctica │
└──────────┴──────────┴──────────┘
```

要点：
- **浅灰纯色背景**（方便干净抠图），每枚徽章在各自格子里居中。
- 三种语言只是**徽章上的文字**不同，图案/构图尽量保持一致。
- 不必三种都给——先给哪种我就生成哪种，其余语言自动回退。

## 命名（若你想单枚单语言地给，也支持）

可选另一种方式：单枚单语言文件 `<大洲>_<语言>.png`，例如
`asia_en.png`、`africa_ar.png`、`europe_zh.png`（大洲键见上表英文）。

## 全部徽章 key（命名参照）

大洲（已落地，含双语底图 `badge_<key>` + 英文版 `badge_<key>_en`）：
`asia` · `africa` · `europe` · `oceania` · `americas` · `antarctica`

里程碑 / 其它（已落地英文版，存为基名 `badge_<key>`，作为各语言默认）：
`first`（First Light）· `five`（Five Countries）· `cities`（Hundred Cities）·
`continents`（All Continents）· `desert`（Desert Pioneer）· `jungle`（Jungle Explorer）·
`island`（Island Hopper）· `antarcticaPro`（Antarctica Pioneer）

**尚缺**：`world`（Globetrotter 环球旅行家）——还没有插画，暂用水晶徽章。

> 当前这些都是**英文**版：里程碑存为基名 `badge_<key>`（英文即默认，其它语言暂回退到它）；
> 大洲英文存为 `badge_<key>_en`（中/阿回退到双语底图）。
> 以后给中文 / 阿语，放 `<key>_zh.png` / `<key>_ar.png`（或整张 `zh.png`/`ar.png` 拼图），我生成 `badge_<key>_<lang>` 覆盖。

## 生成

放好后告诉我，我会运行抠图脚本生成：
`badge_<大洲>_<语言>` 共最多 18 个 imageset（如 `badge_asia_en`、`badge_asia_ar`…），
并确认 app 三语下显示正确。

> 当前的 `data/badge.png`（中英双语那张）已抠成 `badge_<大洲>` 作为**回退底图**。
