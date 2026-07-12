import SwiftUI
import SwiftData

/// 远程交换的寄送面板：邀请（invite）与半页（halves）共用——
/// 邮箱直投（默认，大载荷主通道）/ 复制口令 / 二维码（小载荷）/ AirDrop。
struct DiaryShareSheet: View {

    enum Kind { case invite, halves }

    @Bindable var book: DiaryBook
    let kind: Kind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("lumi.profile.name") private var holderName: String = ""
    @ObservedObject private var post = LumiPost.shared

    @State private var token = ""
    @State private var boxInput = ""
    @State private var sending = false
    @State private var sendResult: LocalizedStringKey?
    @State private var sendFailed = false
    @State private var copied = false
    @State private var showQR = false

    private var pending: [(page: DiaryPage, half: DiaryHalf)] {
        kind == .halves ? DiaryBookStore.pendingHalves(of: book) : []
    }
    private var qrOK: Bool { !token.isEmpty && token.count <= DiaryLink.qrLimit }
    private var mailOK: Bool { !token.isEmpty && token.count <= DiaryLink.mailLimit }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary
                    if LumiPostConfig.isEnabled {
                        if mailOK { postRow } else if !token.isEmpty {
                            Text("这批内容太大寄不动了——语音短一点，或分几次寄")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.nOrange)
                        }
                    }
                    copyRow
                    if qrOK { qrRow } else if !token.isEmpty {
                        Text("内容较大，二维码装不下——用口令或邮局直投吧")
                            .font(.system(size: 11)).foregroundStyle(Color.faint)
                    }
                    airdropRow
                    if let sendResult {
                        Text(sendResult)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(sendFailed ? Color.nOrange : Color.nCyan)
                    }
                }
                .padding(22)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle(kind == .invite ? "邀请 \(book.partnerName)" : "寄给 \(book.partnerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showQR) { qrSheet }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear {
            boxInput = book.partnerBoxID ?? ""
            buildToken()
        }
    }

    private func buildToken() {
        let sender = holderName.isEmpty ? nil : holderName
        let box = post.identity?.boxID
        switch kind {
        case .invite:
            token = DiaryLink.encodeInvite(book: book, sender: sender, senderBox: box)
        case .halves:
            token = DiaryLink.encodeHalves(book: book, halves: pending, sender: sender, senderBox: box)
        }
        if let payload = DiaryLink.decode(token) {
            PostcardInbox.shared.markShared(payload.token)   // 防剪贴板自弹
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: book.title).font(Typo.serif(19)).foregroundStyle(Color.text)
            if kind == .invite {
                Text("邀请 Ta 在自己的 Lumi 里打开同一本——你们各写各的，互寄后逐页拆封")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            } else {
                Text("寄出 \(pending.count) 个已封存的半页——寄到后 Ta 那边对应页就能拆")
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 通道

    private var postRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lumi 邮局直投", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
            TextField("", text: $boxInput,
                      prompt: Text("对方邮箱号 LUMI-XXXXXX").foregroundStyle(Color.faint))
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(Color.text)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(11)
                .background(Color.glass, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
            Button { sendViaPost() } label: {
                HStack {
                    if sending { ProgressView().tint(.white) }
                    (sending ? Text("寄送中…") : Text("直接寄到对方邮箱 ✦"))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(LinearGradient.neon, in: Capsule())
            }
            .disabled(sending || boxInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(boxInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.nPink.opacity(0.35), lineWidth: 1))
    }

    private func sendViaPost() {
        let box = boxInput.trimmingCharacters(in: .whitespaces)
        guard !box.isEmpty, !token.isEmpty else { return }
        sending = true
        sendResult = nil
        Task {
            do {
                await post.ensureMailbox()
                _ = try await post.send(payload: token, to: box)
                book.partnerBoxID = box
                markSent()
                sendFailed = false
                sendResult = "已寄出——对方打开 App 就能收到 ✦"
                Haptics.success()
            } catch {
                sendFailed = true
                sendResult = "寄送失败：\(error.localizedDescription)"
            }
            sending = false
        }
    }

    private var copyRow: some View {
        channelRow(icon: "doc.on.doc", title: copied ? "已复制 ✓" : "复制口令",
                   subtitle: "发到任何聊天工具，对方打开 App 自动收到") {
            UIPasteboard.general.string = token
            copied = true
            markSent()
            Haptics.success()
        }
    }

    private var qrRow: some View {
        channelRow(icon: "qrcode", title: "二维码",
                   subtitle: "对方在明信片墙「扫码」即可收下") {
            showQR = true
            markSent()
        }
    }

    @ViewBuilder
    private var airdropRow: some View {
        if let fileURL = DiaryLink.writeFile(token) {
            ShareLink(item: fileURL) {
                channelLabel(icon: "square.and.arrow.up", title: "AirDrop / 分享文件",
                             subtitle: "对方用 Lumi 打开即收下")
            }
            .simultaneousGesture(TapGesture().onEnded { markSent() })
        }
    }

    private func channelRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { channelLabel(icon: icon, title: title, subtitle: subtitle) }
    }

    private func channelLabel(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.nCyan).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.text)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.faint)
        }
        .padding(15)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.line, lineWidth: 1))
    }

    private var qrSheet: some View {
        VStack(spacing: 16) {
            Text("扫码收日记").font(Typo.serif(20)).foregroundStyle(Color.text).padding(.top, 26)
            if let ui = PostcardToken.qrImage(token) {
                Image(uiImage: ui)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
            Text("对方：明信片墙 → 扫码").font(.system(size: 12)).foregroundStyle(Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    /// 任一通道出手：邀请置 inviteSentAt；半页置 syncedAt。
    private func markSent() {
        switch kind {
        case .invite:
            if book.inviteSentAt == nil { book.inviteSentAt = .now }
        case .halves:
            DiaryBookStore.markSynced(pending, context: context)
        }
        try? context.save()
    }
}
