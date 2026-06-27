import SwiftUI
import UIKit

/// 明信片样式（复刻设计稿）：复古 / 现代 / 插画。
enum PostcardStyle: String, CaseIterable, Identifiable {
    case vintage, modern, vivid
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self { case .vintage: return "复古"; case .modern: return "现代"; case .vivid: return "插画" }
    }
    /// 选择器缩略图渐变。
    var thumb: [Color] {
        switch self {
        case .vintage: return [Color(hex: 0xCAA15F), Color(hex: 0x5B3D22)]
        case .modern:  return [Color(hex: 0xE8A06A), Color(hex: 0x7D4A6A)]
        case .vivid:   return [Color(hex: 0xFF8A4D), Color(hex: 0x7A3FF0)]
        }
    }
}

/// 邮票：按运输方式分三类——空运 / 陆运 / 海运。
enum PostcardStamp: String, CaseIterable, Identifiable {
    case air, land, sea
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self { case .air: return "空运"; case .land: return "陆运"; case .sea: return "海运" }
    }
    var inner: Color {
        switch self { case .air: return Color(hex: 0x22468F); case .land: return Color(hex: 0x3F7A3A); case .sea: return Color(hex: 0x1F6B7A) }
    }
    var motif: String {
        switch self { case .air: return "airplane"; case .land: return "truck.box.fill"; case .sea: return "ferry.fill" }
    }
    var caption: String {
        switch self { case .air: return "AIR FREIGHT"; case .land: return "LAND FREIGHT"; case .sea: return "SEA FREIGHT" }
    }
    var sub: String {
        switch self { case .air: return "LUMI · ¥1.50"; case .land: return "LUMI · ¥1.00"; case .sea: return "LUMI · ¥0.80" }
    }
    var stripes: Bool { self == .air }
}

/// 一种样式解析出的配色 / 字体口径。
struct PostcardTheme {
    let photo: [Color]
    let overlay: LinearGradient
    let paper: AnyShapeStyle
    let paperPattern: Bool
    let ink: Color
    let line: Color
    let addr: Color
    let locColor: Color
    let locSerif: Bool
    let msgColor: Color
    let msgSerif: Bool
    let pm: Color

    static func make(_ s: PostcardStyle) -> PostcardTheme {
        switch s {
        case .vintage:
            return PostcardTheme(
                photo: [Color(hex: 0xCAA15F), Color(hex: 0x9C6B3A), Color(hex: 0x5B3D22)],
                overlay: LinearGradient(colors: [Color(hex: 0x321E0C).opacity(0.5), Color(hex: 0x321E0C).opacity(0.04)],
                                        startPoint: .bottom, endPoint: .center),
                paper: AnyShapeStyle(Color(hex: 0xE4D4B2)), paperPattern: true,
                ink: Color(hex: 0x5B4A2F), line: Color(hex: 0x5B4A2F).opacity(0.45), addr: Color(hex: 0x5B4A2F).opacity(0.7),
                locColor: Color(hex: 0xFFF5E2), locSerif: true,
                msgColor: Color(hex: 0x5B4A2F), msgSerif: true, pm: Color(hex: 0x6B4A2A))
        case .modern:
            return PostcardTheme(
                photo: [Color(hex: 0xE8A06A), Color(hex: 0xC96B58), Color(hex: 0x7D4A6A)],
                overlay: LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .bottom, endPoint: .center),
                paper: AnyShapeStyle(Color.white), paperPattern: false,
                ink: Color(hex: 0x222222), line: Color.black.opacity(0.13), addr: Color.black.opacity(0.45),
                locColor: .white, locSerif: false,
                msgColor: Color(hex: 0x2A2A2A), msgSerif: false, pm: Color(hex: 0x444444))
        case .vivid:
            return PostcardTheme(
                photo: [Color(hex: 0xFF8A4D), Color(hex: 0xFF4D8D), Color(hex: 0x7A3FF0)],
                overlay: LinearGradient(colors: [Color.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .center),
                paper: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xFFB84D)],
                                                    startPoint: .top, endPoint: .bottom)), paperPattern: false,
                ink: Color(hex: 0x7A3B10), line: Color(hex: 0x7A3B10).opacity(0.35), addr: Color(hex: 0x7A3B10).opacity(0.72),
                locColor: .white, locSerif: true,
                msgColor: Color(hex: 0x7A3B10), msgSerif: true, pm: Color(hex: 0x8A4A10))
        }
    }
}

/// 原生绘制的邮票贴图。
struct PostcardStampView: View {
    let stamp: PostcardStamp
    var mini: Bool = false

    var body: some View {
        let pad: CGFloat = mini ? 3 : 4
        return RoundedRectangle(cornerRadius: 2).fill(.white)
            .overlay {
                ZStack {
                    stamp.inner
                    if stamp.stripes {
                        StripeFill().fill(.white.opacity(0.12))
                    }
                    VStack(spacing: 1) {
                        Image(systemName: stamp.motif).font(.system(size: mini ? 10 : 13)).foregroundStyle(.white)
                        if !mini {
                            Text(stamp.caption).font(.system(size: 5, weight: .bold)).tracking(0.4).foregroundStyle(.white)
                            Text(stamp.sub).font(.system(size: 4)).tracking(0.3).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .overlay(RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                .padding(pad)
            }
            .shadow(color: .black.opacity(0.25), radius: mini ? 1 : 2, y: 1)
    }
}

private struct StripeFill: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height)); p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            p.addLine(to: CGPoint(x: x + rect.height + 3, y: 0)); p.addLine(to: CGPoint(x: x + 3, y: rect.height))
            x += 6
        }
        return p
    }
}

private struct DiagonalPaper: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height)); p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += 7
        }
        return p
    }
}

/// 明信片翻面预览卡（正面照片 / 背面书写面），点按或外部按钮翻转。
struct PostcardFlipCard: View {
    let footprint: Footprint
    var cover: UIImage?
    var message: String
    var recipient: String
    let style: PostcardStyle
    let stamp: PostcardStamp
    let flipped: Bool

    private var theme: PostcardTheme { PostcardTheme.make(style) }
    private var locEn: String { (footprint.cityName ?? footprint.title).uppercased() }
    private var locZh: String { footprint.locationSubtitle.isEmpty ? footprint.title : footprint.locationSubtitle }

    var body: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .aspectRatio(1.55, contentMode: .fit)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 0.6), value: flipped)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }

    /// 正面：只展示上传的照片（横向裁切填满固定尺寸）；无照片用样式渐变兜底。
    private var front: some View {
        Group {
            if let cover {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                LinearGradient(colors: theme.photo, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Text(footprint.flag).font(.system(size: 90)).opacity(0.22))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var back: some View {
        HStack(spacing: 0) {
            // 左：地点（国家 / 地名）+ 寄语
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text(footprint.flag).font(.system(size: 13))
                    Text(locEn)
                        .font(theme.msgSerif ? Typo.serif(13, weight: .semibold) : .system(size: 12, weight: .bold))
                        .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                }
                Text(locZh).font(.system(size: 8)).foregroundStyle(theme.addr).lineLimit(1)
                Rectangle().fill(theme.line).frame(height: 1).padding(.trailing, 6)
                Text(message)
                    .font(theme.msgSerif ? Typo.serif(12, weight: .regular).italic() : .system(size: 12, weight: .light))
                    .lineSpacing(3).foregroundStyle(theme.msgColor)
                Spacer(minLength: 0)
            }
            .padding(.init(top: 14, leading: 15, bottom: 14, trailing: 11))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle().fill(theme.line).frame(width: 1).padding(.vertical, 16)

            // 右：邮票 / 邮戳（顶）+ 收件（底）
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    ZStack(alignment: .bottomLeading) {
                        PostcardStampView(stamp: stamp)
                            .frame(width: 50, height: 60).rotationEffect(.degrees(4))
                        postmark.offset(x: -14, y: 10)
                    }
                }
                Spacer(minLength: 0)
                Rectangle().fill(theme.line).frame(height: 1).padding(.bottom, 6)
                Text("寄给").font(.system(size: 8)).foregroundStyle(theme.addr)
                Text(recipient.isEmpty ? " " : recipient)
                    .font(theme.msgSerif ? Typo.serif(12) : .system(size: 12, weight: .medium))
                    .foregroundStyle(theme.ink).lineLimit(1)
            }
            .padding(.init(top: 14, leading: 11, bottom: 14, trailing: 14))
            .frame(width: 124)
            .frame(maxHeight: .infinity)
        }
        .background(theme.paper)
        .overlay { if theme.paperPattern { DiagonalPaper().stroke(Color(hex: 0x785F3C).opacity(0.06), lineWidth: 1) } }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var postmark: some View {
        VStack(spacing: 0) {
            Text("LUMI").font(.system(size: 4.5, weight: .bold))
            Text(pmCity).font(.system(size: 4, weight: .bold))
            Text(pmYear).font(.system(size: 3.5, design: .monospaced))
        }
        .foregroundStyle(theme.pm)
        .frame(width: 32, height: 32)
        .overlay(Circle().stroke(theme.pm, lineWidth: 1))
        .background(Circle().fill(.white.opacity(0.3)))
        .rotationEffect(.degrees(-8))
    }

    private var pmCity: String {
        let c = (footprint.cityName ?? footprint.title)
        return String(c.prefix(3)).uppercased()
    }
    private var pmYear: String {
        "'" + String(Calendar.current.component(.year, from: footprint.visitedAt) % 100)
    }
}
