# 徽章源图（按语言分文件夹）

把徽章图按语言放进 **`en/` `zh/` `ar/`** 三个子文件夹。App 会**按系统语言**挑对应语言版本；
缺某语言就回退到现有底图，不会空白或崩溃。

## 放图方式

每个语言文件夹里，按 **key** 命名单张图（已抠好或浅灰底/透明底均可）：

```
data/badge/
  en/asia.png  en/first.png  …   ← 英文版（当前已就位，可作模板参照）
  zh/asia.png  zh/first.png  …   ← 中文版（待你放）
  ar/asia.png  ar/first.png  …   ← 阿语版（待你放）
```

放好后告诉我，我会抠图（去底→透明、autocrop）并生成 `badge_<key>_<lang>` 进 `Lumi/Assets.xcassets`。

## 全部 key

大洲（6）：`asia` `africa` `europe` `oceania` `americas` `antarctica`
里程碑 / 其它（9）：`first`（First Light）`five`（Five Countries）`cities`（Hundred Cities）
`continents`（All Continents）`desert`（Desert Pioneer）`jungle`（Jungle Explorer）
`island`（Island Hopper）`antarcticaPro`（Antarctica Pioneer）`world`（Globetrotter，**尚缺图**）

> 也支持整张拼图：把一张 6 连 / 9 连图命名 `<lang>/_sheet.png` 放进对应语言夹，告诉我布局即可。
> 当前 `en/` 里的 15 张是上轮抠好的英文版（透明底），可作命名/构图参照。

## 解析规则（代码侧）

`Badge.resolvedImageName`：`badge_<key>` → 优先 `badge_<key>_<zh|en|ar>`，缺失回退基名。
- 大洲：基名 `badge_<key>` 是早期中英双语底图；英文版 `badge_<key>_en` 已就位。
- 里程碑：基名 `badge_<key>` 当前就是英文（各语言默认）；放了 zh/ar 后会以 `badge_<key>_<lang>` 覆盖。
