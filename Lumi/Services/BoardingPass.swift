import Foundation

/// 登机牌里的一段航程（解析结果，尚未查坐标）。
struct BoardingPassLeg {
    let from: String            // 出发机场 IATA 三字码
    let to: String              // 到达机场 IATA 三字码
    let carrier: String         // 承运航司二/三字码（如 EK）
    let flightNumber: String    // 规整后的航班号（如 EK307）
    let date: Date?             // 航班日期（儒略日推得，可能为空）
}

/// 一张登机牌的解析结果。
struct BoardingPass {
    let passengerName: String
    let legs: [BoardingPassLeg]
}

/// IATA BCBP（Bar Coded Boarding Pass，Resolution 792）文本解析。
///
/// 登机牌条码（纸质多为 PDF417）解码后是一段定长文本：
/// 23 字节唯一头（格式码 M/S + 航段数 + 姓名20 + 电子票标识）+ 每段 37 字节强制区 + 变长条件区。
/// 我们只取每段的 起降机场 / 航司 / 航班号 / 儒略日。纯本地解析，不联网。
enum BCBP {

    static func parse(_ raw: String) -> BoardingPass? {
        let s = Array(raw)
        guard s.count > 23 else { return nil }
        guard s[0] == "M" || s[0] == "S" else { return nil }
        guard let legCount = Int(String(s[1])), (1...9).contains(legCount) else { return nil }
        let name = String(s[2..<22]).trimmingCharacters(in: .whitespaces)

        var idx = 23
        var legs: [BoardingPassLeg] = []

        for _ in 0..<legCount {
            guard idx + 37 <= s.count else { break }
            func take(_ n: Int) -> String { let r = String(s[idx..<idx + n]); idx += n; return r }

            _ = take(7)                                                     // PNR
            let from    = take(3).trimmingCharacters(in: .whitespaces).uppercased()
            let to      = take(3).trimmingCharacters(in: .whitespaces).uppercased()
            let carrier = take(3).trimmingCharacters(in: .whitespaces).uppercased()
            let flight  = take(5).trimmingCharacters(in: .whitespaces)
            let julian  = take(3).trimmingCharacters(in: .whitespaces)
            _ = take(1)                                                     // 舱位
            _ = take(4)                                                     // 座位
            _ = take(5)                                                     // 值机序号
            _ = take(1)                                                     // 乘客状态
            let condLen = Int(take(2), radix: 16) ?? 0                      // 条件区字节数（16 进制）
            idx += min(condLen, max(0, s.count - idx))                      // 跳过条件区

            if from.count == 3, to.count == 3 {
                legs.append(BoardingPassLeg(from: from, to: to, carrier: carrier,
                                            flightNumber: normalizeFlight(carrier: carrier, raw: flight),
                                            date: dateFromJulian(julian)))
            }
        }
        return legs.isEmpty ? nil : BoardingPass(passengerName: name, legs: legs)
    }

    /// 航班号规整：去前导零并拼上航司码（"EK" + "0307" → "EK307"）。
    private static func normalizeFlight(carrier: String, raw: String) -> String {
        let trimmed = String(raw.drop(while: { $0 == "0" }))
        let num = trimmed.isEmpty ? raw : trimmed
        return carrier.isEmpty ? num : carrier + num
    }

    /// 儒略日（当年第几天，1...366）→ Date。年份缺失，选与今天最接近的年份（兼容去年/明年）。
    private static func dateFromJulian(_ j: String) -> Date? {
        guard let day = Int(j), (1...366).contains(day) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        let year = cal.component(.year, from: today)
        var best: Date?
        var bestDiff = Double.greatestFiniteMagnitude
        for y in [year - 1, year, year + 1] {
            var c = DateComponents(); c.year = y; c.month = 1; c.day = 1
            guard let jan1 = cal.date(from: c),
                  let date = cal.date(byAdding: .day, value: day - 1, to: jan1) else { continue }
            let diff = abs(date.timeIntervalSince(today))
            if diff < bestDiff { bestDiff = diff; best = date }
        }
        return best
    }
}
