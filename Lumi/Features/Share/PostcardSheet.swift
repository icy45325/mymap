import SwiftUI
import UIKit

/// 明信片分享编辑器：实时预览 + 可改的手写寄语（自动生成默认）+ 分享成图 / 口令 / 二维码。
struct PostcardSheet: View {
    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lumi.receivedTokens") private var receivedTokensRaw: String = ""
    @ObservedObject private var store = PlusStore.shared
    @State private var message: String
    @State private var cover: UIImage?
    @State private var shareImage: Image?
    @State private var qr: Image?
    @State private var cardFile: URL?                // AirDrop 用的 .lumicard 文件
    @State private var copied = false
    @State private var showPaywall = false
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
                    PostcardView(footprint: footprint, cover: cover, message: message, watermark: !store.isPlus)
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
                            Label("邮寄明信片", systemImage: "paperplane.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(LinearGradient.neonH, in: Capsule())
                                .foregroundStyle(.white)
                        }
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
        .task { cover = await loadAssetUIImage(footprint.photoAssetIDs.first); rerender() }
        .onChange(of: message) { _, _ in rerender() }
        .onChange(of: store.isPlus) { _, _ in rerender() }   // 升级后即时去水印 / 提清
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

    @MainActor private func rerender() {
        // Plus：无水印 + 高清(3x)；免费：盖水印 + 标清(2x)
        let card = PostcardView(footprint: footprint, cover: cover, message: message, watermark: !store.isPlus)
        shareImage = ShareRender.image(card, scale: store.isPlus ? 3 : 2)
        qr = PostcardToken.qrImage(shareLinkString).map { Image(uiImage: $0) }
        cardFile = PostcardToken.writeCardFile(tokenString)
        copied = false
    }

    private func copyLink() {
        UIPasteboard.general.string = shareLinkString
        // 标记本机已「见过」此 token，避免发送方自己再被弹「收到明信片」
        var seen = Set(receivedTokensRaw.split(separator: ",").map(String.init))
        seen.insert(token)
        receivedTokensRaw = seen.joined(separator: ",")
        copied = true
    }
}
