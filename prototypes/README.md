# Lumi 原型（prototypes）

**视觉原型 / spec，不参与 App 构建、不进 WebView。** 用浏览器打开即可，用来在写原生代码前锁定观感与参数。

- [`badge-wall.html`](badge-wall.html) — three.js **3D 水晶徽章墙**原型（premium）：
  - 一墙逐徽章霓虹色水晶（`MeshPhysicalMaterial`：清漆 / 虹彩 / 透光 / 高 IOR），
    环境贴图(PMREM) 真实反射 + `UnrealBloom` 辉光 + ACES 色调映射；
  - 居中**清晰徽记**（512px 高 anisotropy 纹理，不糊）；
  - 拖拽 / 陀螺仪倾斜看折射流光；水晶 idle 自转 + 浮动；
  - 点击徽章 → 飞到中心放大 + 升级为真玻璃 + 旋转 + 磨砂玻璃详情面板；
  - 「模拟解锁 ✦」→ cinematic：水晶弹簧放大 + bloom 闪光 + 粒子迸发 + 冲击波环 + 名称揭示。
  - 原生对齐：iOS 用 **SceneKit** 真 3D 水晶（PBR 逐徽章着色 + 点光 + CoreMotion）做详情/解锁，
    墙用 SceneKit **快照**保证流畅，徽记用清晰 `Image(systemName:)`。**生产实现为原生，不用本 HTML。**

> 打开方式：直接双击 `badge-wall.html`，或 `python3 -m http.server` 后访问（陀螺仪需 HTTPS / 用户授权）。
