// 由 tools/gen_web_dots.py --swift 生成（data/admin0.json → 128×64 point-in-polygon），勿手改。
// 与 docs/index.html 的 DOTS 常量同源同值：官网首屏点阵地图与 App 点阵陆地共用这份轮廓。

/// 点阵陆地位图：等距圆柱投影，lon [-180.0, 180.0] / lat [75.0, -58.0]（顶裁北极圈以上、底裁南极）。
enum DotMatrixLand {
    static let gridW = 128, gridH = 64
    static let lonMin = -180.0, lonMax = 180.0
    static let latTop = 75.0, latBottom = -58.0

    /// 每行 32 个 hex 字符（128 bit，最高位=西经 180.0°）。
    static let rows: [String] = [
        "00000c03000fff8000001801ff000000",
        "00001bacf80fff00000030fffffc3800",
        "03fc6bf60f07ff0001f000ffffffff86",
        "87ffffbfe387f00007fcffdfffffffff",
        "efffffffc347c1e00f73ffffffffffff",
        "11ffffff438380001effffffffffffff",
        "07fffffe0e0380003cffffffffffff7c",
        "0383fffc0e0000003c7ffffffffffa40",
        "0040fffe07c000021c7fffffffffc0c0",
        "02007fffcfe0000200ffffffffff01c0",
        "00003fffeff000073fffffffffffe180",
        "00001fffffe000037fffffffffffc000",
        "00001fffff980001ffffffffffffe000",
        "00000fffff800001fffbffffffffa000",
        "00000fffff400000f7c7bfffffffa000",
        "00000ffffe0000078bc19ffffffe2000",
        "00000ffffc000007057fdffffffc0000",
        "00000ffff8000007017f9fffffcc0000",
        "000007fff8000000f037ffffffe4c000",
        "000007fff0000003f007ffffffe18000",
        "000003ffe0000007f90fffffffe20000",
        "000000ff60000007ffffffffffe00000",
        "000001fc0000000fffffbfffffe00000",
        "000000781800001ffff7cfffffe00000",
        "000000380000003ffffbd0ffffc00000",
        "000000381000003ffffbf87f7f000000",
        "0000003c8800003ffffbf83e7c000000",
        "0000000f8800003ffffdf03c3c000000",
        "000000014000003ffffde0381e000000",
        "00000000c000003fffff80181e100000",
        "000000004200003ffffe001006180000",
        "0000000025c0001ffffe401804000000",
        "000000000fe0000fffffc00810180000",
        "000000000ff800073fff800008400000",
        "000000000ffc00001fff800008c00000",
        "000000000ffc00001fff000011c40000",
        "000000001ffe00001ffe000009f10000",
        "000000000fffc0000ffc00000da1c000",
        "000000001fffe0000ffc000004207000",
        "000000000ffff00007fc000003007000",
        "000000000fffe00007fc000000080800",
        "000000000fffe00007fc000000000000",
        "0000000007ffc0000ffc400000032000",
        "0000000007ffc0000ffc4000000f3000",
        "0000000001ffc0000ff8c000001ff000",
        "0000000001ffc00007f88000001ff000",
        "0000000001ff800007f98000007ff800",
        "0000000001ff000007f8800000fffc00",
        "0000000001fe000007f00000007ffc00",
        "0000000001fe000003f00000007ffe00",
        "0000000001fc000003e00000007ffc00",
        "0000000001fc000003c00000007dfc00",
        "0000000003f800000100000000607c00",
        "0000000003f000000000000000003800",
        "0000000003e000000000000000002002",
        "0000000003c000000000000000000002",
        "00000000038000000000000000000804",
        "00000000038000000000000000000008",
        "00000000070000000000000000000000",
        "00000000070000000000000000000000",
        "00000000060000000000000000000000",
        "00000000030000000000000000000000",
        "00000000018000000000000000000000",
        "00000000000000000000000000000000",
    ]

    /// 解析后的位图（每行 2×UInt64，启动时一次解码）。
    static let bits: [[UInt64]] = rows.map { r in
        [UInt64(r.prefix(16), radix: 16)!, UInt64(r.suffix(16), radix: 16)!]
    }

    static func land(gx: Int, gy: Int) -> Bool {
        guard gx >= 0, gx < gridW, gy >= 0, gy < gridH else { return false }
        return (bits[gy][gx / 64] >> (63 - gx % 64)) & 1 == 1
    }

    /// 网格中心的经纬度（与 web 的 cellOf 同口径的反向映射）。
    static func coordinate(gx: Int, gy: Int) -> (lon: Double, lat: Double) {
        (lonMin + (lonMax - lonMin) * (Double(gx) + 0.5) / Double(gridW),
         latTop + (latBottom - latTop) * (Double(gy) + 0.5) / Double(gridH))
    }
}
