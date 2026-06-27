import SwiftUI
import SwiftData
import CoreLocation
import UIKit

/// 底部 Tab 框架 · 暗夜霓虹 v2：地图 / 星迹 / 成就 / 我。地图默认选中。
struct RootTabView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var footprints: [Footprint]
    /// 已接收 / 已发送过的明信片口令（逗号分隔），用于幂等去重。
    @AppStorage("lumi.receivedTokens") private var receivedTokensRaw: String = ""
    /// 已「见过」的解锁徽章 id；用于在**添加足迹时**检测新解锁并弹庆祝（全 App 级）。
    @AppStorage("lumi.seenBadges") private var seenBadgesRaw: String = ""
    @AppStorage("lumi.badgesInit") private var badgesInit: Bool = false
    @State private var celebrateBadges: [Badge] = []
    /// 接收枢纽：剪贴板 / 扫码 / lumi:// / AirDrop 四入口统一到这里。
    @ObservedObject private var inbox = PostcardInbox.shared

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
        .onAppear { checkClipboardForPostcard(); detectNewUnlocks() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkClipboardForPostcard() }
        }
        .onChange(of: footprints.count) { _, _ in detectNewUnlocks() }   // 添加足迹即判断是否点亮新徽章
        .overlay { if !celebrateBadges.isEmpty { UnlockCelebration(badges: celebrateBadges) { celebrateBadges = [] } } }
        .alert("收到一张明信片 ✦",
               isPresented: Binding(get: { inbox.pending != nil }, set: { if !$0 { inbox.pending = nil } }),
               presenting: inbox.pending) { payload in
            Button("收下 ✦") { receive(payload) }
            Button("忽略", role: .cancel) { markSeen(payload.token); inbox.pending = nil }
        } message: { payload in
            Text(payload.sender.map { "\($0) 寄来 · \(payload.place)" } ?? payload.place)
        }
    }

    // MARK: - 明信片接收（统一走 PostcardInbox）

    private func checkClipboardForPostcard() {
        if let text = UIPasteboard.general.string { inbox.handle(text: text) }
    }

    private func receive(_ p: PostcardPayload) {
        let fp = Footprint(
            placeName: p.place,
            coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon),
            cityName: p.city,
            visitedAt: p.visitedAt,
            mood: p.message)
        fp.countryCode = p.countryCode
        fp.isReceived = true
        fp.senderName = p.sender
        fp.postcardStyle = p.style ?? "vintage"
        fp.stampStyle = p.stamp ?? "air"
        if p.countryCode == "AE" {
            fp.subRegionCode = Boundaries.shared.emirateCode(at: fp.coordinate)
        }
        context.insert(fp)
        context.insert(Card(footprint: fp))
        try? context.save()
        markSeen(p.token)
        PostcardContacts.shared.record(p.sender, sent: false)   // 攒「往来的人」(本地)
        WidgetSync.refresh(context)
        inbox.pending = nil
    }

    // MARK: - 徽章点亮检测（添加足迹时，全 App 级弹庆祝）

    private func detectNewUnlocks() {
        let board = LumiStats(footprints: footprints).badgeBoard
        let litIDs = Set(board.badges.filter { $0.state == .lit }.map(\.id))
        var seen = Set(seenBadgesRaw.split(separator: ",").map(String.init))
        guard badgesInit else {                       // 首次/升级：静默播种，不一次弹一堆
            seen = litIDs; badgesInit = true
            seenBadgesRaw = seen.sorted().joined(separator: ",")
            return
        }
        let fresh = litIDs.subtracting(seen)
        guard !fresh.isEmpty else { return }
        // 一次可能解锁多枚：收集全部新解锁，交给庆祝弹窗（单枚=大图带名，多枚=汇总不带名）
        if celebrateBadges.isEmpty {
            celebrateBadges = board.badges.filter { $0.state == .lit && fresh.contains($0.id) }
        }
        seen.formUnion(litIDs)
        seenBadgesRaw = seen.sorted().joined(separator: ",")
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
