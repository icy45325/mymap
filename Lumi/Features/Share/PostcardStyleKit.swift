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
        switch self { case .air: return "airplane"; case .land: return "train.side.front.car"; case .sea: return "ferry.fill" }
    }
    var caption: String {
        switch self { case .air: return "AIR FREIGHT"; case .land: return "LAND FREIGHT"; case .sea: return "SEA FREIGHT" }
    }
    var sub: String {
        switch self { case .air: return "LUMI · ¥1.50"; case .land: return "LUMI · ¥1.00"; case .sea: return "LUMI · ¥0.80" }
    }
    var stripes: Bool { self == .air }
}

/// 明信片朝向：由封面照片长宽比决定。
/// 宽>高 → 横版（取 16:9 正面）；宽<高 → 竖版（取 3:4 正面）；近似正方形 → 方版（1:1 正面，邮票在底部）。
enum PostcardOrient {
    case landscape, portrait, square

    static func from(_ cover: UIImage?) -> PostcardOrient {
        guard let c = cover, c.size.width > 0, c.size.height > 0 else { return .landscape }
        let r = c.size.width / c.size.height
        if r > 1.02 { return .landscape }
        if r < 0.98 { return .portrait }
        return .square
    }

    /// 正面照片裁切比例（宽 / 高）。
    var frontAspect: CGFloat {
        switch self {
        case .landscape: return 16.0 / 9.0
        case .portrait:  return 3.0 / 4.0
        case .square:    return 1.0
        }
    }
    /// 背面是否用竖版排布（地名+寄语在上、邮票+寄给在下）。横版用左右分栏。
    var verticalBack: Bool { self != .landscape }
    /// 预览卡最大宽度。
    var previewMaxWidth: CGFloat {
        switch self {
        case .landscape: return 345
        case .square:    return 320
        case .portrait:  return 300
        }
    }
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
    let stamp: StampKind
    let flipped: Bool
    var sender: String = ""
    var dateText: String = ""
    /// 邮戳（邮局盖章）：寄出/分享前不展示，仅收件人看到。
    var showPostmark: Bool = false

    private var theme: PostcardTheme { PostcardTheme.make(style) }
    private var locEn: String { (footprint.cityName ?? footprint.title).uppercased() }
    private var locZh: String { footprint.locationSubtitle.isEmpty ? footprint.title : footprint.locationSubtitle }

    /// 朝向随封面：宽>高=横(16:9)、宽<高=竖(3:4)、近方=方(1:1)。
    private var orient: PostcardOrient { PostcardOrient.from(cover) }

    var body: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .aspectRatio(orient.frontAspect, contentMode: .fit)
        .frame(maxWidth: orient.previewMaxWidth)
        .frame(maxWidth: .infinity)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.62, dampingFraction: 0.78), value: flipped)   // 翻面带轻微回弹
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }

    private var front: some View {
        PostcardFrontPanel(footprint: footprint, cover: cover, style: style)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var back: some View {
        PostcardBackPanel(footprint: footprint, message: message, recipient: recipient,
                          style: style, stamp: stamp, portrait: orient.verticalBack,
                          sender: sender, dateText: dateText, showPostmark: showPostmark)
    }
}

// MARK: - 正面 / 背面 面板（预览卡与导出图共用）

/// 正面：只展示上传的照片（裁切填满）；无照片用样式渐变兜底。
struct PostcardFrontPanel: View {
    let footprint: Footprint
    var cover: UIImage?
    let style: PostcardStyle
    private var theme: PostcardTheme { PostcardTheme.make(style) }
    var body: some View {
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
    }
}

/// 背面书写面：地点 + 寄语 + 邮票/邮戳 + 寄给。横版左右分栏，竖版上下分区。
struct PostcardBackPanel: View {
    let footprint: Footprint
    var message: String
    var recipient: String
    let style: PostcardStyle
    let stamp: StampKind
    var portrait: Bool = false
    var sender: String = ""        // 寄自（默认发送方昵称）
    var dateText: String = ""      // 发送日期（在行程范围内由发送方选定）
    var showPostmark: Bool = false // 邮戳：寄出/分享前不盖，仅收件人看到

    private var theme: PostcardTheme { PostcardTheme.make(style) }
    private var locEn: String { (footprint.cityName ?? footprint.title).uppercased() }
    private var locZh: String { footprint.locationSubtitle.isEmpty ? footprint.title : footprint.locationSubtitle }

    /// 命中节日章吗（仅收件人视角；按足迹所在地区 + 寄出日期窗口）。
    private var festival: Festival? {
        showPostmark ? Festival.match(countryCode: footprint.countryCode, date: footprint.visitedAt) : nil
    }

    /// 邮票位：命中节日 → 节日主题邮票；否则空运/陆运/海运邮票（收件人视角再叠通用邮戳）。
    @ViewBuilder
    private func stampMark(_ w: CGFloat, _ h: CGFloat, pm: CGSize) -> some View {
        if let f = festival {
            FestivalSeal(festival: f).frame(width: w + 4, height: h + 4)
        } else {
            ZStack(alignment: .bottomLeading) {
                StampView(kind: stamp)
                    .frame(width: w, height: h).rotationEffect(.degrees(4))
                if showPostmark { postmark.offset(x: pm.width, y: pm.height) }
            }
        }
    }

    var body: some View {
        Group { if portrait { vertical } else { horizontal } }
            .background(theme.paper)
            .overlay { if theme.paperPattern { DiagonalPaper().stroke(Color(hex: 0x785F3C).opacity(0.06), lineWidth: 1) } }
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    /// 竖版：上＝国家/地名 + 寄语，下＝邮票/邮戳 + 寄给。
    private var vertical: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text(footprint.flag).font(.system(size: 15))
                Text(locEn)
                    .font(theme.msgSerif ? Typo.serif(15, weight: .semibold) : .system(size: 14, weight: .bold))
                    .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.6)
            }
            HStack(spacing: 6) {
                Text(locZh).font(.system(size: 9)).foregroundStyle(theme.addr).lineLimit(1)
                if !dateText.isEmpty {
                    Text(verbatim: "· \(dateText)").font(.system(size: 9)).foregroundStyle(theme.addr).lineLimit(1)
                }
            }
            Rectangle().fill(theme.line).frame(height: 1).padding(.vertical, 9)
            Text(message)
                .font(theme.msgSerif ? Typo.serif(13, weight: .regular).italic() : .system(size: 13, weight: .light))
                .lineSpacing(4).foregroundStyle(theme.msgColor)
            Spacer(minLength: 8)
            Rectangle().fill(theme.line).frame(height: 1).padding(.bottom, 8)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("寄给").font(.system(size: 9)).foregroundStyle(theme.addr)
                    Text(recipient.isEmpty ? " " : recipient)
                        .font(theme.msgSerif ? Typo.serif(14) : .system(size: 14, weight: .medium))
                        .foregroundStyle(theme.ink).lineLimit(1)
                    if !sender.isEmpty {
                        Text("寄自 \(sender)").font(.system(size: 9)).foregroundStyle(theme.addr).lineLimit(1)
                    }
                }
                Spacer()
                stampMark(54, 64, pm: CGSize(width: -16, height: 10))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var horizontal: some View {
        HStack(spacing: 0) {
            // 左：地点（国家 / 地名）+ 寄语
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text(footprint.flag).font(.system(size: 13))
                    Text(locEn)
                        .font(theme.msgSerif ? Typo.serif(13, weight: .semibold) : .system(size: 12, weight: .bold))
                        .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                }
                HStack(spacing: 5) {
                    Text(locZh).font(.system(size: 8)).foregroundStyle(theme.addr).lineLimit(1)
                    if !dateText.isEmpty {
                        Text(verbatim: "· \(dateText)").font(.system(size: 8)).foregroundStyle(theme.addr).lineLimit(1)
                    }
                }
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
                    stampMark(50, 60, pm: CGSize(width: -14, height: 10))
                }
                Spacer(minLength: 0)
                Rectangle().fill(theme.line).frame(height: 1).padding(.bottom, 6)
                Text("寄给").font(.system(size: 8)).foregroundStyle(theme.addr)
                Text(recipient.isEmpty ? " " : recipient)
                    .font(theme.msgSerif ? Typo.serif(12) : .system(size: 12, weight: .medium))
                    .foregroundStyle(theme.ink).lineLimit(1)
                if !sender.isEmpty {
                    Text("寄自 \(sender)").font(.system(size: 8)).foregroundStyle(theme.addr).lineLimit(1)
                }
            }
            .padding(.init(top: 14, leading: 11, bottom: 14, trailing: 14))
            .frame(width: 124)
            .frame(maxHeight: .infinity)
        }
    }

    /// 通用 Lumi 圆戳（邮局盖章）；节日章已在 `stampMark` 里替换整枚邮票，这里只管非节日的常规邮戳。
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

/// 传递明信片的二维码卡：白底 QR + 中心 Lumi logo + Lumi 文案。供分享/展示。
struct PostcardQRCard: View {
    let qr: UIImage
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Image(uiImage: qr).interpolation(.none).resizable()
                    .frame(width: 250, height: 250)
                // 中心留一块**实心白底**作干净遮挡（QR 高容错 H 自动重建），logo 叠其上 → 仍可扫
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(.white).frame(width: 60, height: 60)
                    Image("LumiMark").resizable().scaledToFit().frame(width: 46, height: 46)
                }
            }
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            VStack(spacing: 4) {
                LumiBrandMark(size: 44)
                Text("扫码用 Lumi 收下这张明信片")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: 0x6A6480))
            }
        }
        .padding(26)
        .frame(width: 320)
        .background(LinearGradient(colors: [Color(hex: 0xF3EEFF), Color(hex: 0xE7DEFF)],
                                   startPoint: .top, endPoint: .bottom))
    }
}

/// 导出 / 分享用的成品图：**正面 + 背面并排展示**（竖版明信片左右排：左正面、右背面；
/// 横版明信片上下排：上正面、下背面），带霓虹底色与 Lumi 品牌标。供 `ShareRender.image(_:)` 渲染。
/// 注意：App 内查看（`PostcardFlipCard`）仍是翻面交互，不走此布局。
struct PostcardExportCard: View {
    let footprint: Footprint
    var cover: UIImage?
    var message: String
    var recipient: String
    let style: PostcardStyle
    let stamp: StampKind
    var watermark: Bool = false      // 免费版显示 Lumi 品牌标；Plus 去标
    var sender: String = ""
    var dateText: String = ""
    /// 邮戳（邮局盖章）：寄出/分享前不展示，仅收件人看到。
    var showPostmark: Bool = false

    /// 与预览卡同口径：横(16:9) / 竖(3:4) / 方(1:1)。
    private var orient: PostcardOrient { PostcardOrient.from(cover) }

    var body: some View {
        let isLandscape = orient == .landscape
        let frontW: CGFloat = isLandscape ? 380 : 300
        let frontH: CGFloat = frontW / orient.frontAspect
        // 并排（竖/方）：正反等高；上下（横）：背面给固定高度。
        let backW: CGFloat = isLandscape ? frontW : 300
        let backH: CGFloat = isLandscape ? 176 : frontH

        VStack(spacing: 16) {
            Group {
                if isLandscape {
                    VStack(spacing: 14) { frontPanel(frontW, frontH); backPanel(backW, backH) }
                } else {
                    HStack(alignment: .top, spacing: 14) { frontPanel(frontW, frontH); backPanel(backW, backH) }
                }
            }
            if watermark {
                HStack(spacing: 7) {
                    LumiBrandMark(size: 26)
                    Text(verbatim: "TRACK YOUR JOURNEY. LIGHT UP THE MAP.")
                        .font(.system(size: 8, weight: .semibold)).tracking(1)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 30).padding(.bottom, 22)
        .background(shareBackground)
    }

    private func frontPanel(_ w: CGFloat, _ h: CGFloat) -> some View {
        PostcardFrontPanel(footprint: footprint, cover: cover, style: style)
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }

    private func backPanel(_ w: CGFloat, _ h: CGFloat) -> some View {
        PostcardBackPanel(footprint: footprint, message: message, recipient: recipient,
                          style: style, stamp: stamp, portrait: orient.verticalBack,
                          sender: sender, dateText: dateText, showPostmark: showPostmark)
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }

    /// 分享底色：深色 + 双角霓虹辉光（呼应应用主题）。
    private var shareBackground: some View {
        ZStack {
            Color(hex: 0x0E0B1A)
            RadialGradient(colors: [Color(hex: 0x9B5DE5).opacity(0.38), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Color(hex: 0x4DD9FF).opacity(0.22), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
    }
}
