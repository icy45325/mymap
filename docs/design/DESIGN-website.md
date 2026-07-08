# 官网设计（docs/index.html · GitHub Pages）

> 2026-07-08 重做版。单文件自包含（无外链 CDN），三语（zh/en/ar 含 RTL），Pages 跟 main 分支。

## 灵感参考（ICY 2026-07-08 提供）

| 站点 | 记录要点 |
|---|---|
| https://50-jahre-hitparade.ch/ | 叙事式长页滚动、数据可视化融进页面结构 |
| https://wantedfornothing.com/ | 大字排版、强个性视觉 |
| https://bahamabucks.com/ | **首页元素漂浮效果**（装饰元素缓慢漂浮/视差，ICY 点名想要） |

## 首屏（可玩 demo，产品核心回路网页化）

1. LUMI ✦ 渐变大 logo + 一句话产品定义；装饰元素（邮票/纸飞机/明信片 SVG）**缓慢漂浮**（参考 bahamabucks）。
2. **交互点阵地图**（canvas 等距圆柱 128×64，数据由 `tools/gen_web_dots.py` 从 `data/admin0.json` 生成，
   复刻 App `DotMatrixMapView` 观感）：暗紫陆地点阵 + 6 个预亮城市（东京/巴黎/迪拜/纽约/新加坡/伊斯坦布尔）
   霓虹粉呼吸脉冲。
3. 交互回路：点亮点 → 明信片编辑卡（vintage 卡面 + 手写寄语可改 + 3 枚 SVG 地区票可选）→ 寄出
   （卡片飞向地图另一端）→ 1.2s 后通知条「收到一张来自 XX 的明信片」→ 点开翻面查看，**邮戳浮现**
   （复刻「寄达才盖戳」细节）。
4. 下载 CTA：App Store（`APPSTORE_URL` 常量，上架后回填）+ Android 虚位以待。

## 下方功能区（CSS/SVG 复刻 App 视觉）

点亮地图（小点阵自动逐城点亮+计数）· 明信片与邮票（齿孔票横排+翻面卡）· 护照与成就（暗金封面+
ADMITTED 章+六边形徽章）· Lumi 邮局（邮箱号卡+直寄示意）· 三语与隐私。
色板 = App Tokens：`#0E0B1A / #1A1530 / #FF4FA3 / #9B5DE5 / #4DD9FF / #FFA94D`。

## 维护

- 点阵数据重生成：`python3 tools/gen_web_dots.py`（改网格/裁切范围后重嵌 DOTS 常量）。
- 上架后：`index.html` 顶部 `APPSTORE_URL` 填真实链接。
- 验证：容器内 Playwright/Chromium 截图全交互链路 + 三语 + 390px 响应式。
