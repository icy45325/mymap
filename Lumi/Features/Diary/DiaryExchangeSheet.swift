import SwiftUI
import SwiftData

/// 寄出封存的日记：邮局直投（默认，有对方邮箱号时）/ 复制口令 / 二维码 / AirDrop。
/// 口令在封存时已固化（`sealToken`），重寄永远同一口令 → 对端幂等。
struct DiaryExchangeSheet: View {

    @Bindable var diary: ExchangeDiary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var post = LumiPost.shared

    @State private var boxInput: String = ""
    @State private var sending = false
    @State private var sendResult: LocalizedStringKey?
    @State private var sendFailed = false
    @State private var copied = false
    @State private var showQR = false

    private var token: String { diary.sealToken ?? "" }
    /// 二维码容量之下才提供扫码通道。
    private var qrOK: Bool { token.count <= DiaryToken.qrLimit }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary
                    if LumiPostConfig.isEnabled { postRow }
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
            .navigationTitle("寄给对方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showQR) { qrSheet }
        }
        .preferredColorScheme(.dark)
        .tint(Color.nPink)
        .onAppear { boxInput = diary.partnerBoxID ?? "" }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: diary.title).font(Typo.serif(19)).foregroundStyle(Color.text)
            Text("\(diary.entries.count) 条 · 封存于 \(diary.sealedAt?.formatted(.dateTime.month().day()) ?? "")")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
            Text("对方收下后，等两边都封存就能互相拆开 ✦")
                .font(.system(size: 11)).foregroundStyle(Color.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - 邮局直投

    private var postRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lumi 邮局直投", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.text)
            TextField("", text: $boxInput,
                      prompt: Text("对方邮箱号 LUMI-XXXXXX").foregroundStyle(Color.faint))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(11)
                .background(Color.glass, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
            Button { sendViaPost() } label: {
                HStack {
                    if sending { ProgressView().tint(.white) }
                    (sending ? Text("寄送中…") : Text("直接寄到对方邮箱 ✦"))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
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
                diary.partnerBoxID = box
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

    // MARK: - 口令 / 二维码 / AirDrop

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
        if let fileURL = DiaryToken.writeDiaryFile(token) {
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

    /// 任一通道出手即记「已寄出」（等待对方态）；口令封存时已 markShared，防剪贴板自弹。
    private func markSent() {
        if diary.sentAt == nil { diary.sentAt = .now }
        try? context.save()
    }
}
