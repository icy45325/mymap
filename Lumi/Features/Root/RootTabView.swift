import SwiftUI

/// 底部 Tab 框架 · 暗夜霓虹 v2：地图 / 星迹 / 成就 / 我。地图默认选中。
struct RootTabView: View {

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
    }
}
