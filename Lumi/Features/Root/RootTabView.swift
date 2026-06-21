import SwiftUI

/// 底部 Tab 框架（§4.1）：地图 / 足迹 / 成就 / 我。地图默认选中。
struct RootTabView: View {

    init() {
        // 暗夜不透明 Tab 栏
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.ink)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            MapHomeView()
                .tabItem { Label("地图", systemImage: "map.fill") }

            TimelineView()
                .tabItem { Label("足迹", systemImage: "list.bullet.rectangle.fill") }

            // M5 替换为 StatsView
            ComingSoonView(title: "成就", systemImage: "rosette")
                .tabItem { Label("成就", systemImage: "rosette") }

            ComingSoonView(title: "我", systemImage: "person.crop.circle")
                .tabItem { Label("我", systemImage: "person.fill") }
        }
        .tint(Color.litGlow)
        .preferredColorScheme(.dark)
    }
}

/// v0 占位页（"我"在 v0 无内容；账号体系是付费 Apple Developer 之后的事，§8）。
struct ComingSoonView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage).font(.system(size: 44)).foregroundStyle(Color.textMuted)
                Text("\(title) · 敬请期待").font(.headline).foregroundStyle(Color.textSecondary)
            }
        }
        .preferredColorScheme(.dark)
    }
}
