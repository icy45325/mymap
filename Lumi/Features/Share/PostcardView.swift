import SwiftUI

extension Font {
    /// 按当前语言取系统手写体（中：手札体 / 英：Noteworthy / 阿：Farah）；
    /// 用系统字体避免自带字体打包问题；缺失时 `.custom` 自动回退系统字体，不崩。
    static func handwriting(_ size: CGFloat) -> Font {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let name: String
        switch lang {
        case "zh": name = "Hannotate SC"
        case "ar": name = "Farah"
        default:   name = "Noteworthy"
        }
        return .custom(name, size: size)
    }
}

/// 明信片上自动生成的寄语默认值：有心情用心情；否则按语言套模板。用户可在分享前改。
func defaultPostcardMessage(_ fp: Footprint) -> String {
    if !fp.mood.isEmpty { return fp.mood }
    return String(localized: "想把\(fp.title)的这一刻寄给你 ✦")
}

/// 明信片：足迹渲染成可分享的成品卡（封面=照片或霓虹渐变 + 手写寄语 + 地点/日期）。
/// 供 `ShareRender.image(_:)` 渲染；封面照片需先异步取成 UIImage 传入（ImageRenderer 同步渲染）。
struct PostcardView: View {
    let footprint: Footprint
    var cover: UIImage? = nil
    var message: String = ""
    var style: PostcardStyle = .vintage
    var stamp: PostcardStamp = .air
    /// 免费版导出时盖 Lumi 水印；Plus 去水印（见 PostcardSheet 的 `store.isPlus`）。
    var watermark: Bool = false

    private static let df: Date.FormatStyle = .dateTime.year().month(.wide).day()
    private var theme: PostcardTheme { PostcardTheme.make(style) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: theme.photo, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Text(footprint.flag).font(.system(size: 150)).opacity(0.22))
                }
            }
            .frame(width: 360, height: 480)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.25), .black.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)
            .frame(width: 360, height: 480)

            VStack(alignment: .leading, spacing: 10) {
                Text("LUMI").font(.system(size: 11, weight: .heavy)).tracking(4)
                    .foregroundStyle(Color.nCyan)
                Spacer()
                // 手写寄语（hero）
                if !message.isEmpty {
                    Text(message)
                        .font(.handwriting(26))
                        .foregroundStyle(.white)
                        .lineLimit(4).minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                }
                // 地点 · 日期
                HStack(spacing: 8) {
                    Text(footprint.flag).font(.system(size: 22))
                    Text(footprint.title).font(Typo.serif(20)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("·").foregroundStyle(.white.opacity(0.5))
                    Text(footprint.visitSpanText(Self.df))
                        .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .padding(22)
            .frame(width: 360, height: 480, alignment: .bottomLeading)
        }
        .frame(width: 360, height: 480)
        .overlay(alignment: .topTrailing) {
            PostcardStampView(stamp: stamp)
                .frame(width: 54, height: 64).rotationEffect(.degrees(5))
                .padding(18)
        }
        .overlay(alignment: .bottomTrailing) {
            if watermark {
                HStack(spacing: 4) {
                    Text("✦").font(.system(size: 11))
                    Text("Lumi").font(.system(size: 12, weight: .heavy)).tracking(1)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.vertical, 5).padding(.horizontal, 9)
                .background(.black.opacity(0.28), in: Capsule())
                .padding(14)
            }
        }
        .background(Color.bg)
    }
}
