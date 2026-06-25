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
}

/// 明信片口令编解码（纯本地带外传输：复制口令 / 二维码 → 对方在 App 内自动收下）。
enum PostcardToken {
    static let prefix = "LUMI1:"

    static func encode(footprint fp: Footprint, message: String, token: String, sender: String? = nil) -> String {
        let p = PostcardPayload(token: token, place: fp.placeName, city: fp.cityName,
                                countryCode: fp.countryCode, lat: fp.latitude, lon: fp.longitude,
                                visitedAt: fp.visitedAt, message: message, sender: sender)
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return prefix + data.base64EncodedString()
    }

    static func decode(_ raw: String) -> PostcardPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix(prefix),
              let data = Data(base64Encoded: String(s.dropFirst(prefix.count)))
        else { return nil }
        return try? JSONDecoder().decode(PostcardPayload.self, from: data)
    }

    /// 从任意文本（剪贴板可能含其它内容）里提取口令。
    static func find(in text: String) -> PostcardPayload? {
        guard let r = text.range(of: prefix) else { return nil }
        let tail = text[r.lowerBound...]
        let tokenStr = tail.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" }).first.map(String.init)
            ?? String(tail)
        return decode(tokenStr)
    }

    /// 把口令生成二维码图。
    static func qrImage(_ string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        guard let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
