import SwiftUI
import UIKit

/// 明信片分享编辑器：实时预览 + 可改的手写寄语（自动生成默认）+ 分享成图 / 口令 / 二维码。
struct PostcardSheet: View {
    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.receivedTokens") private var receivedTokensRaw: String = ""
    @State private var message: String
    @State private var cover: UIImage?
    @State private var shareImage: Image?
    @State private var qr: Image?
    @State private var copied = false
    @State private var token = UUID().uuidString    // 本张分享卡的幂等标识（稳定）

    init(footprint: Footprint) {
        self.footprint = footprint
        _message = State(initialValue: defaultPostcardMessage(footprint))
    }

    private var tokenString: String {
        PostcardToken.encode(footprint: footprint, message: message, token: token)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PostcardView(footprint: footprint, cover: cover, message: message)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.line, lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                        .scaleEffect(0.92)
                        .frame(height: 480 * 0.92)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("明信片寄语").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)
                        TextField("在明信片上写点什么…", text: $message, axis: .vertical)
                            .font(.handwriting(20))
                            .foregroundStyle(Color.text)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
                    }
                    .padding(.horizontal, 4)

                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview(footprint.title, image: shareImage)) {
                            Label("分享明信片", systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(LinearGradient.neonH, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    } else {
                        ProgressView().tint(Color.nPink).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }

                    // 口令 / 二维码：对方在 Lumi 里粘贴口令即可自动收下
                    VStack(spacing: 10) {
                        Text("或发口令 / 二维码 —— 对方在 Lumi 里自动收下")
                            .font(.system(size: 11)).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button { copyToken() } label: {
                                Label(copied ? "已复制口令" : "复制口令",
                                      systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nCyan)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(Color.panel, in: Capsule())
                                    .overlay(Capsule().stroke(Color.nCyan.opacity(0.5), lineWidth: 1))
                            }
                            if let qr {
                                ShareLink(item: qr, preview: SharePreview("Lumi 明信片二维码", image: qr)) {
                                    Label("二维码", systemImage: "qrcode")
                                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nPink)
                                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                                        .background(Color.panel, in: Capsule())
                                        .overlay(Capsule().stroke(Color.nPink.opacity(0.5), lineWidth: 1))
                                }
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
        .task { cover = await loadAssetUIImage(footprint.photoAssetIDs.first); rerender() }
        .onChange(of: message) { _, _ in rerender() }
    }

    @MainActor private func rerender() {
        shareImage = ShareRender.image(PostcardView(footprint: footprint, cover: cover, message: message))
        qr = PostcardToken.qrImage(tokenString).map { Image(uiImage: $0) }
        copied = false
    }

    private func copyToken() {
        UIPasteboard.general.string = tokenString
        // 标记本机已「见过」此 token，避免发送方自己再被弹「收到明信片」
        var seen = Set(receivedTokensRaw.split(separator: ",").map(String.init))
        seen.insert(token)
        receivedTokensRaw = seen.joined(separator: ",")
        copied = true
    }
}
