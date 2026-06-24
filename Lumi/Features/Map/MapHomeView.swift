import SwiftUI
import SwiftData
import CoreLocation

/// 世界地图主页（核心页）· 暗夜霓虹 v2。
///
/// 真实 MapKit 底图（霓虹着色）+ 顶部 HUD 大数字 + 世界进度条 +
/// 精彩瞬间轮播 + 渐变 FAB。地理判定仍走离线 point-in-polygon（§5.1）。
struct MapHomeView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Footprint.visitedAt, order: .reverse)
    private var footprints: [Footprint]

    /// 底图 provider —— 固定 MapKit。换 Mapbox / 高德只改这一行。
    private let mapProvider: MapProvider = MapKitProvider()

    @State private var showCapture = false
    @State private var showImmersive = false
    @State private var counterPulse = false
    @State private var barFraction: Double = 0

    private var stats: LumiStats { LumiStats(footprints: footprints) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.bg.ignoresSafeArea()

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
                hud
                Spacer()
                bottomPanel
            }
        }
        .overlay(alignment: .topTrailing) { immersiveButton }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCapture) {
            CaptureView(source: "fab", prefilledCoordinate: nil)
        }
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
            Text("已点亮 FOOTPRINTS LIT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Color.muted)

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

    /// 右上角：放大查看真实 MapKit 地图（全屏）。
    private var immersiveButton: some View {
        Button { showImmersive = true } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.text)
                .frame(width: 38, height: 38)
                .background(Color.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
        }
        .padding(.trailing, 22)
        .padding(.top, 8)
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
                        HighlightCard(highlight: h)
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

/// 精彩瞬间卡（封面 + 标题），点开后跳详情可后续接入。
private struct HighlightCard: View {
    let highlight: Highlight

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssetImage(assetID: highlight.assetID, targetSize: CGSize(width: 500, height: 280))
                .frame(width: 248, height: 140)
                .clipped()
            LinearGradient(colors: [.clear, Color.bg.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title).font(Typo.serif(15)).foregroundStyle(.white)
                Text(highlight.subtitle).font(.system(size: 10.5)).foregroundStyle(Color.muted)
            }
            .padding(13)
        }
        .frame(width: 248, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
    }
}

#Preview {
    MapHomeView()
        .modelContainer(for: [Footprint.self, Trip.self, Card.self], inMemory: true)
}
