import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

/// 明信片口令载荷：编码一条足迹的要素 + 幂等 token（防重复接收）+ 手写寄语。
struct PostcardPayload: Codable {
    let token: String           // 幂等标识（每张分享卡唯一）
    let place: String
    let city: String?
    let countryCode: String?
    let lat: Double
    let lon: Double
    let visitedAt: Date
    let message: String
    let sender: String?
    var style: String? = nil  // 明信片样式（vintage/modern/vivid），旧口令可空
    var stamp: String? = nil  // 邮票（air/city），旧口令可空
    var cover: String? = nil  // 压缩封面图 base64（链接带，QR 因容量不带）
    var senderAvatar: String? = nil   // 寄件人头像缩略图 base64（≈96px，随卡传给「往来的人」）
    var senderCountry: String? = nil  // 寄件人国籍码（ISO2）
}

/// 明信片口令编解码（纯本地带外传输：复制口令 / 二维码 → 对方在 App 内自动收下）。
enum PostcardToken {
    static let prefix = "LUMI1:"

    static func encode(footprint fp: Footprint, message: String, token: String,
                       sender: String? = nil, style: String? = nil, stamp: String? = nil,
                       date: Date? = nil, cover: String? = nil,
                       senderAvatar: String? = nil, senderCountry: String? = nil) -> String {
        let p = PostcardPayload(token: token, place: fp.placeName, city: fp.cityName,
                                countryCode: fp.countryCode, lat: fp.latitude, lon: fp.longitude,
                                visitedAt: date ?? fp.visitedAt, message: message, sender: sender,
                                style: style, stamp: stamp, cover: cover,
                                senderAvatar: senderAvatar, senderCountry: senderCountry)
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return prefix + data.base64EncodedString()
    }

    /// 把封面 UIImage 压成可放进口令的 base64（约 320px、JPEG）。供 AirDrop / 链接携带。
    static func encodeCover(_ image: UIImage, maxDim: CGFloat = 320, quality: CGFloat = 0.5) -> String? {
        let scale = min(1, maxDim / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let r = UIGraphicsImageRenderer(size: target)
        let small = r.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return small.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    static func decode(_ raw: String) -> PostcardPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix(prefix),
              let data = Data(base64Encoded: String(s.dropFirst(prefix.count)))
        else { return nil }
        return try? JSONDecoder().decode(PostcardPayload.self, from: data)
    }

    /// 从任意文本里提取口令：兼容裸口令 `LUMI1:…` 与链接 `lumi://card?t=…`。
    static func find(in text: String) -> PostcardPayload? {
        func firstWord(from i: Substring.Index, of s: String) -> String {
            let tail = s[i...]
            return tail.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" }).first.map(String.init)
                ?? String(tail)
        }
        if let r = text.range(of: "lumi://"), let url = URL(string: firstWord(from: r.lowerBound, of: text)) {
            return payload(from: url)
        }
        if let r = text.range(of: prefix) {
            return decode(firstWord(from: r.lowerBound, of: text))
        }
        return nil
    }

    // MARK: - URL scheme / AirDrop 文件

    /// 可点链接 / 二维码用：`lumi://card?t=<口令>`。
    static func shareURL(_ tokenString: String) -> URL? {
        var c = URLComponents()
        c.scheme = "lumi"; c.host = "card"
        c.queryItems = [URLQueryItem(name: "t", value: tokenString)]
        return c.url
    }

    /// 从 URL 取载荷：`lumi://card?t=…` 或 AirDrop 来的 `.lumicard` 文件。
    static func payload(from url: URL) -> PostcardPayload? {
        if url.isFileURL {
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return find(in: s)
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           comps.scheme == "lumi",
           let t = comps.queryItems?.first(where: { $0.name == "t" })?.value {
            return decode(t)
        }
        return nil
    }

    /// 写一个 `.lumicard` 临时文件用于 AirDrop / 分享。
    static func writeCardFile(_ tokenString: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lumi 明信片.lumicard")
        do { try Data(tokenString.utf8).write(to: url); return url } catch { return nil }
    }

    /// 把口令生成二维码图。`correction` 高（H≈30%）时中心可叠 logo 不影响识别。
    static func qrImage(_ string: String, scale: CGFloat = 12, correction: String = "M") -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correction
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        guard let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
