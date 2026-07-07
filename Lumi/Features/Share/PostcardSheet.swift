import SwiftUI
import SwiftData
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
    @State private var copied = false
    @State private var showPaywall = false
    @State private var mailbox = ""                  // 对方 Lumi 邮箱号（填了 → 直寄成为主按钮）
    @State private var avatarB64: String?            // 我的头像缩略图（随卡传给对方的往来名单）
    @State private var sending = false
    @State private var sentOK = false
    @State private var sendError: String?
    @State private var token = UUID().uuidString    // 本张分享卡的幂等标识（稳定）
    @State private var style: PostcardStyle
    @State private var stamp: StampKind
    @State private var flipped = false
    @State private var recipient = ""
    @State private var sendDate: Date                // 发送日期，限定在行程范围内
    @State private var fromName: String              // 寄自（默认个人资料名字，可改）
    @State private var coverAssetID: String?         // 当前选作封面的相册资源 id（nil=新选/无）
    @State private var pickedPhoto: PhotosPickerItem?

    /// `prefillRecipient` / `prefillMailbox`：回寄入口预填收件人与邮箱号（填了号直寄即为主按钮）。
    init(footprint: Footprint, prefillRecipient: String? = nil, prefillMailbox: String? = nil) {
        self.footprint = footprint
        _message = State(initialValue: defaultPostcardMessage(footprint))
        _style = State(initialValue: PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage)
        _stamp = State(initialValue: StampKind(raw: footprint.stampStyle))
        _sendDate = State(initialValue: footprint.visitedAt)
        _fromName = State(initialValue: UserDefaults.standard.string(forKey: "lumi.profile.name") ?? "")
        _coverAssetID = State(initialValue: footprint.photoAssetIDs.first)
        _recipient = State(initialValue: prefillRecipient ?? "")
        _mailbox = State(initialValue: prefillMailbox ?? "")
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

    /// `includeCover` 区分：true=链接/直寄（带压缩封面图）；false=二维码（容量有限不带图）。
    private func makeToken(includeCover: Bool) -> String {
        let nation = UserDefaults.standard.string(forKey: "lumi.profile.nationality")
        return PostcardToken.encode(footprint: footprint, message: message, token: token,
                                    sender: senderName.isEmpty ? nil : senderName,
                                    style: style.rawValue, stamp: stamp.raw,
                                    date: sendDate, cover: includeCover ? coverB64 : nil,
                                    senderAvatar: includeCover ? avatarB64 : nil,
                                    senderCountry: (nation?.isEmpty ?? true) ? nil : nation,
                                    senderBox: LumiPost.shared.identity?.boxID)
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
                            if LumiPostConfig.isEnabled {
                                HStack(spacing: 8) {
                                    Image(systemName: "tray.full").font(.system(size: 12))
                                        .foregroundStyle(Color.nOrange)
                                    TextField("Lumi 邮箱号（选填，填了可直寄）", text: $mailbox)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .foregroundStyle(Color.text)
                                }
                                .padding(12)
                                .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(mailboxFilled ? Color.nOrange.opacity(0.6) : Color.line, lineWidth: 1))
                                .onChange(of: mailbox) { _, _ in sendError = nil; sentOK = false }
                            }
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
                        VStack(spacing: 10) {
                            if LumiPostConfig.isEnabled && mailboxFilled {
                                // 填了邮箱号 → 直寄是主按钮（默认寄送方式）
                                Button { Task { await directSend() } } label: {
                                    Group {
                                        if sentOK {
                                            Label("已寄达对方邮箱", systemImage: "checkmark.circle.fill")
                                        } else if sending {
                                            ProgressView().tint(.white)
                                        } else {
                                            Label("直寄到 Lumi 邮箱", systemImage: "paperplane.fill")
                                        }
                                    }
                                    .font(.headline).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(sentOK ? AnyShapeStyle(Color.nCyan.opacity(0.85))
                                                       : AnyShapeStyle(LinearGradient.neonH), in: Capsule())
                                }
                                .disabled(sending || sentOK)
                                if let sendError {
                                    Label(sendError, systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12)).foregroundStyle(Color.nOrange)
                                }
                                HStack(spacing: 10) {
                                    ShareLink(item: shareImage,
                                              preview: SharePreview(footprint.title, image: shareImage)) {
                                        miniLabel("分享图片", "square.and.arrow.up", Color.nCyan)
                                    }
                                    igShare
                                }
                            } else {
                                // 没填邮箱号 → 分享成图为主，提示可直寄
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
                                    igShare
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                if LumiPostConfig.isEnabled {
                                    Text("对方也用 Lumi？在上方填 Ta 的邮箱号即可直寄")
                                        .font(.system(size: 11)).foregroundStyle(Color.muted)
                                }
                            }
                        }
                    } else {
                        ProgressView().tint(Color.nPink).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }

                    // 备用通道：链接 / 二维码（对方扫码或点开即在 Lumi 收下）
                    HStack(spacing: 10) {
                        Button { copyLink() } label: {
                            miniLabel(copied ? "已复制" : "复制链接", copied ? "checkmark" : "link", Color.nCyan)
                        }
                        if let qr {
                            ShareLink(item: qr, preview: SharePreview("Lumi 明信片二维码", image: qr)) {
                                miniLabel("二维码", "qrcode", Color.nPink)
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
        .sheet(isPresented: $showPaywall, onDismiss: {
            Task { await store.refreshEntitlement(); rerender() }   // 付费回来立即解锁典藏票，可继续寄
        }) { PaywallView() }
        .task { cover = await loadAssetUIImage(coverAssetID); rerender() }   // 封面先行加载，不被网络阻塞
        .task { await store.refreshEntitlement() }      // 权益对齐并行（订阅后无需再开订阅页）
        .task {                                          // 头像缩略图（≈96px）随卡传给对方
            let avatarID = UserDefaults.standard.string(forKey: "lumi.profile.avatarID")
            if let id = avatarID, !id.isEmpty,
               let ui = await loadAssetUIImage(id, targetSize: CGSize(width: 192, height: 192)) {
                avatarB64 = PostcardToken.encodeCover(ui, maxDim: 96, quality: 0.6)
            }
        }
        .onChange(of: message) { _, _ in rerender() }
        .onChange(of: recipient) { _, _ in rerender() }      // 导出图含「寄给」，改收件人即时重渲
        .onChange(of: fromName) { _, _ in rerender() }       // 「寄自」即时重渲
        .onChange(of: store.isPlus) { _, _ in rerender() }   // 升级后即时去水印 / 提清
        .onChange(of: style) { _, _ in rerender() }
        .onChange(of: stamp) { _, _ in rerender() }
        .onChange(of: sendDate) { _, _ in rerender() }
        .onChange(of: coverAssetID) { _, id in
            guard let id else { return }   // nil = 刚从相册新选了一张（cover 已直接赋值），别再异步清空它
            Task { cover = await loadAssetUIImage(id); rerender() }   // 选了足迹自带的某张
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

    /// 该足迹所在国的特色邮票（地区票**仅限本国足迹**使用；目录里没有该国则不出现）。
    private var footprintRegional: RegionalStamp? {
        footprint.countryCode.flatMap { RegionalStamp.byCode($0) }
    }
    /// 当前可用的节日章：**今天**落在节日窗口（前后 5 天）内 + 足迹地区匹配。
    private var eligibleFestivals: [Festival] {
        Festival.eligible(countryCode: footprint.countryCode, on: Date())
    }
    /// 匹配该足迹（国家 + 子区域）的典藏票；非 Plus 只露前 2 枚作付费入口。
    private var visiblePremiums: [PremiumStamp] {
        let matched = PremiumStamp.matching(countryCode: footprint.countryCode,
                                            subRegionCode: footprint.subRegionCode)
        return store.isPlus ? matched : Array(matched.prefix(2))
    }

    /// 邮票选择：基础三款 + 本国特色票 + 窗口期内节日章 + 典藏票（Plus / 带锁入口）。
    private var stampPicker: some View {
        editorBlock("邮票") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PostcardStamp.allCases) { p in
                        stampCell(.basic(p), title: Text(p.label))
                    }
                    if let r = footprintRegional {
                        stampCell(.regional(r), title: Text(verbatim: "\(r.flag) \(r.displayName)"))
                    }
                    ForEach(eligibleFestivals) { f in
                        stampCell(.festival(f), title: Text(f.titleKey))
                    }
                    ForEach(visiblePremiums) { p in premiumCell(p) }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// 典藏票 cell：Plus 正常选用；非 Plus 带锁 + PLUS 徽记，点击弹 Paywall（付费入口）。
    private func premiumCell(_ p: PremiumStamp) -> some View {
        let locked = !store.isPlus
        let kind = StampKind.premium(p)
        let active = kind == stamp
        return Button {
            if locked { showPaywall = true } else { stamp = kind; Haptics.selection() }
        } label: {
            VStack(spacing: 5) {
                StampView(kind: kind, mini: true)
                    .frame(width: 30, height: 36)
                    .grayscale(locked ? 0.6 : 0).opacity(locked ? 0.75 : 1)
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(3).background(.black.opacity(0.55), in: Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                HStack(spacing: 3) {
                    Text(p.nameKey).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(active ? Color.text : Color.muted).lineLimit(1)
                    if locked {
                        Text(verbatim: "PLUS").font(.system(size: 7, weight: .heavy)).tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.vertical, 2).padding(.horizontal, 5)
                            .background(LinearGradient.neonH, in: Capsule())
                    }
                }
            }
            .frame(minWidth: 74).padding(.vertical, 9).padding(.horizontal, 6)
            .background(active ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(active ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stampCell(_ kind: StampKind, title: Text) -> some View {
        let active = kind == stamp
        return Button { stamp = kind; Haptics.selection() } label: {
            VStack(spacing: 5) {
                StampView(kind: kind, mini: true).frame(width: 30, height: 36)
                title.font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? Color.text : Color.muted)
                    .lineLimit(1)
            }
            .frame(minWidth: 74).padding(.vertical, 9).padding(.horizontal, 6)
            .background(active ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(active ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 邮箱号已填（去空格后非空）。
    private var mailboxFilled: Bool { !mailbox.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Instagram 分享按钮（装了 IG 才出现，点按高清现渲染）。
    private var igShare: some View {
        InstagramShareButton {
            ShareRender.uiImage(
                PostcardExportCard(footprint: footprint, cover: cover, message: message,
                                   recipient: recipient, style: style, stamp: stamp,
                                   watermark: !store.isPlus, sender: senderName, dateText: dateText),
                scale: 4)
        }
    }

    /// 站内直寄（v1.1 默认寄送方式）：寄达对方 Lumi 邮箱。
    @MainActor private func directSend() async {
        let target = LumiPost.normalize(mailbox)
        sending = true; sendError = nil
        defer { sending = false }
        do {
            let mailID = try await LumiPost.shared.send(payload: tokenString, to: target)
            LumiPost.shared.recordSent(footprintID: footprint.id.uuidString, mailID: mailID)
            PostcardInbox.shared.markShared(token)   // 防剪贴板被动探测自弹
            let name = recipient.trimmingCharacters(in: .whitespaces)
            contacts.record(name.isEmpty ? target : name, boxID: target, sent: true)
            sentOK = true
            Haptics.success()
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // 让成功态停留一秒
            dismiss()                                            // 回足迹详情（详情页会刷新寄出记录）
        } catch {
            sendError = error.localizedDescription
        }
    }

    /// 往来联系人快选（点一下填入「寄给」；有邮箱号的连邮箱号一起带出）。
    private var contactSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(contacts.recent.prefix(8)) { c in
                    Button {
                        recipient = c.name
                        if let box = c.boxID { mailbox = box }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: c.boxID != nil ? "envelope.fill" : "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(c.boxID != nil ? Color.nOrange : Color.nCyan)
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
        // 权益回落守卫：非 Plus 不可寄典藏票（权益过期/未购时自动回落基础空运）
        if !store.isPlus, stamp.isPremium { stamp = .basic(.air) }
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
