import SwiftUI
import SwiftData
import CoreLocation
import UIKit

/// 底部 Tab 框架 · 暗夜霓虹 v2：地图 / 星迹 / 成就 / 我。地图默认选中。
struct RootTabView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// 已接收 / 已发送过的明信片口令（逗号分隔），用于幂等去重。
    @AppStorage("lumi.receivedTokens") private var receivedTokensRaw: String = ""
    @State private var incoming: PostcardPayload?

    init() {
        // 暗夜霓虹半透明 Tab 栏
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.bg)
        appearance.shadowColor = UIColor(Color.hair)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            MapHomeView()
                .tabItem { Label("地图", systemImage: "map.fill") }

            TimelineView()
                .tabItem { Label("星迹", systemImage: "sparkles") }

            StatsView()
                .tabItem { Label("成就", systemImage: "rosette") }

            ProfileView()
                .tabItem { Label("我", systemImage: "person.fill") }
        }
        .tint(Color.nPink)
        .preferredColorScheme(.dark)
        .onAppear { checkClipboardForPostcard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkClipboardForPostcard() }
        }
        .alert("收到一张明信片 ✦",
               isPresented: Binding(get: { incoming != nil }, set: { if !$0 { incoming = nil } }),
               presenting: incoming) { payload in
            Button("收下 ✦") { receive(payload) }
            Button("忽略", role: .cancel) { markSeen(payload.token); incoming = nil }
        } message: { payload in
            Text(payload.sender.map { "\($0) 寄来 · \(payload.place)" } ?? payload.place)
        }
    }

    // MARK: - 明信片接收（剪贴板口令）

    private func checkClipboardForPostcard() {
        guard let text = UIPasteboard.general.string,
              let payload = PostcardToken.find(in: text),
              !seenTokens.contains(payload.token)
        else { return }
        incoming = payload
    }

    private func receive(_ p: PostcardPayload) {
        let fp = Footprint(
            placeName: p.place,
            coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon),
            cityName: p.city,
            visitedAt: p.visitedAt,
            mood: p.message)
        fp.countryCode = p.countryCode
        if p.countryCode == "AE" {
            fp.subRegionCode = Boundaries.shared.emirateCode(at: fp.coordinate)
        }
        context.insert(fp)
        context.insert(Card(footprint: fp))
        try? context.save()
        markSeen(p.token)
        WidgetSync.refresh(context)
        incoming = nil
    }

    private var seenTokens: Set<String> {
        Set(receivedTokensRaw.split(separator: ",").map(String.init))
    }
    private func markSeen(_ token: String) {
        var seen = seenTokens
        seen.insert(token)
        receivedTokensRaw = seen.joined(separator: ",")
    }
}
