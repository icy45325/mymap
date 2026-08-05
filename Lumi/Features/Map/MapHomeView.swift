import SwiftUI
import SwiftData
import CoreLocation
import MapKit

/// 世界地图主页（核心页）· 暗夜霓虹 v2。
///
/// 真实 MapKit 底图（霓虹着色）+ 顶部 HUD 大数字 + 世界进度条 +
/// 精彩瞬间轮播 + 渐变 FAB。地理判定仍走离线 point-in-polygon（§5.1）。
struct MapHomeView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var allFootprints: [Footprint]
    /// 足迹 = 自己去过的；收到的明信片不点亮首页（LumiStats 内部同口径二次兜底）。
    private var footprints: [Footprint] { allFootprints.filter { !$0.isReceived } }

    /// 底图 provider —— 固定 MapKit。换 Mapbox / 高德只改这一行。
    private let mapProvider: MapProvider = MapKitProvider()

    @State private var showCapture = false
    @State private var showImmersive = false
    @State private var showScanner = false
    @State private var counterPulse = false
    @State private var barFraction: Double = 0

    /// World / 本地 视图切换（每次进入默认 world，不持久化）。
    private enum MapScope { case world, local }
    @State private var scope: MapScope = .world
    @State private var localCamera: MapCameraPosition = .automatic
    @StateObject private var location = LocationService()
    @ObservedObject private var localSpots = LocalHighlights.shared

    private var stats: LumiStats { LumiStats(footprints: footprints) }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Footprint.self) { fp in
                    FootprintDetailView(footprint: fp)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var content: some View {
        ZStack(alignment: .top) {
            Color.bg.ignoresSafeArea()

            if scope == .world {
                // 默认底图：点阵光点地图（展示用）。放大后才是真实 MapKit 地图。
                DotMatrixBackground(footprints: footprints)
                    .ignoresSafeArea()

                // 顶部 HUD 渐隐到地图
                LinearGradient(colors: [Color.bg.opacity(0.92), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 230)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    scopeSwitch
                    hud
                    Spacer()
                    bottomPanel
                }
            } else {
                VStack(spacing: 0) {
                    scopeSwitch
                    localMapCard
                    localPanel
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if scope == .world {
                HStack(spacing: 10) {
                    scanButton
                    immersiveButton
                }
                .padding(.trailing, 22).padding(.top, 8)
            }
        }
        .task(id: scope == .local) {
            guard scope == .local else { return }
            // 中心：当前定位 → 最近足迹 → 系统默认；运营位内容同时刷新
            if let c = await location.requestOnce() {
                localCamera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 24_000, longitudinalMeters: 24_000))
            } else if let fp = footprints.first {
                localCamera = .region(MKCoordinateRegion(center: fp.coordinate, latitudinalMeters: 24_000, longitudinalMeters: 24_000))
            }
            await LocalHighlights.shared.refresh()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCapture) {
            CaptureView(source: "fab", prefilledCoordinate: nil)
        }
        .sheet(isPresented: $showScanner) { ScannerSheet() }
        .fullScreenCover(isPresented: $showImmersive) {
            RealMapScreen(provider: mapProvider) { showImmersive = false }
        }
        .onChange(of: stats.countries) { _, _ in pulseCounter() }
        .onAppear { animateBar() }
        .onChange(of: stats.worldPercent) { _, _ in animateBar() }
    }

    // MARK: - HUD（大数字）

    private var hud: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GradientText(text: "\(stats.countries)", font: Typo.serif(54))
                Text("/ \(stats.worldTotal) 国")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.faint)
            }
            .scaleEffect(counterPulse ? 1.12 : 1, anchor: .leading)

            HStack(spacing: 8) {
                Circle().fill(Color.grn).frame(width: 5, height: 5)
                    .shadow(color: .grn, radius: 4)
                Text("\(stats.cities) 座城市 · 全球 \(percentText)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    private var percentText: String {
        String(format: "%.1f%%", stats.worldPercent)
    }

    // MARK: - World / 本地 切换

    private var scopeSwitch: some View {
        HStack(spacing: 8) {
            scopeChip("世界 World", .world)
            scopeChip("本地 Local", .local)
            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.top, 6)
    }

    private func scopeChip(_ label: LocalizedStringKey, _ s: MapScope) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { scope = s }
            Haptics.selection()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(scope == s ? .white : Color.muted)
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(scope == s ? AnyShapeStyle(LinearGradient.neonH)
                                       : AnyShapeStyle(Color.panel.opacity(0.62)),
                            in: Capsule())
                .overlay(Capsule().stroke(scope == s ? Color.clear : Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 本地视图（上半真实地图 + 下半运营位热点）

    /// 上半：真实 MapKit 地图，中心=当前定位（拿不到退最近足迹）。
    private var localMapCard: some View {
        Map(position: $localCamera) { UserAnnotation() }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .containerRelativeFrame(.vertical) { len, _ in len * 0.5 }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
            .padding(.horizontal, 18)
            .padding(.top, 12)
    }

    /// 下半：本地热点（服务下发；未上架时是「敬请期待」空态）。
    private var localPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("本地热点").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                Text("HIGHLIGHTS").font(.system(size: 11)).tracking(1.2).foregroundStyle(Color.faint)
            }
            if localSpots.items.isEmpty {
                localEmptyCard
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(localSpots.items) { spotRow($0) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
    }

    private var localEmptyCard: some View {
        VStack(spacing: 8) {
            Text(verbatim: "✦").font(.system(size: 22)).foregroundStyle(Color.faint)
            Text("本地热点推荐 · 敬请期待").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            Text("平台推荐的附近打卡热点将在这里出现").font(.system(size: 11)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    private func spotRow(_ item: LocalHighlights.Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 15)).foregroundStyle(Color.nPink)
                .frame(width: 34, height: 34)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: item.title)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                if let sub = item.subtitle {
                    Text(verbatim: sub).font(.system(size: 11)).foregroundStyle(Color.muted)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.panel.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    /// 右上角：放大查看真实 MapKit 地图（全屏）。
    private var immersiveButton: some View {
        Button { showImmersive = true } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 15, weight: .semibold))
                .flipsForRightToLeftLayoutDirection(true)
                .foregroundStyle(Color.text)
                .frame(width: 38, height: 38)
                .background(Color.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
        }
    }

    /// 右上角：扫码收明信片。
    private var scanButton: some View {
        Button { showScanner = true } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.nCyan)
                .frame(width: 38, height: 38)
                .background(Color.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nCyan.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - 底部面板（进度条 + 精彩瞬间 + FAB）

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            worldBar
            if !stats.highlights.isEmpty { highlights }
            fab
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.clear, Color.bg.opacity(0.9), Color.bg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        )
    }

    private var worldBar: some View {
        VStack(spacing: 7) {
            HStack {
                Text("世界进度 World").font(.system(size: 11)).foregroundStyle(Color.muted)
                Spacer()
                Text(percentText).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.text)
            }
            NeonBar(fraction: barFraction, height: 7)
        }
        .padding(.horizontal, 8)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("精彩瞬间").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                Text("HIGHLIGHTS").font(.system(size: 11)).tracking(1.2).foregroundStyle(Color.faint)
            }
            .padding(.horizontal, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stats.highlights) { h in
                        if let fp = footprints.first(where: { $0.id == h.id }) {
                            NavigationLink(value: fp) {
                                HighlightCard(highlight: h)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HighlightCard(highlight: h)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var fab: some View {
        Button { showCapture = true } label: {
            HStack(spacing: 9) {
                Image(systemName: "sparkles").font(.system(size: 16, weight: .bold))
                Text("点亮新足迹").font(.system(size: 14.5, weight: .bold)).tracking(0.4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(LinearGradient.neonH, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.white)
            .shadow(color: Color.nPurple.opacity(0.55), radius: 16, y: 8)
        }
    }

    // MARK: - 动画

    private func animateBar() {
        withAnimation(.easeOut(duration: 1.3)) { barFraction = stats.worldPercent / 100 }
    }

    private func pulseCounter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { counterPulse = true }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { counterPulse = false }
        }
    }
}

/// 精彩瞬间卡（封面 + 标题），点按进入对应足迹详情页（返回回到主页）。
private struct HighlightCard: View {
    let highlight: Highlight

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssetImage(assetID: highlight.assetID, targetSize: CGSize(width: 660, height: 414))
                .frame(width: 300, height: 188)
                .clipped()
            LinearGradient(colors: [.clear, Color.bg.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title).font(Typo.serif(15)).foregroundStyle(.white)
                Text(highlight.subtitle).font(.system(size: 10.5)).foregroundStyle(Color.muted)
            }
            .padding(13)
        }
        .frame(width: 300, height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
    }
}

#Preview {
    MapHomeView()
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
