import SwiftUI
import SwiftData
import UIKit

/// 明信片墙：只收藏**收到的**明信片（扫码 / 链接 / 隔空投送收到的）。
/// 自己点亮的足迹不是明信片；自己寄出的（按明信片逻辑）自己也看不到。
struct PostcardWallView: View {
    @Query(sort: \Footprint.createdAt, order: .reverse) private var footprints: [Footprint]
    @ObservedObject private var contacts = PostcardContacts.shared
    @ObservedObject private var post = LumiPost.shared
    @State private var selected: Footprint?
    @State private var selectedContact: PostcardContact?
    @State private var showScanner = false
    @State private var sort: WallSort = .received
    @State private var boxCopied = false
    /// 按联系人筛选：只看 Ta 寄来的（nil = 全部）。
    @State private var filterSender: String?
    /// 邮箱号分享卡渲染缓存（identity 就绪后渲一次）。
    @State private var mailboxImage: Image?

    enum WallSort: String, CaseIterable, Identifiable {
        case received, place
        var id: String { rawValue }
        var label: LocalizedStringKey { self == .received ? "按接收时间" : "按国家 A–Z" }
    }

    private var items: [Footprint] {
        var received = footprints.filter { $0.isReceived }
        if let who = filterSender {
            received = received.filter { $0.senderName?.caseInsensitiveCompare(who) == .orderedSame }
        }
        switch sort {
        case .received:   // 接收时间倒序（无 receivedAt 的旧数据用 createdAt 兜底）
            return received.sorted { ($0.receivedAt ?? $0.createdAt) > ($1.receivedAt ?? $1.createdAt) }
        case .place:      // 国家名 A→Z（无国家码回退地点名）
            return received.sorted {
                let a = CountryInfo.localizedName(for: $0.countryCode) ?? $0.title
                let b = CountryInfo.localizedName(for: $1.countryCode) ?? $1.title
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
        }
    }

    /// 封面横竖判定（解码一次后缓存；无图默认竖版）。
    private static var orientCache: [UUID: Bool] = [:]
    private func isLandscape(_ fp: Footprint) -> Bool {
        if let hit = Self.orientCache[fp.id] { return hit }
        var v = false
        if let d = fp.receivedCoverData, let ui = UIImage(data: d) {
            v = ui.size.width > ui.size.height
        }
        Self.orientCache[fp.id] = v
        return v
    }

    /// 流式行：横版卡独占一行（宽 16:10 限高），竖版卡两两一行（3:4）。
    private var wallRows: [[Footprint]] {
        var rows: [[Footprint]] = []
        var pending: Footprint?
        for fp in items {
            if isLandscape(fp) {
                if let p = pending { rows.append([p]); pending = nil }
                rows.append([fp])
            } else if let p = pending {
                rows.append([p, fp]); pending = nil
            } else {
                pending = fp
            }
        }
        if let p = pending { rows.append([p]) }
        return rows
    }

    var body: some View {
        Group {
            if items.isEmpty && contacts.recent.isEmpty {
                emptyWrap
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if LumiPostConfig.isEnabled { mailboxCard }
                        if !items.isEmpty { countStat }
                        if !contacts.recent.isEmpty { contactsStrip }
                        if let who = filterSender { senderFilterChip(who) }
                        if items.isEmpty {
                            (filterSender == nil ? Text("还没有收到明信片") : Text("还没有收到 Ta 的明信片"))
                                .font(.subheadline).foregroundStyle(Color.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 28)
                        } else {
                            if items.count > 1 {
                                Picker("", selection: $sort) {
                                    ForEach(WallSort.allCases) { Text($0.label).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            LazyVStack(spacing: 12) {
                                ForEach(Array(wallRows.enumerated()), id: \.offset) { _, row in
                                    if row.count == 1 && isLandscape(row[0]) {
                                        Button { selected = row[0] } label: {
                                            PostcardCell(footprint: row[0], landscape: true)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        HStack(alignment: .top, spacing: 12) {
                                            ForEach(row) { fp in
                                                Button { selected = fp } label: { PostcardCell(footprint: fp) }
                                                    .buttonStyle(.plain)
                                                    .frame(maxWidth: .infinity)
                                            }
                                            if row.count == 1 {   // 奇数收尾：占位半宽保持对齐
                                                Color.clear.frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await LumiPost.shared.refreshInbox() }   // 下拉收信（未启用时 no-op）
            }
        }
        .task { await LumiPost.shared.refreshInbox() }                  // 进页即拉一次
        .task(id: post.identity?.boxID) {                               // 邮箱号分享卡预渲染
            guard let box = post.identity?.boxID else { return }
            mailboxImage = ShareRender.image(MailboxShareCard(boxID: box))
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("明信片墙")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showScanner = true } label: {
                    Label("扫码收明信片", systemImage: "qrcode.viewfinder")
                }
                .tint(Color.nCyan)
            }
        }
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(item: $selected) { ReceivedPostcardSheet(footprint: $0) }
        .sheet(item: $selectedContact) { c in
            ContactCardSheet(contact: c) { filterSender = $0.name }
        }
        .sheet(isPresented: $showScanner) { ScannerSheet() }
    }

    /// 联系人头像：有随卡传来的头像图就用，否则霓虹底 + 首字母。
    @ViewBuilder
    static func avatar(_ c: PostcardContact, size: CGFloat) -> some View {
        if let b64 = c.avatarB64, let data = Data(base64Encoded: b64), let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
                .overlay(Circle().stroke(Color.line, lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(LinearGradient.neon).frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.line, lineWidth: 1))
                Text(String(c.name.prefix(1))).font(Typo.serif(size * 0.4)).foregroundStyle(.white)
            }
        }
    }
    private func contactAvatar(_ c: PostcardContact, size: CGFloat) -> some View {
        Self.avatar(c, size: size)
    }

    /// 我的 Lumi 邮箱号卡（v1.1）：复制 / 分享给朋友；还没开通则一键开通。
    private var mailboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill").font(.system(size: 12)).foregroundStyle(Color.nOrange)
                Text("我的 Lumi 邮箱号").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            }
            if let identity = post.identity {
                HStack(spacing: 10) {
                    Text(verbatim: identity.boxID)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.text)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = identity.boxID
                        boxCopied = true; Haptics.selection()
                    } label: {
                        Label(boxCopied ? "已复制" : "复制邮箱号",
                              systemImage: boxCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.nCyan)
                            .padding(.vertical, 7).padding(.horizontal, 12)
                            .background(Color.bg, in: Capsule())
                            .overlay(Capsule().stroke(Color.nCyan.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    // 分享一张带品牌的邮箱号卡图（渲染完成前兜底纯文本）
                    if let img = mailboxImage {
                        ShareLink(item: img, preview: SharePreview("Lumi", image: img)) { mailboxShareIcon }
                    } else {
                        ShareLink(item: identity.boxID) { mailboxShareIcon }
                    }
                }
                Text("把邮箱号告诉朋友，Ta 就能把明信片直接寄进你的 App")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            } else {
                Button {
                    Task { await post.ensureMailbox() }
                } label: {
                    Label("开通我的邮箱", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(LinearGradient.neonH, in: Capsule())
                }
            }
        }
        .padding(14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    private var mailboxShareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nPink)
            .padding(8)
            .background(Color.bg, in: Circle())
            .overlay(Circle().stroke(Color.nPink.opacity(0.5), lineWidth: 1))
    }

    /// 按联系人筛选激活时的提示 chip（点 ✕ 清除）。
    private func senderFilterChip(_ who: String) -> some View {
        HStack(spacing: 8) {
            Button {
                filterSender = nil
                Haptics.selection()
            } label: {
                HStack(spacing: 5) {
                    Text("只看 \(who) 寄来的").font(.system(size: 12, weight: .semibold))
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.nPink)
                .padding(.vertical, 6).padding(.horizontal, 11)
                .background(Color.nPink.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.nPink.opacity(0.4), lineWidth: 1))
            }
            Spacer()
        }
    }

    /// 明信片墙统计：已收到的明信片数量（+ 往来的人数）。
    private var countStat: some View {
        HStack(spacing: 10) {
            statCard("\(items.count)", "收到的明信片")
            if !contacts.recent.isEmpty { statCard("\(contacts.recent.count)", "往来的人") }
        }
    }

    private func statCard(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Typo.serif(26)).foregroundStyle(Color.text)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
    }

    /// 往来的人（本地 social-lite）：收 / 发明信片攒下的昵称头像横条；点击看资料卡。
    private var contactsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("往来的人").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(contacts.recent) { c in
                        Button { selectedContact = c } label: {
                            VStack(spacing: 5) {
                                contactAvatar(c, size: 46)
                                    .overlay(alignment: .topTrailing) {
                                        if c.boxID != nil {   // 存了邮箱号 → 可直寄标识
                                            Image(systemName: "envelope.fill").font(.system(size: 7))
                                                .foregroundStyle(.white)
                                                .padding(3.5).background(Color.nOrange, in: Circle())
                                                .overlay(Circle().stroke(Color.bg, lineWidth: 1.5))
                                        }
                                    }
                                Text(c.name).font(.system(size: 10)).foregroundStyle(Color.muted)
                                    .lineLimit(1).frame(width: 52)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2).padding(.top, 4)   // 顶部留白：角标不被滚动容器裁切
            }
        }
    }

    /// 空态也能下拉收信、看到邮箱号卡（否则新用户找不到直投入口）。
    private var emptyWrap: some View {
        ScrollView {
            VStack(spacing: 16) {
                if LumiPostConfig.isEnabled { mailboxCard }
                empty.padding(.top, 60)
            }
            .padding(16)
        }
        .refreshable { await LumiPost.shared.refreshInbox() }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack").font(.system(size: 44)).foregroundStyle(Color.nPink)
            Text("还没有收到明信片").font(.headline).foregroundStyle(Color.text)
            Text("朋友用扫码 / 链接 / 隔空投送寄来的明信片，会收进这里")
                .font(.subheadline).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 查看收到的明信片：翻转 + 分享 + 寄卡人档案与一键回寄。
private struct ReceivedPostcardSheet: View {
    let footprint: Footprint
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @State private var flipped = false
    @State private var cover: UIImage?
    @State private var shareImage: Image?
    @State private var showReplyPicker = false

    /// 寄卡人在「往来的人」里的档案（头像 / 国籍 / 邮箱号随卡攒下）。
    private var senderContact: PostcardContact? {
        guard !sender.isEmpty else { return nil }
        return PostcardContacts.shared.contacts
            .first { $0.name.caseInsensitiveCompare(sender) == .orderedSame }
    }

    private var style: PostcardStyle { PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage }
    private var stamp: StampKind { StampKind(raw: footprint.stampStyle) }
    private var dateText: String { footprint.visitSpanText() }
    private var sender: String { footprint.senderName ?? "" }

    private var exportCard: PostcardExportCard {
        PostcardExportCard(footprint: footprint, cover: cover, message: footprint.mood,
                           recipient: holderName, style: style, stamp: stamp,
                           watermark: true, sender: sender, dateText: dateText, showPostmark: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PostcardFlipCard(footprint: footprint, cover: cover, message: footprint.mood,
                                     recipient: holderName, style: style, stamp: stamp, flipped: flipped,
                                     sender: sender, dateText: dateText, showPostmark: true)
                        .onTapGesture { withAnimation { flipped.toggle() } }

                    Button { withAnimation { flipped.toggle() } } label: {
                        Label("翻面", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                            .padding(.vertical, 9).padding(.horizontal, 18)
                            .background(Color.panel, in: Capsule())
                            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                    }

                    if !sender.isEmpty { senderCard }

                    if let shareImage {
                        HStack(spacing: 10) {
                            ShareLink(item: shareImage, preview: SharePreview(footprint.title, image: shareImage)) {
                                Label("分享", systemImage: "square.and.arrow.up")
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                                    .background(LinearGradient.neonH, in: Capsule()).foregroundStyle(.white)
                            }
                            InstagramShareButton { ShareRender.uiImage(exportCard, scale: 4) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                    } else {
                        ProgressView().tint(Color.nPink).padding(.vertical, 14)
                    }
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("明信片").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(Color.muted)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            if let d = footprint.receivedCoverData { cover = UIImage(data: d) }
            shareImage = ShareRender.image(exportCard, scale: 3)
        }
        .sheet(isPresented: $showReplyPicker) {
            ReplyFootprintPicker(recipientName: sender, recipientBox: senderContact?.boxID)
        }
    }

    /// 寄卡人档案卡：头像 + 名字 + 国籍 + 邮箱号 + 回寄按钮。
    private var senderCard: some View {
        let contact = senderContact
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let c = contact {
                    PostcardWallView.avatar(c, size: 46)
                } else {
                    PostcardWallView.avatar(PostcardContact(name: sender, lastAt: .now), size: 46)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("寄卡人").font(.system(size: 10)).foregroundStyle(Color.muted)
                        if let cc = contact?.countryCode {
                            Text(verbatim: flagEmoji(cc)).font(.system(size: 11))
                        }
                    }
                    Text(verbatim: sender).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.text)
                    if let box = contact?.boxID {
                        Text(verbatim: box)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                Button { showReplyPicker = true } label: {
                    Label("回寄明信片", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.vertical, 9).padding(.horizontal, 14)
                        .background(LinearGradient.neonH, in: Capsule())
                }
            }
        }
        .padding(14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
        .padding(.horizontal, 4)
    }
}

/// 回寄：从自己的足迹里挑一个作为明信片，收件人 / 邮箱号已预填。
private struct ReplyFootprintPicker: View {
    let recipientName: String
    let recipientBox: String?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Footprint.visitedAt, order: .reverse) private var footprints: [Footprint]
    @State private var replyTarget: Footprint?

    private var mine: [Footprint] { footprints.filter { !$0.isReceived } }
    private static let df: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()

    var body: some View {
        NavigationStack {
            Group {
                if mine.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "mappin.slash").font(.system(size: 34)).foregroundStyle(Color.muted)
                        Text("还没有可回寄的足迹，先去点亮一个地方吧")
                            .font(.subheadline).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(mine) { fp in
                                Button { replyTarget = fp } label: {
                                    HStack(spacing: 12) {
                                        Text(fp.flag).font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(fp.title).font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.text).lineLimit(1)
                                            Text(fp.visitSpanText(Self.df))
                                                .font(.system(size: 11)).foregroundStyle(Color.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12)).foregroundStyle(Color.muted)
                                    }
                                    .padding(13)
                                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("选一个足迹回寄")
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
        .sheet(item: $replyTarget) { fp in
            PostcardSheet(footprint: fp, prefillRecipient: recipientName, prefillMailbox: recipientBox)
        }
    }
}

/// 往来联系人资料卡：头像 + 名字 + 国籍 + 收发计数 + 邮箱号（可复制）+ 只看 Ta 寄来的。
private struct ContactCardSheet: View {
    let contact: PostcardContact
    /// 「看 Ta 寄来的明信片」回调（墙置筛选）。
    var onFilter: ((PostcardContact) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            PostcardWallView.avatar(contact, size: 84)
            VStack(spacing: 5) {
                Text(contact.name).font(Typo.serif(24)).foregroundStyle(Color.text)
                if let cc = contact.countryCode {
                    Text(verbatim: "\(flagEmoji(cc)) \(CountryInfo.localizedName(for: cc) ?? cc)")
                        .font(.system(size: 13)).foregroundStyle(Color.muted)
                }
            }
            HStack(spacing: 10) {
                statPill("\(contact.sentCount)", "寄给 Ta")
                statPill("\(contact.receivedCount)", "收到 Ta 的")
            }
            if let box = contact.boxID {
                Button {
                    UIPasteboard.general.string = box
                    copied = true; Haptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full").font(.system(size: 12)).foregroundStyle(Color.nOrange)
                        Text(verbatim: box)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.text)
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11)).foregroundStyle(copied ? Color.nCyan : Color.muted)
                    }
                    .padding(.vertical, 9).padding(.horizontal, 16)
                    .background(Color.panel, in: Capsule())
                    .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Text("寄明信片时从「往来的人」点选 Ta，即可直寄")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            if contact.receivedCount > 0, let onFilter {
                Button {
                    onFilter(contact)
                    Haptics.selection()
                    dismiss()
                } label: {
                    Label("看 Ta 寄来的明信片", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nPink)
                        .padding(.vertical, 9).padding(.horizontal, 18)
                        .background(Color.panel, in: Capsule())
                        .overlay(Capsule().stroke(Color.nPink.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 28).padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.muted).padding(10)
                    .background(Color.panel, in: Circle())
            }
            .padding(14)
        }
    }

    private func statPill(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Typo.serif(20)).foregroundStyle(Color.text)
            Text(label).font(.system(size: 10)).foregroundStyle(Color.muted)
        }
        .frame(minWidth: 86).padding(.vertical, 10).padding(.horizontal, 14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
    }
}

/// 明信片墙单元：封面（照片或霓虹渐变）+ 手写寄语片段 + 地点；收到的标「✦ 收到」。
/// 竖版 3:4；横版卡（封面宽>高）16:10 独占整行。
private struct PostcardCell: View {
    let footprint: Footprint
    var landscape: Bool = false

    private var style: PostcardStyle { PostcardStyle(rawValue: footprint.postcardStyle) ?? .vintage }
    private var stamp: StampKind { StampKind(raw: footprint.stampStyle) }
    private var aspect: CGFloat { landscape ? 16.0/10.0 : 3.0/4.0 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = footprint.receivedCoverData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if let id = footprint.photoAssetIDs.first {
                    AssetImage(assetID: id, targetSize: CGSize(width: 600, height: 800))
                } else {
                    LinearGradient(colors: PostcardTheme.make(style).photo,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Text(footprint.flag).font(.system(size: 64)).opacity(0.25))
                }
            }
            .aspectRatio(aspect, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                if !footprint.mood.isEmpty {
                    Text(footprint.mood).font(.handwriting(15)).foregroundStyle(.white)
                        .lineLimit(2)
                }
                HStack(spacing: 5) {
                    Text(footprint.flag).font(.system(size: 14))
                    Text(footprint.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .lineLimit(1)
                }
                if footprint.isReceived {
                    // 老数据 receivedAt 为空回落 createdAt（与墙排序口径一致）
                    Text("收到于 \((footprint.receivedAt ?? footprint.createdAt).formatted(.dateTime.year().month(.abbreviated).day()))")
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(12)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            StampView(kind: stamp, mini: true).frame(width: 26, height: 31).padding(8)
        }
        .overlay(alignment: .topTrailing) {
            if footprint.isReceived {
                Text("✦ 收到").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(Color.nPink.opacity(0.9), in: Capsule())
                    .padding(8)
            }
        }
    }
}
