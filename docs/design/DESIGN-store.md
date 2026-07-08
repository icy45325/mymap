# 资源商店设计（邮票 · 邮戳 · 明信片素材 · 主题）

> 2026-07-07 首版。目标：把「邮票等可定制资源」产品化为**多主题资源包商店**——用户可选、可收集、可购买；
> 明信片正面从「只能用户照片」扩展到「可从商店选素材」。
> 配套：[`ARCHITECTURE.md` §4.1 资源管线](../architecture/ARCHITECTURE.md)、[`PRODUCT-MAP.md` §2 变现地图](../product/PRODUCT-MAP.md)、
> [`DESIGN-monetization.md`](DESIGN-monetization.md)（早期变现设计，本文细化其「一次性装饰内购」方向）。

## 0. 决策记录（ICY 可直接批注调整）

| # | 决策 | 状态 |
|---|---|---|
| D1 | 商业模式：**混合制**——功能类永久归 Plus；商店资源包分**常规包（Plus 免费领）**与**限量/联名包（人人单买，Plus 折扣）** | ✅ 已定（ICY 07-08） |
| D2 | 分发：**基础内置，增值远程**——基础/常规包随 App 打包（零服务端），增值包（限量/联名/付费）v1.2 起走 Supabase Storage 远程下发；manifest 协议两端同构 | ✅ 已定（ICY 07-08） |
| D3 | 版本落位：**商店主体 v1.2（与账号同版）**；v1.15 先做内置资源包预热（走现有 Plus 门控，无独立购买） | ✅ 已定（ICY 07-08） |
| D4 | 正面素材形态：**官方插画/画框模板 + 照片滤镜质感**先行；背面信纸/花字/贴纸纳入品类规划但排后 | ✅ 已定（ICY 07-08） |
| D5 | 早鸟承诺口径：早鸟终身会员 = 所有**功能**迭代 + 商店**常规包**；限量/联名属收藏品类不在承诺内（Plus 享折扣）。**Paywall 文案已按此口径更新（07-08）** | ✅ 已定（ICY 07-08） |

## 1. 品类分类学（ContentPack.category）

| category | 内容 | 现状对应 | 可用性规则 |
|---|---|---|---|
| `stamp` 邮票包 | 地区 / 节日 / 典藏 / 古代（时间长河💡预留） | RegionalStamp(手绘) · Festival(6) · PremiumStamp(14) | 复用现有：地区限本国足迹、节日限窗口±5天+地区、典藏限国家/子区域 |
| `postmark` 邮戳包 | 按国家/地区/节日的收件邮戳 | 通用 LUMI 圆章 1 枚（图鉴已留「敬请期待」位） | 收件人侧渲染；寄达才盖 |
| `cardFront` 正面素材 | 城市插画整面模板 · 画框/边框叠层 · 照片滤镜 | 无（正面=用户照片） | 模板可替代照片；画框/滤镜叠加照片 |
| `cardBack` 背面素材 | 信纸纹理 · 花字 · 贴纸 | 无 | 排后（D4） |
| `theme` 大主题 | AppTheme 扩展（配色+地图+图标一套） | neon/aurora/sunset 3 套 | 全局唯一激活 |
| `passport` 护照风格 | 封面/内页风格 | classic/starlit 2 套 | 全局选择 |

**统一抽象 ContentPack**：所有品类共用一个包模型——`id`、`category`、`items[]`（条目）、预览资源、
定价档（§4）、可用性规则（复用 Festival 窗口 / RegionalStamp 地区匹配机制，规则参数进 manifest 而非写死代码）。

## 2. manifest 协议（内置与远程同构）

```jsonc
// packs/index.json —— 货架目录（v1.15 在 bundle；v1.2 同一文件放 Supabase Storage）
{
  "schemaVersion": 1,
  "packs": [{
    "id": "jp-classics",              // 全局唯一，进 raw 编码，永不复用
    "category": "stamp",
    "version": 2,                      // 包内容版本（远程增量更新用）
    "minAppVersion": "1.15",           // 老客户端自动隐藏看不懂的包
    "name": { "zh": "日本·浮世绘", "en": "Japan Classics", "ar": "…" },
    "pricing": "plus",                 // free | plus | paid:<tier>（限量/联名）
    "productID": null,                 // pricing=paid 时 = com.lumi.pack.jp-classics
    "availability": {                  // 可用性规则（可选，缺省=无限制）
      "countryCodes": ["JP"],          // 限定国家足迹
      "festivalWindow": null           // 或 {"month":12,"day":25,"span":5}
    },
    "preview": "pack_jp_classics",     // 货架预览图资源名/URL
    "items": [{
      "id": "fuji",                    // raw = pack:jp-classics/fuji
      "name": { "zh": "富士山", "en": "Mt. Fuji", "ar": "…" },
      "render": { "type": "image", "asset": "prem_jp_fuji" }
      // 或 { "type": "coded", "renderer": "regional.JP" } —— SwiftUI 手绘票引用渲染器 id
    }]
  }]
}
```

要点：
- **同一 schema 两种宿主**：v1.15 读 bundle，v1.2 读远程（下载→缓存目录→sha256 校验）；加载器不感知来源。
- `render.type` 双轨：`image`（美术图，imageset 或远程图）与 `coded`（保留现有 SwiftUI 手绘渲染器，manifest 只引用 id）。
- 三语名进 manifest（远程上新不依赖 App 发版的本地化）。

## 3. 现有目录迁移（v1.15，一次性）

| 现状硬编码 | 迁移后 | 兼容 |
|---|---|---|
| `RegionalStamp.all`（手绘） | 内置包 `regional-classic`（items render=coded） | raw `cc:XX` **保持不变**，仅目录数据化 |
| `PremiumStamp.all`（14 imageset） | 内置包 `premium-ae/cn/jp/us` 四包（pricing=plus） | raw `prem:id` 不变 |
| `Festival` 6 节日 | 内置包 `festival-classic`（availability.festivalWindow） | raw `fest:id` 不变 |
| 基础海陆空 | **不迁移**（产品保底，永远硬编码兜底） | — |

三条不变量（同 [`ARCHITECTURE.md` §4.1](../architecture/ARCHITECTURE.md)）：**raw 只增不改**；
**接收端降级**（未拥有/未知 → 基础渲染但保留原始 raw，装包后自动还原）；**manifest 同构**。

## 4. 权益与定价（混合制细则，D1/D5）

| pricing 档 | 谁能用 | StoreKit |
|---|---|---|
| `free` | 所有人（如地区手绘票——解锁条件是玩法不是钱） | — |
| `plus` | Plus 免费领；非 Plus 见锁+升级入口（现典藏票模式） | 随 `com.lumi.plus.lifetime` |
| `paid:collector` | 人人可买；Plus 自动 8 折档（用 StoreKit 价格档实现：双 SKU 或促销价） | `com.lumi.pack.<id>` Non-Consumable |

- 恢复购买：沿用现有 `PlusStore` 恢复流程扩展到 pack SKU。
- **v1.2 账号认领**：登录后把 Apple 交易映射的已购 pack 写云端（同 box_id 认领模式）；未登录期间购买照常（凭据在 Apple）。
- ✅ 早鸟文案已按 D5 口径落地（07-08）：Paywall 权益点/法务说明/副标题 →「后续所有功能迭代与常规内容包（限量/联名款除外，会员享折扣）」。

## 5. 商店 UI

- **入口**：`CustomizeShowcaseView`（个性化展示台）升级为「商店」页（Me 页入口改名）；图鉴锁定条目点击 → 跳对应包详情。
- **货架**：按品类分区横滑（邮票包 / 邮戳包 / 正面素材 / 主题…），包卡片 = 预览图 + 名称 + 价签（免费领/Plus/价格）。
- **包详情**：条目网格预览（邮票用现有 `StampView`）+ 可用性说明（"限日本足迹使用"）+ 获取按钮三态（免费领/随 Plus/购买）。
- **已拥有**：我的包列表 + 在编辑器内的呈现（邮票选择器按包分组，拥有的在前，未拥有露 1-2 枚作入口——现典藏票模式推广）。
- 明信片编辑器接入：正面素材 = 照片选择器旁增「素材库」标签页；滤镜 = 照片上的强度滑杆。

## 6. 交换兼容性（协议约束）

收到明信片含未拥有的 pack 资源时：
1. 正常收取入库（**不因资源缺失拒收**），`stampStyle`/正面素材 id 原样保存；
2. 渲染回落：邮票→`.air`，正面模板→发送时随口令携带的压缩封面图（口令本就带图，天然兜底），滤镜→原图；
3. 明信片详情露一行「此卡使用了『日本·浮世绘』邮票」→ 点击进包详情（**收明信片成为商店获客入口**）；
4. 装包/购买后自动按原样渲染（因为 raw 从未被改写）。

## 7. 分阶段落地

| 阶段 | 内容 | 前置 |
|---|---|---|
| **v1.15 预热** | ✅ **地基已落**（2026-07-08，不依赖 D1–D5）：`Lumi/Store/ContentPack.swift`（模型）+ `PackCatalog.swift`（Bundle 加载器 + `pack:` raw 解析 + 渲染分发 + DEBUG 一致性自检）+ `Lumi/Resources/StorePacks.json`（四类现有目录元数据镜像 33 条，legacyRaw 链接旧编码）+ `StampKind.pack`（raw 保留式解析，渲染侧降级）。**待 D1–D5 后**：图鉴/选择器改读 manifest、新内置包试水、权益门控 | 地基无前置；后续依赖 D1–D5 |
| **v1.2 开张** | 远程 manifest + Storage 下发；`paid` 档 + pack SKU + 恢复；商店页/包详情；正面素材品类首发；购买云端化 | 账号（同版） |
| **v1.3 共创** | 创作者投稿（上传→审核状态机→上架）；分成记账；举报/下架 | 商店已开张 |

## 8. 验收要点

1. 迁移后老明信片/老口令渲染与迁移前逐像素一致（raw 兼容）；
2. 未拥有资源的卡：收取成功 + 降级渲染 + 升级入口可达 + 购买后还原；
3. pricing 三档的获取/恢复/Plus 折扣全通；
4. 远程 manifest 拉取失败 → 回落最近缓存/内置目录，商店永不白屏；
5. 提审构建（远程未配置）：商店只展示内置包，体验完整。
