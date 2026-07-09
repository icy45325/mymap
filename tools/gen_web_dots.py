#!/usr/bin/env python3
# 官网点阵地图数据生成器：data/admin0.json（173 国 MultiPolygon，等距圆柱）
# → 128×64 网格 point-in-polygon → 每行 32 个 hex 字符的位图（~2KB），嵌进 docs/index.html 的 DOTS 常量。
# 用法：python3 tools/gen_web_dots.py            # 打印 JS 数组
#       python3 tools/gen_web_dots.py --swift    # 打印 Swift 源（Lumi/Features/Map/DotMatrixLand.swift）
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

SWIFT_TEMPLATE = '''\
// 由 tools/gen_web_dots.py --swift 生成（data/admin0.json → %(w)d×%(h)d point-in-polygon），勿手改。
// 与 docs/index.html 的 DOTS 常量同源同值：官网首屏点阵地图与 App 点阵陆地共用这份轮廓。

/// 点阵陆地位图：等距圆柱投影，lon [%(lon0)s, %(lon1)s] / lat [%(lat0)s, %(lat1)s]（顶裁北极圈以上、底裁南极）。
enum DotMatrixLand {
    static let gridW = %(w)d, gridH = %(h)d
    static let lonMin = %(lon0)s, lonMax = %(lon1)s
    static let latTop = %(lat0)s, latBottom = %(lat1)s

    /// 每行 %(hexw)d 个 hex 字符（%(w)d bit，最高位=西经 %(lon1)s°）。
    static let rows: [String] = [
%(rows)s
    ]

    /// 解析后的位图（每行 2×UInt64，启动时一次解码）。
    static let bits: [[UInt64]] = rows.map { r in
        [UInt64(r.prefix(16), radix: 16)!, UInt64(r.suffix(16), radix: 16)!]
    }

    static func land(gx: Int, gy: Int) -> Bool {
        guard gx >= 0, gx < gridW, gy >= 0, gy < gridH else { return false }
        return (bits[gy][gx / 64] >> (63 - gx %% 64)) & 1 == 1
    }

    /// 网格中心的经纬度（与 web 的 cellOf 同口径的反向映射）。
    static func coordinate(gx: Int, gy: Int) -> (lon: Double, lat: Double) {
        (lonMin + (lonMax - lonMin) * (Double(gx) + 0.5) / Double(gridW),
         latTop + (latBottom - latTop) * (Double(gy) + 0.5) / Double(gridH))
    }
}
'''

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
    if '--swift' in sys.argv:
        body = '\n'.join('        "%s",' % r for r in rows)
        print(SWIFT_TEMPLATE % dict(w=W, h=H, hexw=W // 4, rows=body,
                                    lon0='%.1f' % LON0, lon1='%.1f' % LON1,
                                    lat0='%.1f' % LAT0, lat1='%.1f' % LAT1), end='')
    else:
        print('const DOTS = [')
        for r in rows:
            print('"%s",' % r)
        print('];')
    print('// grid %dx%d lon[%s,%s] lat[%s,%s]' % (W, H, LON0, LON1, LAT0, LAT1), file=sys.stderr)

if __name__ == '__main__':
    main()
