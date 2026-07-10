import Foundation
import UIKit

/// 交换日记口令载荷：整本日记（文字 + 心情）一次性随口令交换。
/// 照片不随口令传（体积会击穿二维码，且带外版的仪式核心是文字互换）。
struct DiaryPayload: Codable {
    var v: Int = 1
    let token: String            // 幂等标识（封存时生成一次，固化在 ExchangeDiary.sealToken）
    let pairID: String           // 配对码：对方寄回时凭它自动对上发起方的日记本
    let diaryID: String          // 寄件方日记 id（自收自发检测）
    let title: String
    let sender: String?          // 寄件人昵称
    let senderBox: String?       // 寄件人 Lumi 邮箱号（收件方回寄用）
    let sealedAt: Date
    let entries: [Entry]

    struct Entry: Codable {
        let d: Date              // 条目日期
        let t: String            // 正文
        var m: String? = nil     // 心情 emoji
    }
}

extension DiaryPayload: Identifiable {
    var id: String { token }    // sheet(item:) 用；token 本就全局唯一
}

/// 交换日记口令编解码。与明信片 `LUMI1:` 平行的新前缀——旧版 App 对 `LUMID1:` 视而不见，
/// 干净向后兼容；四条收件入口的分流在 `PostcardInbox` 内完成。
enum DiaryToken {
    static let prefix = "LUMID1:"

    static func encode(diary: ExchangeDiary, token: String, sender: String?, senderBox: String?) -> String {
        let items = diary.entries
            .sorted { $0.date < $1.date }
            .map { DiaryPayload.Entry(d: $0.date, t: $0.text, m: $0.mood) }
        let p = DiaryPayload(token: token, pairID: diary.pairID, diaryID: diary.id.uuidString,
                             title: diary.title, sender: sender, senderBox: senderBox,
                             sealedAt: diary.sealedAt ?? .now, entries: items)
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return prefix + data.base64EncodedString()
    }

    /// 把解码后的载荷还原成口令字符串（收件落壳存 `partnerToken` 用；token 原样保留）。
    static func reencode(_ p: DiaryPayload) -> String {
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return prefix + data.base64EncodedString()
    }

    static func decode(_ raw: String) -> DiaryPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix(prefix),
              let data = Data(base64Encoded: String(s.dropFirst(prefix.count)))
        else { return nil }
        return try? JSONDecoder().decode(DiaryPayload.self, from: data)
    }

    /// 从任意文本里提取日记口令：兼容裸口令 `LUMID1:…` 与链接 `lumi://diary?t=…`。
    static func find(in text: String) -> DiaryPayload? {
        func firstWord(from i: Substring.Index, of s: String) -> String {
            let tail = s[i...]
            return tail.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" }).first.map(String.init)
                ?? String(tail)
        }
        if let r = text.range(of: "lumi://diary"), let url = URL(string: firstWord(from: r.lowerBound, of: text)) {
            return payload(from: url)
        }
        if let r = text.range(of: prefix) {
            return decode(firstWord(from: r.lowerBound, of: text))
        }
        return nil
    }

    /// 可点链接 / 二维码用：`lumi://diary?t=<口令>`。
    static func shareURL(_ tokenString: String) -> URL? {
        var c = URLComponents()
        c.scheme = "lumi"; c.host = "diary"
        c.queryItems = [URLQueryItem(name: "t", value: tokenString)]
        return c.url
    }

    /// 从 URL 取载荷：`lumi://diary?t=…` 或 AirDrop 来的 `.lumicard` 文件（内容按前缀分流）。
    static func payload(from url: URL) -> DiaryPayload? {
        if url.isFileURL {
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return find(in: s)
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           comps.scheme == "lumi", comps.host == "diary",
           let t = comps.queryItems?.first(where: { $0.name == "t" })?.value {
            return decode(t)
        }
        return nil
    }

    /// 写一个 `.lumicard` 临时文件用于 AirDrop / 分享（复用明信片的 UTI 关联，零 Info.plist 改动）。
    static func writeDiaryFile(_ tokenString: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lumi 交换日记.lumicard")
        do { try Data(tokenString.utf8).write(to: url); return url } catch { return nil }
    }

    /// 二维码容量硬上限（version 40 · M 级 ≈ 2953 字节）之下的安全阈值：超过则寄出面板隐藏 QR 入口。
    static let qrLimit = 2800
}
