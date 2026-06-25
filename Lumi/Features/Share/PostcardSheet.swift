import SwiftUI

/// 明信片分享编辑器：实时预览 + 可改的手写寄语（自动生成默认）+ 分享成图。
struct PostcardSheet: View {
    let footprint: Footprint

    @Environment(\.dismiss) private var dismiss
    @State private var message: String
    @State private var cover: UIImage?
    @State private var shareImage: Image?

    init(footprint: Footprint) {
        self.footprint = footprint
        _message = State(initialValue: defaultPostcardMessage(footprint))
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
    }
}
