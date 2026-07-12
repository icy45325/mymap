import SwiftUI
import Photos

/// 按 assetID 异步取相册原图（供 ImageRenderer 等需要「先拿到 UIImage 再同步渲染」的场景，如明信片）。
func loadAssetUIImage(_ assetID: String?, targetSize: CGSize = CGSize(width: 1440, height: 1440)) async -> UIImage? {
    guard let assetID,
          let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
    else { return nil }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat   // 单次回调，避免 continuation 多次 resume
    options.resizeMode = .exact
    return await withCheckedContinuation { cont in
        PHImageManager.default().requestImage(
            // aspectFit：保留原始长宽比（明信片横竖版由照片比例判定，aspectFill 会一律裁成目标比例）
            for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options
        ) { img, _ in cont.resume(returning: img) }
    }
}

/// 按 PhotoKit 本地标识符加载相册图（v0 不拷贝原图，只引用）。
/// 资源失效（用户从系统相册删了照片）→ 显示占位图，不崩溃（§7）。
///
/// 性能（2026-07-11 重写）：共享 `PHCachingImageManager` + `NSCache` 内存缓存；
/// `.opportunistic` 低清先上、高清覆盖（缩略图秒出）；请求可取消（滚动不堆积）；
/// `PHAsset.fetchAssets` 移出主线程。对外 API 不变。
struct AssetImage: View {

    let assetID: String?
    var targetSize: CGSize = CGSize(width: 240, height: 240)

    @State private var image: UIImage?
    @State private var failed = false
    @State private var requestID: PHImageRequestID?

    private static let manager = PHCachingImageManager()
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .onAppear { start() }
        .onChange(of: assetID) { _, _ in start() }
        .onDisappear { cancel() }
    }

    private var placeholder: some View {
        ZStack {
            Color.panel2
            Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
                .font(.system(size: 22))
                .foregroundStyle(Color.textMuted)
        }
    }

    private func cacheKey(_ id: String) -> NSString {
        "\(id)@\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    }

    private func start() {
        cancel()
        failed = false
        guard let assetID else { image = nil; return }
        if let hit = Self.cache.object(forKey: cacheKey(assetID)) { image = hit; return }
        image = nil
        let size = targetSize
        let key = cacheKey(assetID)
        // fetchAssets 是同步磁盘调用——放到后台，避免列表滚动时主线程逐图卡顿
        Task.detached(priority: .userInitiated) {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = fetch.firstObject else {
                await MainActor.run { failed = true }       // 照片已被删
                return
            }
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true           // iCloud 优化存储的图仍能出
            options.deliveryMode = .opportunistic           // 低清先上、高清覆盖（可能多次回调）
            options.resizeMode = .fast
            let id = Self.manager.requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { img, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                Task { @MainActor in
                    if let img {
                        image = img
                        if !degraded { Self.cache.setObject(img, forKey: key) }
                    } else if !degraded, image == nil {
                        failed = true
                    }
                }
            }
            await MainActor.run { requestID = id }
        }
    }

    private func cancel() {
        if let requestID { Self.manager.cancelImageRequest(requestID) }
        requestID = nil
    }
}
