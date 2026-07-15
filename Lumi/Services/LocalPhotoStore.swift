import UIKit

/// 手选照片的本地落地存储（第八批：相册权限修复）。
///
/// `PhotosPicker` 不需要相册权限就能选照片，但它返回的 `itemIdentifier` 走
/// `PHAsset.fetchAssets` 渲染时**受权限约束**——「部分照片（limited）」下选集外的照片
/// 永远取不到。因此手选照片改为**拷贝进 App 沙盒**（降采样 JPEG），id 用
/// `local:<uuid>.jpg` 前缀与 PHAsset id 共存于 `Footprint.photoAssetIDs`，模型零迁移；
/// 渲染端（AssetImage / loadAssetUIImage）按前缀分流。相册导入流仍引用 PHAsset
/// （扫描到的必在权限内），不经此存储。
enum LocalPhotoStore {

    static let prefix = "local:"
    /// 落地时的最长边（明信片渲染 1440 目标之上留余量）。
    private static let maxDimension: CGFloat = 2048

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("LocalPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func url(for id: String) -> URL? {
        guard id.hasPrefix(prefix) else { return nil }
        return dir.appendingPathComponent(String(id.dropFirst(prefix.count)))
    }

    /// 降采样 + JPEG 写盘；失败返回 nil（调用方回退存 itemIdentifier）。
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let scaled = downscale(image, to: maxDimension)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: dir.appendingPathComponent(name))
            return prefix + name
        } catch { return nil }
    }

    /// 读取（渲染端后台调用）；`maxDimension` 为目标最长边，避免小缩略图解码整张大图。
    static func loadUIImage(id: String, maxDimension target: CGFloat = 2048) -> UIImage? {
        guard let url = url(for: id), let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return downscale(image, to: target)
    }

    static func delete(_ id: String) {
        guard let url = url(for: id) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 启动时清理孤儿文件（删足迹的路径很多，统一在这里兜底）。
    /// `keeping`：仍被足迹引用的全部 `local:` id。
    static func purgeOrphans(keeping ids: Set<String>) {
        let names = Set(ids.compactMap { $0.hasPrefix(prefix) ? String($0.dropFirst(prefix.count)) : nil })
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where !names.contains(file) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    private static func downscale(_ image: UIImage, to maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
