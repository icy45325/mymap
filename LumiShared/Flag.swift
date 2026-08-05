import Foundation

/// ISO_A2 → 国旗 emoji（区域指示符拼合）。App 与小组件共用（小组件 target 无 CountryInfo）。
func flagEmoji(_ code: String?) -> String {
    guard let raw = code, raw.count >= 2 else { return "🏳️" }
    let cc = String(raw.prefix(2)).uppercased()
    let base: UInt32 = 0x1F1E6   // 🇦
    var scalars = String.UnicodeScalarView()
    for a in cc.unicodeScalars {
        guard a.value >= 65, a.value <= 90, let s = UnicodeScalar(base + a.value - 65) else { return "🏳️" }
        scalars.append(s)
    }
    return String(scalars)
}
