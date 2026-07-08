#!/usr/bin/env python3
# 官网点阵地图数据生成器：data/admin0.json（173 国 MultiPolygon，等距圆柱）
# → 128×64 网格 point-in-polygon → 每行 32 个 hex 字符的位图（~2KB），嵌进 docs/index.html 的 DOTS 常量。
# 用法：python3 tools/gen_web_dots.py            # 打印 JS 数组
import json, sys

W, H = 128, 64
LON0, LON1 = -180.0, 180.0
LAT0, LAT1 = 75.0, -58.0     # 顶部裁北极圈以上、底部裁南极（与 App 点阵观感一致）

def point_in_ring(x, y, ring):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside

def load_features():
    d = json.load(open('data/admin0.json'))
    feats = []
    for f in d['features']:
        polys = f['geometry']['coordinates']
        if f['geometry']['type'] == 'Polygon':
            polys = [polys]
        for poly in polys:
            outer = poly[0]
            xs = [p[0] for p in outer]; ys = [p[1] for p in outer]
            feats.append((min(xs), min(ys), max(xs), max(ys), poly))
    return feats

def main():
    feats = load_features()
    rows = []
    for gy in range(H):
        lat = LAT0 + (LAT1 - LAT0) * (gy + 0.5) / H
        bits = 0
        for gx in range(W):
            lon = LON0 + (LON1 - LON0) * (gx + 0.5) / W
            hit = False
            for (x0, y0, x1, y1, poly) in feats:
                if not (x0 <= lon <= x1 and y0 <= lat <= y1):
                    continue
                if point_in_ring(lon, lat, poly[0]):
                    # 挖洞（内环）
                    if not any(point_in_ring(lon, lat, hole) for hole in poly[1:]):
                        hit = True
                        break
            if hit:
                bits |= 1 << (W - 1 - gx)
        rows.append(format(bits, '0%dx' % (W // 4)))
    print('const DOTS = [')
    for r in rows:
        print('"%s",' % r)
    print('];')
    print('// grid %dx%d lon[%s,%s] lat[%s,%s]' % (W, H, LON0, LON1, LAT0, LAT1), file=sys.stderr)

if __name__ == '__main__':
    main()
