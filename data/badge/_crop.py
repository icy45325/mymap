#!/usr/bin/env python3
"""按语言把 data/badge/ 里的徽章源图抠出来 → Lumi/Assets.xcassets。

读取：
  data/badge/<lang>.png        —— 3×2 六连拼图（lang ∈ zh/en/ar），布局见 README
  data/badge/<key>_<lang>.png  —— 可选：单枚单语言（key 见 KEYS）
输出：
  Lumi/Assets.xcassets/badge_<key>_<lang>.imageset/  （透明底，autocrop）

用法（仓库根目录）：python3 data/badge/_crop.py
依赖：Pillow
"""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(ROOT, "data", "badge")
ASSETS = os.path.join(ROOT, "Lumi", "Assets.xcassets")
LANGS = ["zh", "en", "ar"]
# 3×2 网格顺序（与 README / 原图一致）
KEYS = ["asia", "africa", "europe", "oceania", "americas", "antarctica"]


def remove_bg(im, tol=26):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    br = sum(c[0] for c in corners) // 4
    bg = sum(c[1] for c in corners) // 4
    bb = sum(c[2] for c in corners) // 4

    def is_bg(p):
        return abs(p[0] - br) <= tol and abs(p[1] - bg) <= tol and abs(p[2] - bb) <= tol

    visited = bytearray(w * h)
    dq = deque()
    for x in range(w):
        dq.append((x, 0)); dq.append((x, h - 1))
    for y in range(h):
        dq.append((0, y)); dq.append((w - 1, y))
    while dq:
        x, y = dq.popleft()
        idx = y * w + x
        if visited[idx]:
            continue
        visited[idx] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                dq.append((nx, ny))
    return im


def autocrop(im, pad=14):
    bbox = im.split()[3].getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    return im.crop((max(0, l - pad), max(0, t - pad),
                    min(im.width, r + pad), min(im.height, b + pad)))


def finish(cell):
    cell = autocrop(remove_bg(cell))
    if max(cell.size) > 600:
        s = 600 / max(cell.size)
        cell = cell.resize((round(cell.width * s), round(cell.height * s)), Image.LANCZOS)
    return cell


def write_imageset(cell, name):
    d = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    cell.save(os.path.join(d, f"{name}.png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    {\n      "filename" : "%s.png",\n'
                '      "idiom" : "universal"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' % name)
    print(f"  {name}  {cell.size}")


def main():
    n = 0
    for lang in LANGS:
        sheet = os.path.join(SRC_DIR, f"{lang}.png")
        if os.path.exists(sheet):
            im = Image.open(sheet).convert("RGBA")
            W, H = im.size
            cw, ch = W // 3, H // 2
            print(f"sheet {lang}.png -> {im.size}")
            for i, key in enumerate(KEYS):
                cx, cy = i % 3, i // 3
                cell = im.crop((cx * cw, cy * ch, (cx + 1) * cw, (cy + 1) * ch))
                write_imageset(finish(cell), f"badge_{key}_{lang}")
                n += 1
        # 单枚单语言
        for key in KEYS:
            p = os.path.join(SRC_DIR, f"{key}_{lang}.png")
            if os.path.exists(p):
                write_imageset(finish(Image.open(p).convert("RGBA")), f"badge_{key}_{lang}")
                n += 1
    print(f"done. {n} imageset(s) written.")


if __name__ == "__main__":
    main()
