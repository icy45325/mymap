import Foundation
import SwiftData

/// 旅程候选：从散点足迹自动聚类出的「一段旅程」（同国家 + 时间相邻 ≤3 天合并）。
/// 名称 / 日期范围 / 足迹数 / 旅伴并集全部自动派生——用户在创建交换日记时选一个即可，零填写。
struct TripCandidate: Identifiable {
    let id: String                 // 稳定键：国家码 + 起始日
    let title: String              // 「迪拜之旅」/「英国之旅」
    let countryCode: String?
    let start: Date
    let end: Date
    let footprints: [Footprint]    // 按 visitedAt 升序
    let companions: [String]       // 段内旅伴并集（保序去重）
    /// 已有 Trip 实体则复用（足迹曾挂过 Trip）。
    let existingTrip: Trip?

    var dateRangeText: String {
        let f: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()
        let s = start.formatted(f)
        return Calendar.current.isDate(start, inSameDayAs: end) ? s : "\(s) – \(end.formatted(f))"
    }
}

/// 旅程聚类 + 落地：交换日记「本必绑 Trip」的地基（Trip 从此业务化）。
@MainActor
enum TripSuggest {

    /// 相邻足迹间隔 ≤3 天视为同一段旅程。
    private static let gapDays = 3

    /// 全部候选旅程（新→旧）。已挂 Trip 的足迹按其 Trip 原样成段。
    /// 只聚自己去过的足迹（收到的明信片不构成旅程）。
    static func candidates(from allFootprints: [Footprint]) -> [TripCandidate] {
        let footprints = allFootprints.filter { !$0.isReceived }
        var out: [TripCandidate] = []

        // 1) 已有 Trip 的直接成段
        let grouped = Dictionary(grouping: footprints.filter { $0.trip != nil }) { $0.trip!.id }
        for (_, fps) in grouped {
            let sorted = fps.sorted { $0.visitedAt < $1.visitedAt }
            guard let first = sorted.first, let trip = first.trip else { continue }
            out.append(make(sorted, title: trip.title, trip: trip))
        }

        // 2) 散点按 国家 + 时间相邻 聚类
        let loose = footprints.filter { $0.trip == nil }
        let byCountry = Dictionary(grouping: loose) { $0.countryCode ?? "??" }
        for (_, fps) in byCountry {
            let sorted = fps.sorted { $0.visitedAt < $1.visitedAt }
            var segment: [Footprint] = []
            for fp in sorted {
                if let last = segment.last {
                    let lastEnd = last.endedAt ?? last.visitedAt
                    let gap = Calendar.current.dateComponents([.day], from: lastEnd, to: fp.visitedAt).day ?? 0
                    if gap > gapDays {
                        out.append(make(segment, title: nil, trip: nil))
                        segment = []
                    }
                }
                segment.append(fp)
            }
            if !segment.isEmpty { out.append(make(segment, title: nil, trip: nil)) }
        }

        return out.sorted { $0.start > $1.start }
    }

    /// 足迹所属的候选旅程（足迹详情入口用：自动命中、跳过「选旅程」）。
    static func candidate(containing footprint: Footprint, in footprints: [Footprint]) -> TripCandidate? {
        candidates(from: footprints).first { c in c.footprints.contains { $0.id == footprint.id } }
    }

    /// 把候选落成 Trip 实体（幂等：已有 existingTrip 直接返回；否则创建并把足迹挂上）。
    static func materialize(_ c: TripCandidate, context: ModelContext) -> Trip {
        if let trip = c.existingTrip { return trip }
        let trip = Trip(title: c.title)
        context.insert(trip)
        for fp in c.footprints { fp.trip = trip }
        try? context.save()
        return trip
    }

    private static func make(_ fps: [Footprint], title: String?, trip: Trip?) -> TripCandidate {
        let first = fps.first!
        let end = fps.map { $0.endedAt ?? $0.visitedAt }.max() ?? first.visitedAt
        // 名称：城市唯一用城市，否则用国家；「XX 之旅」
        let cities = Set(fps.compactMap(\.cityName))
        let place = cities.count == 1 ? cities.first!
            : (CountryInfo.localizedName(for: first.countryCode) ?? first.placeName)
        var seen = Set<String>(), mates: [String] = []
        for name in fps.flatMap(\.companions) {
            let k = name.lowercased()
            if !k.isEmpty, !seen.contains(k) { seen.insert(k); mates.append(name) }
        }
        return TripCandidate(id: "\(first.countryCode ?? "??")-\(Int(first.visitedAt.timeIntervalSince1970))",
                             title: title ?? String(localized: "\(place) 之旅"),
                             countryCode: first.countryCode,
                             start: first.visitedAt, end: end,
                             footprints: fps, companions: mates,
                             existingTrip: trip)
    }
}
