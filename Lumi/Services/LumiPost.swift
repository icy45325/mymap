import Foundation

// ─────────────────────────────────────────────────────────────
//  Lumi 邮局（v1.1 轻互动）：明信片站内直投的客户端服务层。
//
//  设计见 docs/DESIGN-v1.1-lumi-post.md。要点：
//  · Supabase Free + 零 Auth「能力密钥」模型：box_id 公开可寄、read_token 私密可读；
//  · 仅调 PostgREST RPC（URLSession 直连，无 SDK / 无 SPM 依赖）；
//  · Info.plist 未配置 LumiPostURL / LumiPostAnonKey 时整体 no-op（提审预留分支保持纯本地）。
// ─────────────────────────────────────────────────────────────

/// 后端配置：从 Info.plist 读；两键齐全才启用。
enum LumiPostConfig {
    static var url: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "LumiPostURL") as? String,
              !s.isEmpty else { return nil }
        return URL(string: s)
    }
    static var anonKey: String? {
        guard let k = Bundle.main.object(forInfoDictionaryKey: "LumiPostAnonKey") as? String,
              !k.isEmpty else { return nil }
        return k
    }
    /// 功能总开关：未配置 = 隐藏一切直投 UI、所有调用 no-op。
    static var isEnabled: Bool { url != nil && anonKey != nil }
}

/// 我的信箱两码（创建时服务端返回一次；本地持久化）。
struct LumiMailboxIdentity: Codable, Equatable {
    let boxID: String       // 邮箱号（公开，给别人寄）："LUMI-7F3K9Q"
    let readToken: String   // 读取密钥（私密，仅本机）
}

/// 收到的一封信。
struct LumiIncomingMail: Decodable {
    let id: Int64
    let fromBox: String?
    let payload: String     // LUMI1: 口令编码（复用 MVP 编解码与幂等去重）
    enum CodingKeys: String, CodingKey { case id, fromBox = "from_box", payload }
}

enum LumiPostError: LocalizedError {
    case disabled, badResponse(Int), boxNotFound, noIdentity

    var errorDescription: String? {
        switch self {
        case .disabled:          return String(localized: "站内直投未启用")
        case .badResponse(let c): return String(localized: "邮局暂时不可用（\(c)）")
        case .boxNotFound:       return String(localized: "没有找到这个 Lumi 邮箱号")
        case .noIdentity:        return String(localized: "邮箱还没开通")
        }
    }
}

/// Lumi 邮局客户端：开箱 / 寄信 / 收信 / 回执。
@MainActor
final class LumiPost: ObservableObject {
    static let shared = LumiPost()

    /// 我的信箱（nil = 未开通）。
    @Published private(set) var identity: LumiMailboxIdentity?

    private static let identityKey = "lumi.post.identity"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.identityKey),
           let id = try? JSONDecoder().decode(LumiMailboxIdentity.self, from: data) {
            identity = id
        }
    }

    /// 确保有信箱：没有则向服务端申请（幂等；未启用时静默返回 nil）。
    @discardableResult
    func ensureMailbox() async -> LumiMailboxIdentity? {
        guard LumiPostConfig.isEnabled else { return nil }
        if let identity { return identity }
        do {
            let data = try await rpc("create_mailbox", body: [:])
            struct Created: Decodable {
                let boxId: String, readToken: String
                enum CodingKeys: String, CodingKey { case boxId = "box_id", readToken = "read_token" }
            }
            let c = try JSONDecoder().decode(Created.self, from: data)
            let id = LumiMailboxIdentity(boxID: c.boxId, readToken: c.readToken)
            persist(id)
            return id
        } catch {
            return nil   // 开箱失败不打扰（下次再试）
        }
    }

    /// 直寄一张明信片到对方邮箱号。`payload` 为现有口令编码（PostcardToken.encode 产物）。
    func send(payload: String, to boxID: String) async throws {
        guard LumiPostConfig.isEnabled else { throw LumiPostError.disabled }
        let from = identity?.boxID
        _ = try await rpc("send_mail", body: [
            "p_to": normalize(boxID),
            "p_from": from as Any,
            "p_payload": payload,
        ])
    }

    /// 拉取收件箱新信（服务端顺手置 delivered）；逐封交给 `PostcardInbox` 走既有入库/幂等流程。
    /// 返回本次拉到的封数。
    @discardableResult
    func refreshInbox() async -> Int {
        guard LumiPostConfig.isEnabled, let identity else { return 0 }
        do {
            let data = try await rpc("fetch_mail", body: [
                "p_box": identity.boxID, "p_token": identity.readToken,
            ])
            let mails = (try? JSONDecoder().decode([LumiIncomingMail].self, from: data)) ?? []
            for m in mails { PostcardInbox.shared.handle(text: m.payload) }
            return mails.count
        } catch { return 0 }
    }

    /// 查询自己寄出信件的送达状态（足迹详情「已送达 ✓」用）。
    func checkDelivered(ids: [Int64]) async -> Set<Int64> {
        guard LumiPostConfig.isEnabled, let identity, !ids.isEmpty else { return [] }
        do {
            let data = try await rpc("check_delivered", body: [
                "p_box": identity.boxID, "p_token": identity.readToken, "p_ids": ids,
            ])
            let done = (try? JSONDecoder().decode([Int64].self, from: data)) ?? []
            return Set(done)
        } catch { return [] }
    }

    // MARK: - 内部

    /// 邮箱号归一化：容忍用户少打前缀 / 小写 / 混入空格连字符差异。
    private func normalize(_ raw: String) -> String {
        var s = raw.uppercased().replacingOccurrences(of: " ", with: "")
        if !s.hasPrefix("LUMI-") { s = "LUMI-" + s.replacingOccurrences(of: "LUMI", with: "") }
        return s
    }

    private func persist(_ id: LumiMailboxIdentity) {
        identity = id
        if let data = try? JSONEncoder().encode(id) {
            UserDefaults.standard.set(data, forKey: Self.identityKey)
        }
    }

    /// 调 Supabase PostgREST RPC：POST /rest/v1/rpc/<name>。
    private func rpc(_ name: String, body: [String: Any]) async throws -> Data {
        guard let base = LumiPostConfig.url, let key = LumiPostConfig.anonKey else {
            throw LumiPostError.disabled
        }
        var req = URLRequest(url: base.appendingPathComponent("rest/v1/rpc/\(name)"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw LumiPostError.badResponse(-1) }
        switch http.statusCode {
        case 200...299: return data
        case 404:       throw LumiPostError.boxNotFound
        default:        throw LumiPostError.badResponse(http.statusCode)
        }
    }
}
