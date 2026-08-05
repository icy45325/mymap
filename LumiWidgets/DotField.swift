import SwiftUI

/// 点阵星图：暗底上一片低亮度网点，少数点位被「点亮」成橙色光点。
///
/// 点位由已点亮国家码**确定性**映射到网格（同一份数据每次渲染位置稳定），
/// 复刻产品示意图左侧的星座观感。无随机、无外部依赖，纯绘制。
struct DotField: View {

    let litCodes: [String]
    var cols: Int = 11
    var rows: Int = 7
    var baseDot: CGFloat = 3
    var litDot: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let cw = geo.size.width / CGFloat(cols)
            let ch = geo.size.height / CGFloat(rows)
            let lit = litCells

            ZStack {
                // 底网点
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: baseDot, height: baseDot)
                            .position(x: cw * (CGFloat(c) + 0.5),
                                      y: ch * (CGFloat(r) + 0.5))
                    }
                }
                // 点亮光点
                ForEach(lit, id: \.self) { idx in
                    let c = idx % cols, r = idx / cols
                    Circle()
                        .fill(WidgetTheme.lit)
                        .frame(width: litDot, height: litDot)
                        .shadow(color: WidgetTheme.lit.opacity(0.9), radius: 5)
                        .position(x: cw * (CGFloat(c) + 0.5),
                                  y: ch * (CGFloat(r) + 0.5))
                }
            }
        }
    }

    /// 国家码 → 网格序号（djb2 哈希取模），去重后稳定布局。
    private var litCells: [Int] {
        let total = max(cols * rows, 1)
        var cells = Set<Int>()
        for code in litCodes {
            var hash = 5381
            for byte in code.utf8 { hash = (hash &* 33) &+ Int(byte) }
            cells.insert(abs(hash) % total)
        }
        return cells.sorted()
    }
}
