import Foundation

/// 交换日记远程模式（App 内交换）的口令协议 `LUMID2:`——双方都在**自己的 App**里操作：
/// ① `invite`：发起者把本的元数据寄给对方 → 对方 App 生成**镜像本**（同 pairID、同页结构，视角对调）；
/// ② `halves`：一方封存的半页打包寄给对方 → 落到对方镜像本对应页的「对方半页」。
/// 传输复用明信片四通道（剪贴板口令 / 二维码 / lumi:// 链接+AirDrop / 邮局直投）；
/// pairID+邮箱号的配对也是后续好友关系的前提。
struct DiaryLinkPayload: Codable, Identifiable {
    var v: Int = 1
    let kind: String             // "invite" / "halves"
    let token: String            // 幂等标识
    let pairID: String           // 配对码（镜像本两端一致）
    let sender: String?          // 寄件人昵称
    let senderBox: String?       // 寄件人 Lumi 邮箱号
    // —— invite ——
    var title: String? = nil
    var spineHex: String? = nil
    var pages: [PageMeta]? = nil
    // —— halves ——
    var halves: [HalfPayload]? = nil

    struct PageMeta: Codable {
        let i: Int               // orderIndex
        let t: String            // titleSnapshot
        let d: Date              // dateSnapshot
    }

    struct HalfPayload: Codable {
        let i: Int               // 页 orderIndex
        var t: String? = nil     // 文字
        var draw: String? = nil  // 涂鸦 PKDrawing data base64
        var voice: String? = nil // 语音 m4a base64
        var vd: Double = 0       // 语音时长
        let sealedAt: Date
    }

    var id: String { token }
    var isInvite: Bool { kind == "invite" }
}

enum DiaryLink {
    static let prefix = "LUMID2:"
    /// 二维码容量安全阈值（超过隐藏 QR 入口，走口令/邮局）。
    static let qrLimit = 2800
    /// 邮局 payload 上限的客户端预检（服务端 400000）。
    static let mailLimit = 390_000

    // MARK: - 编码

    @MainActor
    static func encodeInvite(book: DiaryBook, sender: String?, senderBox: String?) -> String {
        let metas = book.sortedPages.map {
            DiaryLinkPayload.PageMeta(i: $0.orderIndex, t: $0.titleSnapshot, d: $0.dateSnapshot)
        }
        let p = DiaryLinkPayload(kind: "invite", token: "di-" + UUID().uuidString.prefix(10).uppercased(),
                                 pairID: book.pairID, sender: sender, senderBox: senderBox,
                                 title: book.title, spineHex: book.spineColorHex, pages: metas)
        return encode(p)
    }

    @MainActor
    static func encodeHalves(book: DiaryBook, halves: [(page: DiaryPage, half: DiaryHalf)],
                             sender: String?, senderBox: String?) -> String {
        let items = halves.map { pair in
            DiaryLinkPayload.HalfPayload(i: pair.page.orderIndex,
                                         t: pair.half.text,
                                         draw: pair.half.drawingData?.base64EncodedString(),
                                         voice: pair.half.voiceData?.base64EncodedString(),
                                         vd: pair.half.voiceDuration,
                                         sealedAt: pair.half.sealedAt ?? .now)
        }
        let p = DiaryLinkPayload(kind: "halves", token: "dh-" + UUID().uuidString.prefix(10).uppercased(),
                                 pairID: book.pairID, sender: sender, senderBox: senderBox,
                                 halves: items)
        return encode(p)
    }

    private static func encode(_ p: DiaryLinkPayload) -> String {
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return prefix + data.base64EncodedString()
    }

    // MARK: - 解码 / 提取（与 PostcardToken 同套路）

    static func decode(_ raw: String) -> DiaryLinkPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix(prefix),
              let data = Data(base64Encoded: String(s.dropFirst(prefix.count)))
        else { return nil }
        return try? JSONDecoder().decode(DiaryLinkPayload.self, from: data)
    }

    static func find(in text: String) -> DiaryLinkPayload? {
        func firstWord(from i: Substring.Index, of s: String) -> String {
            let tail = s[i...]
            return tail.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" }).first.map(String.init)
                ?? String(tail)
        }
        if let r = text.range(of: "lumi://diary2"), let url = URL(string: firstWord(from: r.lowerBound, of: text)) {
            return payload(from: url)
        }
        if let r = text.range(of: prefix) {
            return decode(firstWord(from: r.lowerBound, of: text))
        }
        return nil
    }

    static func shareURL(_ tokenString: String) -> URL? {
        var c = URLComponents()
        c.scheme = "lumi"; c.host = "diary2"
        c.queryItems = [URLQueryItem(name: "t", value: tokenString)]
        return c.url
    }

    static func payload(from url: URL) -> DiaryLinkPayload? {
        if url.isFileURL {
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return find(in: s)
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           comps.scheme == "lumi", comps.host == "diary2",
           let t = comps.queryItems?.first(where: { $0.name == "t" })?.value {
            return decode(t)
        }
        return nil
    }

    /// AirDrop 复用 `.lumicard` 扩展名（内容按前缀分流，零 Info.plist 改动）。
    static func writeFile(_ tokenString: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lumi 交换日记.lumicard")
        do { try Data(tokenString.utf8).write(to: url); return url } catch { return nil }
    }
}
