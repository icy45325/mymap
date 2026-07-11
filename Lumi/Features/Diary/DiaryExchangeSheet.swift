import SwiftUI
import SwiftData

/// 寄出封存的日记：伙伴清单逐个直投（有邮箱号者）+ 复制口令 / 二维码 / AirDrop。
/// 同一份口令全员通用（封存时固化 `sealToken`），重寄天然幂等。
struct DiaryExchangeSheet: View {

    @Bindable var diary: ExchangeDiary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var post = LumiPost.shared

    @State private var sendingID: UUID?
    @State private var sentIDs: Set<UUID> = []
    @State private var sendResult: LocalizedStringKey?
    @State private var sendFailed = false
    @State private var copied = false
    @State private var showQR = false

    private var token: String { diary.sealToken ?? "" }
    private var qrOK: Bool { token.count <= DiaryToken.qrLimit }
    private var sortedPartners: [DiaryPartner] {
        diary.partners.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary
                    if LumiPostConfig.isEnabled, sortedPartners.contains(where: { $0.boxID != nil }) {
                        directList
                    }
                    copyRow
                    if qrOK { qrRow } else {
                        Text("这本日记比较长，二维码装不下——用口令或邮局直投吧")
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
            .navigationTitle("寄给伙伴们")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showQR) { qrSheet }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: diary.title).font(Typo.serif(19)).foregroundStyle(Color.text)
            Text("\(diary.entries.count) 条 · 封存于 \(diary.sealedAt?.formatted(.dateTime.month().day()) ?? "")")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
            Text("同一份口令全员通用——发进群里，伙伴们都能收下 ✦")
                .font(.system(size: 11)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 邮局逐人直投

    private var directList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lumi 邮局直投", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
            ForEach(sortedPartners) { partner in
                HStack(spacing: 10) {
                    PersonAvatar.named(partner.name, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: partner.name.isEmpty ? "…" : partner.name)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
                        if let box = partner.boxID {
                            Text(verbatim: box)
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.faint)
                        } else {
                            Text("没有邮箱号 · 用口令/二维码给 Ta")
                                .font(.system(size: 10)).foregroundStyle(Color.faint)
                        }
                    }
                    Spacer()
                    if partner.boxID != nil {
                        if sentIDs.contains(partner.id) || partner.sentAt != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                Text("已寄").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.nCyan)
                        } else {
                            Button { send(to: partner) } label: {
                                if sendingID == partner.id {
                                    ProgressView().tint(.white).scaleEffect(0.7)
                                        .frame(width: 44, height: 26)
                                } else {
                                    Text("寄出 ✦").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(LinearGradient.neon, in: Capsule())
                                }
                            }
                            .disabled(sendingID != nil)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.nPink.opacity(0.35), lineWidth: 1))
    }

    private func send(to partner: DiaryPartner) {
        guard let box = partner.boxID, !token.isEmpty else { return }
        sendingID = partner.id
        sendResult = nil
        Task {
            do {
                await post.ensureMailbox()
                _ = try await post.send(payload: token, to: box)
                partner.sentAt = .now
                sentIDs.insert(partner.id)
                markSent()
                sendFailed = false
                sendResult = "已寄给 \(partner.name) ✦"
                Haptics.success()
            } catch {
                sendFailed = true
                sendResult = "寄送失败：\(error.localizedDescription)"
            }
            sendingID = nil
        }
    }

    // MARK: - 口令 / 二维码 / AirDrop（全员同一份）

    private var copyRow: some View {
        channelRow(icon: "doc.on.doc", title: copied ? "已复制 ✓" : "复制口令",
                   subtitle: "发到任何聊天工具或群里，伙伴打开 App 自动收到") {
            UIPasteboard.general.string = token
            copied = true
            markSent()
            Haptics.success()
        }
    }

    private var qrRow: some View {
        channelRow(icon: "qrcode", title: "二维码",
                   subtitle: "伙伴在明信片墙「扫码」即可收下") {
            showQR = true
            markSent()
        }
    }

    @ViewBuilder
    private var airdropRow: some View {
        if let fileURL = DiaryToken.writeDiaryFile(token) {
            ShareLink(item: fileURL) {
                channelLabel(icon: "square.and.arrow.up", title: "AirDrop / 分享文件",
                             subtitle: "伙伴用 Lumi 打开即收下")
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
            Text("伙伴：明信片墙 → 扫码").font(.system(size: 12)).foregroundStyle(Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    /// 任一通道出手即记「已寄出」；口令封存时已 markShared，防剪贴板自弹。
    private func markSent() {
        if diary.sentAt == nil { diary.sentAt = .now }
        try? context.save()
    }
}
