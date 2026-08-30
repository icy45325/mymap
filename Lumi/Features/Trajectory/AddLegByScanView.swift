import SwiftUI
import SwiftData
import CoreLocation

/// 扫登机牌加航线：扫码 → 解析 BCBP → 查机场坐标 → 预览确认 → 存为 Leg 航段。
/// 纯本地：条码解析与机场库都离线，不联网、不碰身份信息。
struct AddLegByScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// 与地图共享同一开关键：存完航段后自动打开航线图层，立刻可见。
    @AppStorage("map.showRoutes") private var showRoutes = false

    @State private var scanning = true
    @State private var passenger = ""
    @State private var previews: [PreviewLeg] = []
    @State private var message: String?

    /// 一段可确认的航线预览（已查到坐标）。
    struct PreviewLeg: Identifiable {
        let id = UUID()
        let from: AirportDB.Airport
        let to: AirportDB.Airport
        let flight: String
        let date: Date?
    }

    var body: some View {
        NavigationStack {
            Group {
                if scanning { scanner } else { result }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("扫登机牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 扫描

    private var scanner: some View {
        BoardingPassScannerView { raw in handle(raw) }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .bottom) {
                Text("把登机牌上的条形码放进取景框")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    .padding(.vertical, 9).padding(.horizontal, 16)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 40)
            }
    }

    private func handle(_ raw: String) {
        guard let bp = BCBP.parse(raw) else {
            message = "没认出这张登机牌，换个角度再扫一次试试"
            previews = []
            scanning = false
            return
        }
        passenger = bp.passengerName
        var out: [PreviewLeg] = []
        for l in bp.legs {
            guard let a = AirportDB.lookup(l.from), let b = AirportDB.lookup(l.to) else { continue }
            out.append(PreviewLeg(from: a, to: b, flight: l.flightNumber, date: l.date))
        }
        previews = out
        message = out.isEmpty ? "识别到登机牌，但机场三字码在本地库里查不到" : nil
        scanning = false
    }

    // MARK: 结果

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !passenger.isEmpty {
                    Text(passenger).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.muted)
                }
                if let message {
                    Text(message).font(.system(size: 13)).foregroundStyle(Color.nPink)
                        .padding(12).panelCard(12)
                }
                ForEach(previews) { legCard($0) }

                if !previews.isEmpty {
                    Button(action: save) {
                        Text(previews.count > 1 ? "加入 \(previews.count) 段航线" : "加入这段航线")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient.neonH, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button { scanning = true; message = nil } label: {
                    Text("重新扫描").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.nCyan)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.panel, in: Capsule())
                        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
    }

    private func legCard(_ leg: PreviewLeg) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane").font(.system(size: 18)).foregroundStyle(Color(hex: 0x4FE3FF))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(leg.from.iata).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
                    Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Color.faint)
                    Text(leg.to.iata).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.text)
                }
                Text("\(leg.from.name) → \(leg.to.name)")
                    .font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(2)
                HStack(spacing: 10) {
                    Text(leg.flight).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.nCyan)
                    if let d = leg.date {
                        Text(d.formatted(.dateTime.year().month(.abbreviated).day()))
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                    }
                }
            }
            Spacer()
        }
        .padding(14).panelCard(14)
    }

    // MARK: 保存

    private func save() {
        for l in previews {
            let leg = Leg(mode: .flight,
                          fromName: l.from.name, from: l.from.coordinate,
                          toName: l.to.name, to: l.to.coordinate,
                          departAt: l.date ?? .now,
                          note: l.flight)
            context.insert(leg)
        }
        try? context.save()
        showRoutes = true          // 存完自动打开航线图层
        Haptics.success()
        dismiss()
    }
}
