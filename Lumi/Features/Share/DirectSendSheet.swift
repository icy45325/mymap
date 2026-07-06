import SwiftUI
import UIKit

/// 直寄到 Lumi 邮箱（v1.1）：输入对方邮箱号 / 从往来的人快选 → `send_mail` 站内直投。
/// 仅在 `LumiPostConfig.isEnabled` 时可达（入口已在 PostcardSheet 里门控）。
struct DirectSendSheet: View {
    let payload: String          // 明信片口令编码（含压缩封面）
    let footprintID: String      // 记台账用（足迹详情「已送达 ✓」）
    let recipientName: String    // 「寄给」昵称（记入往来的人）
    let token: String            // 分享幂等标识（markShared 防自弹）

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var post = LumiPost.shared
    @ObservedObject private var contacts = PostcardContacts.shared
    @State private var boxInput = ""
    @State private var sending = false
    @State private var sentOK = false
    @State private var errorText: String?

    /// 有邮箱号的往来联系人（可点选直寄）。
    private var sendableContacts: [PostcardContact] {
        contacts.recent.filter { $0.boxID != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("输入对方的 Lumi 邮箱号，明信片直接寄进 Ta 的 App")
                        .font(.system(size: 12)).foregroundStyle(Color.muted)

                    TextField("LUMI-XXXXXX", text: $boxInput)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(Color.text)
                        .padding(14)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
                        .onChange(of: boxInput) { _, _ in errorText = nil }

                    if !sendableContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("从往来的人里选").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.muted)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sendableContacts.prefix(10)) { c in
                                        Button { boxInput = c.boxID ?? ""; Haptics.selection() } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "envelope.fill")
                                                    .font(.system(size: 9)).foregroundStyle(Color.nOrange)
                                                Text(c.name).font(.system(size: 12))
                                                    .foregroundStyle(Color.text).lineLimit(1)
                                            }
                                            .padding(.vertical, 7).padding(.horizontal, 12)
                                            .background(Color.panel, in: Capsule())
                                            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.nOrange)
                    }

                    Button { Task { await sendNow() } } label: {
                        Group {
                            if sentOK {
                                Label("寄出成功！对方打开 Lumi 就能收到", systemImage: "checkmark.circle.fill")
                            } else if sending {
                                ProgressView().tint(.white)
                            } else {
                                Label("直寄", systemImage: "paperplane.fill")
                            }
                        }
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(sentOK ? AnyShapeStyle(Color.nCyan.opacity(0.85))
                                           : AnyShapeStyle(LinearGradient.neonH), in: Capsule())
                    }
                    .disabled(sending || sentOK ||
                              boxInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    myBoxRow
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("直寄到 Lumi 邮箱")
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
        .task { await post.ensureMailbox() }
    }

    /// 我的邮箱号（当面互换用）：点按复制。
    private var myBoxRow: some View {
        Group {
            if let identity = post.identity {
                Button {
                    UIPasteboard.general.string = identity.boxID
                    Haptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full").font(.system(size: 12)).foregroundStyle(Color.nCyan)
                        Text("我的 Lumi 邮箱号").font(.system(size: 12)).foregroundStyle(Color.muted)
                        Text(verbatim: identity.boxID)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.text)
                        Spacer()
                        Image(systemName: "doc.on.doc").font(.system(size: 11)).foregroundStyle(Color.muted)
                    }
                    .padding(12)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sendNow() async {
        let target = LumiPost.normalize(boxInput)
        sending = true; errorText = nil
        defer { sending = false }
        do {
            let mailID = try await post.send(payload: payload, to: target)
            post.recordSent(footprintID: footprintID, mailID: mailID)
            PostcardInbox.shared.markShared(token)   // 防剪贴板被动探测自弹（与复制链接同款）
            // 「寄给」没写名字就拿邮箱号当名字，保证 boxID 能存进往来的人
            let name = recipientName.trimmingCharacters(in: .whitespaces)
            contacts.record(name.isEmpty ? target : name, boxID: target, sent: true)
            sentOK = true
            Haptics.success()
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
