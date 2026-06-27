#!/usr/bin/env python3
"""把 data/badge/<lang>/<key>.png 抠图 → Lumi/Assets.xcassets/badge_<key>_<lang>.

读取：data/badge/{en,zh,ar}/<key>.png  （单张按 key 命名；已抠好或浅灰/透明底均可）
输出：Lumi/Assets.xcassets/badge_<key>_<lang>.imageset/  （去底→透明、autocrop）

用法（仓库根目录）：python3 data/badge/_crop.py [en|zh|ar]   不带参数=处理三种
依赖：Pillow
注：整张 6/9 连拼图（_sheet.png）需按布局定圆心，单独脚本处理，此处跳过。
"""
import os, sys
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(ROOT, "data", "badge")
ASSETS = os.path.join(ROOT, "Lumi", "Assets.xcassets")
LANGS = ["en", "zh", "ar"]


def remove_bg(im, tol=24):
    """从四边 flood fill 把背景抠成透明，保留主体内部。
    若本身就是透明底（边角 alpha≈0），只按 alpha 判背景，**不**做颜色键，
    避免误伤深色徽章内部（如暗底六边形）。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    transparent_src = sum(c[3] for c in corners) // 4 < 12
    br = sum(c[0] for c in corners) // 4
    bg = sum(c[1] for c in corners) // 4
    bb = sum(c[2] for c in corners) // 4

    def is_bg(p):
        if p[3] < 12:
            return True
        if transparent_src:
            return False
        if abs(p[0] - br) <= tol and abs(p[1] - bg) <= tol and abs(p[2] - bb) <= tol:
            return True
        mx, mn = max(p[0], p[1], p[2]), min(p[0], p[1], p[2])
        return mx - mn <= 20 and (p[0] + p[1] + p[2]) // 3 >= 185  # 近白/浅灰

    visited = bytearray(w * h)
    dq = deque()
    for x in range(w):
        dq.append((x, 0)); dq.append((x, h - 1))
    for y in range(h):
        dq.append((0, y)); dq.append((w - 1, y))
    while dq:
        x, y = dq.popleft()
        i = y * w + x
        if visited[i]:
            continue
        visited[i] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                dq.append((nx, ny))
    return im


def autocrop(im, pad=8):
    b = im.split()[3].getbbox()
    if not b:
        return im
    l, t, r, bm = b
    return im.crop((max(0, l - pad), max(0, t - pad),
                    min(im.width, r + pad), min(im.height, bm + pad)))


def write_imageset(im, asset_name):
    if max(im.size) > 560:
        s = 560 / max(im.size)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    d = os.path.join(ASSETS, asset_name + ".imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, asset_name + ".png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    {\n      "filename" : "%s.png",\n'
                '      "idiom" : "universal"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' % asset_name)
    print(f"  {asset_name}  {im.size}")


def main():
    langs = [sys.argv[1]] if len(sys.argv) > 1 else LANGS
    n = 0
    for lang in langs:
        d = os.path.join(SRC_DIR, lang)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.lower().endswith(".png") or fn.startswith("_"):
                continue
            key = os.path.splitext(fn)[0]
            im = Image.open(os.path.join(d, fn))
            write_imageset(autocrop(remove_bg(im)), f"badge_{key}_{lang}")
            n += 1
    print(f"done. {n} imageset(s).")


if __name__ == "__main__":
    main()
