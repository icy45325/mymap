import SwiftUI
import SwiftData

/// 模拟护照本（写实风）：深蓝封面 + 米黄内页 + 各国出入境章。可左右翻页。
/// v1 用现有数据（国家/城市/日期）生成入境章；交通工具区分为后续。
struct PassportView: View {
    @Query(sort: \Footprint.visitedAt, order: .forward) private var footprints: [Footprint]

    // 个人资料（驱动护照持有人页与封面颜色）
    @AppStorage("lumi.profile.name") private var holderName: String = "旅行者"
    @AppStorage("lumi.profile.nationality") private var nationality: String = ""
    @AppStorage("lumi.profile.avatarID") private var avatarID: String = ""

    // 封面按国籍取色
    private var coverColors: (Color, Color) { PassportPalette.cover(for: nationality) }
    private var navy1: Color { coverColors.0 }
    private var navy2: Color { coverColors.1 }
    private let gold = Color(hex: 0xC9A24B)
    private let cream = Color(hex: 0xEDE6D6)
    private let inks: [Color] = [Color(hex: 0x1B3A5B), Color(hex: 0x7B2B3A),
                                 Color(hex: 0x2E5A3A), Color(hex: 0x1F5E5E), Color(hex: 0x4A3A6B)]

    private static let df: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    private struct Stamp: Identifiable {
        let id = UUID()
        let flag: String, country: String, place: String, year: String, date: String
        let ink: Color, angle: Double
    }

    private var stamps: [Stamp] {
        footprints.enumerated().map { i, fp in
            Stamp(flag: fp.flag,
                  country: fp.countryName ?? fp.placeName,
                  place: fp.title,
                  year: String(Calendar.current.component(.year, from: fp.visitedAt)),
                  date: fp.visitedAt.formatted(Self.df).uppercased(),
                  ink: inks[i % inks.count],
                  angle: Double((i * 37) % 13) - 6)
        }
    }
    private var pages: [[Stamp]] {
        let all = stamps
        return stride(from: 0, to: all.count, by: 4).map { Array(all[$0..<min($0 + 4, all.count)]) }
    }

    var body: some View {
        TabView {
            cover
            dataPage
            ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                innerPage(page, number: idx + 1)
            }
            if pages.isEmpty { emptyPage }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color(hex: 0x0A0A12).ignoresSafeArea())
        .navigationTitle("护照本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: 0x0A0A12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - 封面

    private var cover: some View {
        ZStack {
            LinearGradient(colors: [navy1, navy2], startPoint: .topLeading, endPoint: .bottomTrailing)
            RoundedRectangle(cornerRadius: 6).stroke(gold.opacity(0.7), lineWidth: 1.5)
                .padding(22)
            VStack(spacing: 16) {
                Text("LUMI · 世界护照").font(.system(size: 11, weight: .semibold)).tracking(3)
                    .foregroundStyle(gold.opacity(0.85))
                Spacer()
                Image(systemName: "globe.asia.australia.fill").font(.system(size: 58)).foregroundStyle(gold)
                    .overlay(Circle().stroke(gold.opacity(0.6), lineWidth: 1).frame(width: 92, height: 92))
                Text("PASSPORT").font(Typo.serif(34)).tracking(4).foregroundStyle(gold)
                Text("护照").font(Typo.serif(20)).foregroundStyle(gold.opacity(0.9))
                Spacer()
                Text("去过 \(LumiStats(footprints: footprints).countries) 国 · \(LumiStats(footprints: footprints).cities) 城")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(gold.opacity(0.8))
                Text("← 左右翻页 →").font(.system(size: 10)).foregroundStyle(gold.opacity(0.5))
            }
            .padding(.vertical, 54)
        }
        .padding(20)
    }

    // MARK: - 持有人资料页

    private var dataPage: some View {
        ZStack {
            cream
            RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0xC9B98E).opacity(0.6), lineWidth: 1).padding(16)
            VStack(alignment: .leading, spacing: 14) {
                Text("PASSPORT · 护照").font(.system(size: 11, weight: .bold)).tracking(2)
                    .foregroundStyle(Color(hex: 0x7A6E55))
                HStack(alignment: .top, spacing: 16) {
                    // 头像
                    Group {
                        if avatarID.isEmpty {
                            ZStack { Color(hex: 0xD9CDB2); Image(systemName: "person.fill")
                                .font(.system(size: 40)).foregroundStyle(Color(hex: 0x9A8E73)) }
                        } else {
                            AssetImage(assetID: avatarID, targetSize: CGSize(width: 300, height: 380))
                        }
                    }
                    .frame(width: 92, height: 116).clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0x9A8E73), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 9) {
                        field("姓名 / NAME", holderName.isEmpty ? "旅行者" : holderName)
                        field("国籍 / NATIONALITY",
                              nationality.isEmpty ? "—" : "\(flagEmoji(nationality)) \(CountryInfo.localizedName(for: nationality) ?? nationality)")
                        field("足迹 / FOOTPRINTS", "\(LumiStats(footprints: footprints).countries) 国 · \(LumiStats(footprints: footprints).cities) 城")
                    }
                }
                Spacer()
                Text("ISSUED BY LUMI · 世界护照").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Color(hex: 0x9A8E73))
            }
            .padding(.horizontal, 30).padding(.vertical, 34)
        }
        .padding(20)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundStyle(Color(hex: 0x9A8E73))
            Text(value).font(Typo.serif(15)).foregroundStyle(Color(hex: 0x3A3326)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: - 内页

    private func innerPage(_ page: [Stamp], number: Int) -> some View {
        ZStack {
            cream
            RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0xC9B98E).opacity(0.6), lineWidth: 1).padding(16)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("VISAS · 签证页").font(.system(size: 11, weight: .bold)).tracking(2)
                        .foregroundStyle(Color(hex: 0x7A6E55))
                    Spacer()
                    Text("— \(number) —").font(.system(size: 10)).foregroundStyle(Color(hex: 0x9A8E73))
                }
                .padding(.horizontal, 30).padding(.top, 30)
                Spacer()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 26) {
                    ForEach(page) { stampView($0) }
                }
                .padding(.horizontal, 26)
                Spacer()
            }
        }
        .padding(20)
    }

    private var emptyPage: some View {
        ZStack {
            cream
            VStack(spacing: 10) {
                Image(systemName: "airplane.departure").font(.system(size: 40)).foregroundStyle(Color(hex: 0x9A8E73))
                Text("护照还是空的").font(Typo.serif(20)).foregroundStyle(Color(hex: 0x5A5040))
                Text("去点亮第一个国家，盖下第一枚入境章").font(.system(size: 12)).foregroundStyle(Color(hex: 0x9A8E73))
            }
        }
        .padding(20)
    }

    private func stampView(_ s: Stamp) -> some View {
        VStack(spacing: 3) {
            Text("✦ ENTRY").font(.system(size: 8, weight: .bold)).tracking(1.5)
            HStack(spacing: 6) {
                Text(s.flag).font(.system(size: 18))
                Text(s.year).font(Typo.serif(22))
            }
            Text(s.country.uppercased()).font(.system(size: 8.5, weight: .bold)).tracking(0.5)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(s.date).font(.system(size: 7.5)).opacity(0.85)
        }
        .foregroundStyle(s.ink)
        .padding(.vertical, 11).padding(.horizontal, 14)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(s.ink, lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 9).inset(by: 3).stroke(s.ink.opacity(0.55), lineWidth: 1))
        .opacity(0.86)
        .rotationEffect(.degrees(s.angle))
    }
}

/// 护照封面按国籍取色（近似现实护照配色：红 / 蓝 / 墨绿 / 酒红 / 黑，未设或未知则深蓝）。
enum PassportPalette {
    private static let red    = (Color(hex: 0x6E1420), Color(hex: 0x44101A))
    private static let navy   = (Color(hex: 0x16284A), Color(hex: 0x0E1B36))
    private static let green  = (Color(hex: 0x1E4D34), Color(hex: 0x113021))
    private static let bordeaux = (Color(hex: 0x5A1A2A), Color(hex: 0x3A1019))
    private static let black  = (Color(hex: 0x1A1A1E), Color(hex: 0x0C0C10))

    private static let map: [String: (Color, Color)] = [
        // 红
        "CN": red, "JP": red, "SG": red, "CH": red, "TR": red, "VN": red, "RU": red,
        "PL": red, "HK": red, "TW": red, "RS": red, "MO": red,
        // 墨绿
        "SA": green, "PK": green, "NG": green, "BD": green, "MA": green, "DZ": green,
        // 酒红（多数欧盟/英）
        "GB": bordeaux, "FR": bordeaux, "DE": bordeaux, "IT": bordeaux, "ES": bordeaux,
        "NL": bordeaux, "PT": bordeaux, "GR": bordeaux, "IE": bordeaux,
        // 黑
        "NZ": black,
        // 蓝
        "US": navy, "AU": navy, "BR": navy, "IN": navy, "KR": navy, "TH": navy,
        "AE": navy, "QA": navy, "EG": navy, "ZA": navy, "CA": navy, "MX": navy, "ID": navy,
    ]

    static func cover(for code: String) -> (Color, Color) {
        map[code.uppercased()] ?? navy
    }
}
