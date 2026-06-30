import SwiftUI
import UIKit
import PhotosUI

/// 明信片分享编辑器：实时预览 + 可改的手写寄语（自动生成默认）+ 分享成图 / 口令 / 二维码。
struct PostcardSheet: View {
    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @ObservedObject private var store = PlusStore.shared
    @ObservedObject private var contacts = PostcardContacts.shared
    @State private var message: String
    @State private var cover: UIImage?
    @State private var coverB64: String?             // 压缩封面 base64（随 AirDrop/链接传，QR 不带）
    @State private var shareImage: Image?
    @State private var qr: Image?
    @State private var cardFile: URL?                // AirDrop 用的 .lumicard 文件
    @State private var copied = false
    @State private var showPaywall = false
    @State private var token = UUID().uuidString    // 本张分享卡的幂等标识（稳定）
    @State private var style: PostcardStyle
    @State private var stamp: PostcardStamp
    @State private var flipped = false
    @State private var recipient = ""
    @State private var sendDate: Date                // 发送日期，限定在行程范围内
    @State private var fromName: String              // 寄自（默认个人资料名字，可改）
    @State private var coverAssetID: String?         // 当前选作封面的相册资源 id（nil=新选/无）
    @State private var pickedPhoto: PhotosPickerItem?

    init(footprint: Footprint) {
        self.footprint = footprint
        _message = State(initialValue: defaultPostcardMessage(footprint))
        _style = State(initialValue: PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage)
        _stamp = State(initialValue: PostcardStamp(rawValue: footprint.stampStyle) ?? .air)
        _sendDate = State(initialValue: footprint.visitedAt)
        _fromName = State(initialValue: UserDefaults.standard.string(forKey: "lumi.profile.name") ?? "")
        _coverAssetID = State(initialValue: footprint.photoAssetIDs.first)
    }

    /// 当前样式解析出的配色 / 字体口径（输入框寄语字体与卡面保持一致）。
    private var theme: PostcardTheme { PostcardTheme.make(style) }
    /// 发送方昵称（来自可编辑的「寄自」，默认个人资料名字）。
    private var senderName: String { fromName.trimmingCharacters(in: .whitespaces) }
    /// 发送日期可选范围 = 行程起止日。
    private var dateRange: ClosedRange<Date> {
        let end = footprint.endedAt ?? footprint.visitedAt
        return min(footprint.visitedAt, end)...max(footprint.visitedAt, end)
    }
    private var dateText: String { sendDate.formatted(.dateTime.year().month(.abbreviated).day()) }

    /// `includeCover` 区分：true=AirDrop/链接（带压缩封面图）；false=二维码（容量有限不带图）。
    private func makeToken(includeCover: Bool) -> String {
        PostcardToken.encode(footprint: footprint, message: message, token: token,
                             sender: senderName.isEmpty ? nil : senderName,
                             style: style.rawValue, stamp: stamp.rawValue,
                             date: sendDate, cover: includeCover ? coverB64 : nil)
    }
    private var tokenString: String { makeToken(includeCover: true) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 翻面预览卡（正面照片 / 背面书写）
                    PostcardFlipCard(footprint: footprint, cover: cover, message: message,
                                     recipient: recipient, style: style, stamp: stamp, flipped: flipped,
                                     sender: senderName, dateText: dateText)
                        .onTapGesture { withAnimation { flipped.toggle() } }

                    Button { withAnimation { flipped.toggle() } } label: {
                        Label("翻面", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                            .padding(.vertical, 9).padding(.horizontal, 18)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                    }

                    editorBlock("明信片寄语") {
                        TextField("在明信片上写点什么…", text: $message, axis: .vertical)
                            .font(theme.msgSerif ? Typo.serif(18, weight: .regular).italic()
                                                 : .system(size: 18, weight: .light))
                            .foregroundStyle(Color.text).lineLimit(2...5)
                            .padding(12)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                    }

                    editorBlock("寄给") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("远方的你", text: $recipient)
                                .foregroundStyle(Color.text)
                                .padding(12)
                                .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                            if recipient.isEmpty && !contacts.recent.isEmpty { contactSuggestions }
                        }
                    }

                    editorBlock("寄自") {
                        TextField("你的名字", text: $fromName)
                            .foregroundStyle(Color.text)
                            .padding(12)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                    }

                    photoPicker
                    stylePicker
                    stampPicker
                    if footprint.isMultiDay { sendDatePicker }

                    if let shareImage {
                        HStack(spacing: 10) {
                            ShareLink(item: shareImage,
                                      preview: SharePreview(footprint.title, image: shareImage)) {
                                Label("邮寄明信片", systemImage: "paperplane.fill")
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                                    .background(LinearGradient.neonH, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                contacts.record(recipient, sent: true)   // 寄出即攒往来
                                Haptics.light()
                            })
                            InstagramShareButton {                        // 装了 IG 才出现，点按高清现渲染
                                ShareRender.uiImage(
                                    PostcardExportCard(footprint: footprint, cover: cover, message: message,
                                                       recipient: recipient, style: style, stamp: stamp,
                                                       watermark: !store.isPlus, sender: senderName, dateText: dateText),
                                    scale: 4)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ProgressView().tint(Color.nPink).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }

                    if !store.isPlus { plusUpsell }

                    // 链接 / 二维码 / 隔空投送：对方扫码或点开即在 Lumi 自动收下
                    VStack(spacing: 10) {
                        Text("链接 / 二维码 / 隔空投送 —— 对方扫码或点开即在 Lumi 收下")
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 10) {
                            Button { copyLink() } label: {
                                miniLabel(copied ? "已复制" : "复制链接", copied ? "checkmark" : "link", Color.nCyan)
                            }
                            if let qr {
                                ShareLink(item: qr, preview: SharePreview("Lumi 明信片二维码", image: qr)) {
                                    miniLabel("二维码", "qrcode", Color.nPink)
                                }
                            }
                            if let cardFile {
                                ShareLink(item: cardFile) { miniLabel("隔空投送", "paperplane", Color.nPurple) }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("明信片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { await store.refreshEntitlement()        // 打开即对齐 Plus 权益（订阅后无需再开订阅页）
                cover = await loadAssetUIImage(coverAssetID); rerender() }
        .onChange(of: message) { _, _ in rerender() }
        .onChange(of: recipient) { _, _ in rerender() }      // 导出图含「寄给」，改收件人即时重渲
        .onChange(of: fromName) { _, _ in rerender() }       // 「寄自」即时重渲
        .onChange(of: store.isPlus) { _, _ in rerender() }   // 升级后即时去水印 / 提清
        .onChange(of: style) { _, _ in rerender() }
        .onChange(of: stamp) { _, _ in rerender() }
        .onChange(of: sendDate) { _, _ in rerender() }
        .onChange(of: coverAssetID) { _, id in
            Task { cover = await loadAssetUIImage(id); rerender() }   // 选了相册里某张
        }
        .onChange(of: pickedPhoto) { _, item in
            Task {                                                   // 从相册新选一张
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) { coverAssetID = nil; cover = ui; rerender() }
            }
        }
    }

    /// 选择明信片封面照片：足迹自带照片可点选，或从相册新增一张。
    private var photoPicker: some View {
        editorBlock("照片") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(footprint.photoAssetIDs, id: \.self) { id in
                        AssetImage(assetID: id, targetSize: CGSize(width: 160, height: 160))
                            .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(coverAssetID == id ? Color.nPink : Color.line,
                                        lineWidth: coverAssetID == id ? 2 : 1))
                            .onTapGesture { coverAssetID = id }
                    }
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        VStack(spacing: 3) {
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                            Text("相册").font(.system(size: 9))
                        }
                        .foregroundStyle(Color.nCyan)
                        .frame(width: 60, height: 60)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// 发送日期：限定在行程起止日之间，由发送方选定。
    private var sendDatePicker: some View {
        editorBlock("发送日期") {
            DatePicker("", selection: $sendDate, in: dateRange, displayedComponents: .date)
                .labelsHidden().datePickerStyle(.compact).tint(Color.nPink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
        }
    }

    private func editorBlock<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
            content()
        }
        .padding(.horizontal, 4)
    }

    /// 样式选择（复古 / 现代 / 插画）。
    private var stylePicker: some View {
        editorBlock("样式") {
            HStack(spacing: 10) {
                ForEach(PostcardStyle.allCases) { s in
                    let active = s == style
                    Button { style = s; Haptics.selection() } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: s.thumb, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 40)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(active ? Color.nPink : Color.white.opacity(0.1), lineWidth: active ? 2 : 1))
                            Text(s.label).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(active ? Color.text : Color.muted)
                        }
                        .padding(8)
                        .background(active ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.white.opacity(0.18) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 邮票选择（空运 / 陆运 / 海运）。
    private var stampPicker: some View {
        editorBlock("邮票") {
            HStack(spacing: 8) {
                ForEach(PostcardStamp.allCases) { p in
                    let active = p == stamp
                    Button { stamp = p; Haptics.selection() } label: {
                        VStack(spacing: 5) {
                            PostcardStampView(stamp: p, mini: true).frame(width: 30, height: 36)
                            Text(p.label).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(active ? Color.text : Color.muted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(active ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(active ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 免费版水印提示 + 升级入口。
    private var plusUpsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 15)).foregroundStyle(Color.nCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("明信片带 Lumi 水印").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                    Text("升级 Plus 去水印 · 高清导出").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Text("升级").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .padding(.vertical, 6).padding(.horizontal, 14)
                    .background(LinearGradient.neonH, in: Capsule())
            }
            .padding(12)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.nCyan.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 往来联系人快选（点一下填入「寄给」）。
    private var contactSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(contacts.recent.prefix(8)) { c in
                    Button { recipient = c.name } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill").font(.system(size: 9)).foregroundStyle(Color.nCyan)
                            Text(c.name).font(.system(size: 12)).foregroundStyle(Color.text).lineLimit(1)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 11)
                        .background(Color.panel, in: Capsule())
                        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func miniLabel(_ title: LocalizedStringKey, _ icon: String, _ tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(Color.panel, in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
    }

    private var shareLinkString: String {
        PostcardToken.shareURL(tokenString)?.absoluteString ?? tokenString
    }
    /// 二维码用 token：不带封面图（容量有限），保证可扫。
    private var qrLinkString: String {
        let t = makeToken(includeCover: false)
        return PostcardToken.shareURL(t)?.absoluteString ?? t
    }

    @MainActor private func rerender() {
        coverB64 = cover.flatMap { PostcardToken.encodeCover($0) }   // 压缩封面（AirDrop/链接带图）
        // Plus：无水印 + 高清(3x)；免费：盖水印 + 标清(2x)
        let card = PostcardExportCard(footprint: footprint, cover: cover, message: message,
                                      recipient: recipient, style: style, stamp: stamp,
                                      watermark: !store.isPlus, sender: senderName, dateText: dateText)
        shareImage = ShareRender.image(card, scale: store.isPlus ? 3 : 2)
        // 二维码：高容错(H) + 中心 logo + Lumi 文案，渲染成带样式的卡片图
        if let qrUI = PostcardToken.qrImage(qrLinkString, correction: "H") {
            qr = ShareRender.image(PostcardQRCard(qr: qrUI), scale: 3)
        }
        cardFile = PostcardToken.writeCardFile(tokenString)
        copied = false
    }

    private func copyLink() {
        UIPasteboard.general.string = shareLinkString
        contacts.record(recipient, sent: true)   // 复制链接寄出也攒往来
        // 标记为「本机分享出去的」：剪贴板被动探测会跳过它（不自弹），
        // 但主动扫码 / 点链接仍可收下 → 支持「自己发自己收」。
        PostcardInbox.shared.markShared(token)
        copied = true
        Haptics.selection()
    }
}
