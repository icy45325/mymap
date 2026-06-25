# Lumi 原型（prototypes）

**视觉原型 / spec，不参与 App 构建、不进 WebView。** 用浏览器打开即可，用来在写原生代码前锁定观感与参数。

- [`badge-wall.html`](badge-wall.html) — three.js 全息徽章墙原型：
  - 蜂巢徽章（参考表节选，逐徽章霓虹色）；
  - 移动鼠标 / 倾斜手机（陀螺仪）→ 全息箔流光与扫光带偏移；
  - 点击徽章 → 半浮窗大图（前移放大 + 自转 + 全息）；
  - 「模拟解锁 ✦」→ pop + 粒子迸发。
  - 原生对齐：iOS 用 SwiftUI + Metal shader（`.layerEffect`/`.colorEffect`）+ CoreMotion 复刻流光与倾斜，
    粒子用 `TimelineView`+`Canvas` 或 SpriteKit。**生产实现为原生，不用本 HTML。**

> 打开方式：直接双击 `badge-wall.html`，或 `python3 -m http.server` 后访问（陀螺仪需 HTTPS / 用户授权）。
