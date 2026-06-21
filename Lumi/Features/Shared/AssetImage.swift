import SwiftUI
import Photos

/// 按 PhotoKit 本地标识符加载相册图（v0 不拷贝原图，只引用）。
/// 资源失效（用户从系统相册删了照片）→ 显示占位图，不崩溃（§7）。
struct AssetImage: View {

    let assetID: String?
    var targetSize: CGSize = CGSize(width: 240, height: 240)

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: assetID) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            Color.panel2
            Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
                .font(.system(size: 22))
                .foregroundStyle(Color.textMuted)
        }
    }

    private func load() async {
        image = nil
        failed = false
        guard let assetID else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = fetch.firstObject else { failed = true; return }   // 照片已被删

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat   // 单次回调，避免续体被多次 resume
        options.resizeMode = .fast

        let loaded: UIImage? = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { img, _ in cont.resume(returning: img) }
        }
        if loaded == nil { failed = true }
        image = loaded
    }
}
