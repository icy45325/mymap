import SwiftUI

/// 把任意 SwiftUI 视图渲染成可分享的位图（基础分享：导出图 + ShareLink）。
///
/// v1 仅「渲染成图分享」；二维码 / 打开自动接收的完整闭环见 DESIGN-accounts-and-exchange §4（B3）。
@MainActor
enum ShareRender {
    static func image<V: View>(_ view: V, scale: CGFloat = 3) -> Image? {
        uiImage(view, scale: scale).map(Image.init(uiImage:))
    }

    /// 同上但返回 `UIImage`（Instagram Stories 等需要原始位图）。
    static func uiImage<V: View>(_ view: V, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }
}

/// 分享图统一品牌水印：截取的「Lumi 图标 + Lumi 文字」贴图（已含文字，竖版）。所有分享贴图通用。
/// `size` 为高度，宽度按原图比例自适应（避免拉伸）。
struct LumiBrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        Image("LumiMark").resizable().scaledToFit().frame(height: size)
    }
}

/// 分享图统一品牌页脚：左 = Lumi 标 + 一句话介绍；右 = 官网二维码（扫码 → 落地页 → 下载）。
/// 所有对外分享成图（明信片导出、徽章卡、成就报告）通用——分享即获客入口。
struct ShareBrandFooter: View {
    /// 官网二维码（静态缓存）。
    static let siteQR: UIImage? = PostcardToken.qrImage(
        "https://icy45325.github.io/mymap/", scale: 8, correction: "M")

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            LumiBrandMark(size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "TRACK YOUR JOURNEY. LIGHT UP THE MAP.")
                    .font(.system(size: 7.5, weight: .semibold)).tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                Text("点亮世界地图 · 寄一张会盖邮戳的明信片")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Text("扫码了解 Lumi")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: 56)
                    .multilineTextAlignment(.trailing)
                if let qr = Self.siteQR {
                    Image(uiImage: qr).interpolation(.none).resizable()
                        .frame(width: 46, height: 46)
                        .padding(4)
                        .background(.white, in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }
}

/// 徽章分享卡：暗夜霓虹风的成就卡，供 ImageRenderer 渲染分享。
struct BadgeShareCard: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 14) {
            LumiBrandMark(size: 52)
            HexBadge(badge: badge, size: 128)
                .padding(.top, 4)
            Text(badge.name.localized).font(Typo.serif(27))
                .foregroundStyle(Color.text).multilineTextAlignment(.center)
            Text("\(badge.rarity.tierName.localized) · \(badge.rarity.rawValue.uppercased())")
                .font(.system(size: 12, weight: .heavy)).tracking(1.5)
                .foregroundStyle(badge.rarity.color)
            Text(badge.desc.localized).font(.system(size: 13)).lineSpacing(3)
                .foregroundStyle(Color(hex: 0xC9C2D6))
                .multilineTextAlignment(.center).padding(.horizontal, 18)
            Text("✦ 成就解锁 · Lit on Lumi").font(.system(size: 11))
                .foregroundStyle(Color.muted).padding(.top, 2)
            ShareBrandFooter().padding(.top, 6)
        }
        .padding(.vertical, 36).padding(.horizontal, 28)
        .frame(width: 340)
        .background(
            LinearGradient(colors: [Color.nOrange.opacity(0.22), Color.nPink.opacity(0.14),
                                    Color.nPurple.opacity(0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .background(Color.bg)
    }
}
