import SwiftUI

/// 明信片卡详情（§4.3）：只读。v0 不做编辑（详见 PRD 设计决策待确认项 2）。
struct FootprintDetailView: View {

    let footprint: Footprint

    private static let dateFormat: Date.FormatStyle =
        .dateTime.year().month(.wide).day()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AssetImage(assetID: footprint.photoAssetIDs.first,
                           targetSize: CGSize(width: 1200, height: 900))
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.radius))

                VStack(alignment: .leading, spacing: 6) {
                    Text(footprint.placeName)
                        .font(Typo.display(26))
                        .foregroundStyle(Color.textPrimary)
                    Text(locationLine)
                        .font(.subheadline)
                        .foregroundStyle(Color.litGlow)
                }

                if !footprint.mood.isEmpty {
                    Text("「\(footprint.mood)」")
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: Metrics.radius))
                }

                infoRow("日期", footprint.visitedAt.formatted(Self.dateFormat))
                if !footprint.companions.isEmpty {
                    infoRow("同行人", footprint.companions.joined(separator: "、"))
                }
            }
            .padding(Metrics.pad)
        }
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("足迹")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.ink, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    /// 城市 · 国家（中文国名）。
    private var locationLine: String {
        let country = Locale.current.localizedString(forRegionCode: footprint.countryCode ?? "")
        return [footprint.cityName, country].compactMap { $0 }.joined(separator: " · ")
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.subheadline).foregroundStyle(Color.textSecondary).frame(width: 64, alignment: .leading)
            Text(value).font(.subheadline).foregroundStyle(Color.textPrimary)
            Spacer()
        }
    }
}
