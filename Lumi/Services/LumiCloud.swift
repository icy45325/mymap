import Foundation
import SwiftData
import os.log

// ─────────────────────────────────────────────────────────────
//  LumiCloud（v1.2）：账号 + 云同步 + 邮箱认领。
//
//  · Auth：Sign in with Apple 的 identityToken 直换 Supabase GoTrue 会话
//    （POST /auth/v1/token?grant_type=id_token，零 SDK）；
//  · 同步：Footprint / Wish 两表 JSONB 全量 DTO——推送 upsert（merge-duplicates），
//    拉取按 updatedAt LWW 合并（远端新→覆盖本地；本地没有→插入；照片仅同步引用元数据，
//    receivedCoverData 随 DTO base64 保留收到卡的封面）；
//  · 认领：登录后 claim_mailbox 把 v1.1 匿名信箱绑到账号；新设备 recover_mailbox 找回；
//  · 开关：与邮局共用 LumiPostConfig（两键缺失全 no-op）；登录永远可选，不挡本地使用。
//  建表脚本：docs/design/lumi-account-schema.sql；Apple provider 需在 Supabase 控制台启用。
// ─────────────────────────────────────────────────────────────

/// GoTrue 会话（本地持久化；access_token 短期，refresh_token 换新）。
struct CloudSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userID: String
    var expiresAt: Date
}

/// Footprint 云同步 DTO（JSONB payload；字段可增不可改义）。
struct FootprintDTO: Codable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var placeName: String
    var latitude: Double
    var longitude: Double
    var cityName: String?
    var countryCode: String?
    var subRegionCode: String?
    var visitedAt: Date
    var endedAt: Date?
    var mood: String
    var companions: [String]
    var photoAssetIDs: [String]          // 本机相册标识（跨设备无图，仅保引用）
    var isReceived: Bool
    var senderName: String?
    var receivedAt: Date?
    var receivedCoverB64: String?        // 收到卡的封面（已压缩，跨设备可还原）
    var postcardStyle: String
    var stampStyle: String
    var entryMeans: String

    init(_ f: Footprint) {
        id = f.id; createdAt = f.createdAt; updatedAt = f.updatedAt
        placeName = f.placeName; latitude = f.latitude; longitude = f.longitude
        cityName = f.cityName; countryCode = f.countryCode; subRegionCode = f.subRegionCode
        visitedAt = f.visitedAt; endedAt = f.endedAt; mood = f.mood
        companions = f.companions; photoAssetIDs = f.photoAssetIDs
        isReceived = f.isReceived; senderName = f.senderName; receivedAt = f.receivedAt
        receivedCoverB64 = f.receivedCoverData?.base64EncodedString()
        postcardStyle = f.postcardStyle; stampStyle = f.stampStyle; entryMeans = f.entryMeans
    }

    /// 把远端字段写回本地实体（LWW 覆盖）。
    func apply(to f: Footprint) {
        f.updatedAt = updatedAt
        f.placeName = placeName; f.latitude = latitude; f.longitude = longitude
        f.cityName = cityName; f.countryCode = countryCode; f.subRegionCode = subRegionCode
        f.visitedAt = visitedAt; f.endedAt = endedAt; f.mood = mood
        f.companions = companions
        if !photoAssetIDs.isEmpty { f.photoAssetIDs = photoAssetIDs }   // 跨设备引用无效但不清空本机的
        f.isReceived = isReceived; f.senderName = senderName; f.receivedAt = receivedAt
        if let b64 = receivedCoverB64, f.receivedCoverData == nil {
            f.receivedCoverData = Data(base64Encoded: b64)
        }
        f.postcardStyle = postcardStyle; f.stampStyle = stampStyle; f.entryMeans = entryMeans
    }

    /// 造一条新的本地实体（拉取时本地不存在）。
    @MainActor func makeFootprint() -> Footprint {
        let f = Footprint(placeName: placeName,
                          coordinate: .init(latitude: latitude, longitude: longitude),
                          cityName: cityName, visitedAt: visitedAt, endedAt: endedAt,
                          mood: mood, companions: companions, photoAssetIDs: photoAssetIDs)
        f.id = id
        f.createdAt = createdAt
        apply(to: f)
        return f
    }
}

/// Wish 云同步 DTO。
struct WishDTO: Codable {
    var id: UUID; var createdAt: Date
    var placeName: String; var cityName: String?; var countryCode: String?
    var latitude: Double; var longitude: Double; var note: String

    init(_ w: Wish) {
        id = w.id; createdAt = w.createdAt; placeName = w.placeName; cityName = w.cityName
        countryCode = w.countryCode; latitude = w.latitude; longitude = w.longitude; note = w.note
    }
}

enum LumiCloudError: LocalizedError {
    case disabled, notSignedIn, badResponse(Int, String?)
    var errorDescription: String? {
        switch self {
        case .disabled:    return String(localized: "云同步未启用")
        case .notSignedIn: return String(localized: "请先登录")
        case .badResponse(let c, let m):
            let base = String(localized: "云同步暂时不可用（\(c)）")
            if let m, !m.isEmpty { return base + " · " + m }
            return base
        }
    }
}

/// 账号 + 同步客户端。
@MainActor
final class LumiCloud: ObservableObject {
    static let shared = LumiCloud()

    @Published private(set) var session: CloudSession?
    @Published private(set) var syncing = false
    @Published private(set) var lastSyncAt: Date?
    @Published var lastError: String?

    var isSignedIn: Bool { session != nil }

    private static let sessionKey = "lumi.cloud.session"
    private static let lastSyncKey = "lumi.cloud.lastSyncAt"
    private let log = Logger(subsystem: "com.lumi.v0", category: "cloud")

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.sessionKey),
           let s = try? JSONDecoder().decode(CloudSession.self, from: data) {
            session = s
        }
        lastSyncAt = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
    }

    // MARK: - 登录 / 登出（Apple identityToken → GoTrue 会话）

    /// 用 Sign in with Apple 的 identityToken 换 Supabase 会话；成功后自动认领邮箱 + 全量同步。
    func signIn(appleIDToken: String) async {
        guard LumiPostConfig.isEnabled else { lastError = LumiCloudError.disabled.localizedDescription; return }
        do {
            let data = try await request("auth/v1/token?grant_type=id_token", method: "POST",
                                         json: ["provider": "apple", "id_token": appleIDToken])
            try adoptSession(data)
            lastError = nil
            await claimOrRecoverMailbox()
            await syncNow(LumiStore.shared.mainContext)
        } catch {
            lastError = error.localizedDescription
            log.error("cloud sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
    }

    private func adoptSession(_ data: Data) throws {
        struct TokenResp: Decodable {
            let accessToken: String, refreshToken: String, expiresIn: Double
            let user: U; struct U: Decodable { let id: String }
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token", refreshToken = "refresh_token",
                     expiresIn = "expires_in", user
            }
        }
        let t = try JSONDecoder().decode(TokenResp.self, from: data)
        let s = CloudSession(accessToken: t.accessToken, refreshToken: t.refreshToken,
                             userID: t.user.id, expiresAt: Date().addingTimeInterval(t.expiresIn - 60))
        session = s
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Self.sessionKey) }
    }

    /// 过期前用 refresh_token 换新；失败即登出（下次手动登录）。
    private func validAccessToken() async throws -> String {
        guard let s = session else { throw LumiCloudError.notSignedIn }
        if s.expiresAt > Date() { return s.accessToken }
        let data = try await request("auth/v1/token?grant_type=refresh_token", method: "POST",
                                     json: ["refresh_token": s.refreshToken])
        do { try adoptSession(data) } catch { signOut(); throw LumiCloudError.notSignedIn }
        return session!.accessToken
    }

    // MARK: - 邮箱认领 / 找回（v1.1 匿名信箱 → 账号）

    private func claimOrRecoverMailbox() async {
        guard let token = try? await validAccessToken() else { return }
        if let identity = LumiPost.shared.identity {
            // 本机有信箱 → 绑到账号
            _ = try? await request("rest/v1/rpc/claim_mailbox", method: "POST",
                                   json: ["p_box": identity.boxID, "p_token": identity.readToken],
                                   bearer: token)
        } else {
            // 新设备 → 找回已绑定的信箱两码
            if let data = try? await request("rest/v1/rpc/recover_mailbox", method: "POST",
                                             json: [:], bearer: token) {
                struct Two: Decodable {
                    let boxId: String, readToken: String
                    enum CodingKeys: String, CodingKey { case boxId = "box_id", readToken = "read_token" }
                }
                if let two = try? JSONDecoder().decode(Two.self, from: data) {
                    LumiPost.shared.adopt(LumiMailboxIdentity(boxID: two.boxId, readToken: two.readToken))
                }
            }
        }
    }

    // MARK: - 同步（推 upsert + 拉 LWW 合并）

    /// 全量同步：先推后拉。轻量数据（数百条量级）全量往返即可，v1.3 再做增量。
    func syncNow(_ context: ModelContext) async {
        guard LumiPostConfig.isEnabled, isSignedIn, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            let token = try await validAccessToken()
            try await pushFootprints(context, token: token)
            try await pushWishes(context, token: token)
            try await pullFootprints(context, token: token)
            try await pullWishes(context, token: token)
            try? context.save()
            WidgetSync.refresh(context)
            lastSyncAt = .now
            UserDefaults.standard.set(lastSyncAt, forKey: Self.lastSyncKey)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            log.error("sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let iso = ISO8601DateFormatter()

    private func pushFootprints(_ context: ModelContext, token: String) async throws {
        let all = (try? context.fetch(FetchDescriptor<Footprint>())) ?? []
        guard !all.isEmpty else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let rows: [[String: Any]] = try all.map { f in
            let payload = try JSONSerialization.jsonObject(with: enc.encode(FootprintDTO(f)))
            return ["id": f.id.uuidString, "payload": payload,
                    "updated_at": Self.iso.string(from: f.updatedAt)]
        }
        _ = try await request("rest/v1/sync_footprints?on_conflict=id", method: "POST",
                              jsonArray: rows, bearer: token,
                              prefer: "resolution=merge-duplicates,return=minimal")
    }

    private func pushWishes(_ context: ModelContext, token: String) async throws {
        let all = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        guard !all.isEmpty else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let rows: [[String: Any]] = try all.map { w in
            let payload = try JSONSerialization.jsonObject(with: enc.encode(WishDTO(w)))
            return ["id": w.id.uuidString, "payload": payload,
                    "updated_at": Self.iso.string(from: w.createdAt)]
        }
        _ = try await request("rest/v1/sync_wishes?on_conflict=id", method: "POST",
                              jsonArray: rows, bearer: token,
                              prefer: "resolution=merge-duplicates,return=minimal")
    }

    private func pullFootprints(_ context: ModelContext, token: String) async throws {
        let data = try await request("rest/v1/sync_footprints?select=payload", method: "GET", bearer: token)
        struct Row: Decodable { let payload: FootprintDTO }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let rows = (try? dec.decode([Row].self, from: data)) ?? []
        guard !rows.isEmpty else { return }
        let locals = (try? context.fetch(FetchDescriptor<Footprint>())) ?? []
        var byID = [UUID: Footprint](); for f in locals { byID[f.id] = f }
        for row in rows {
            let dto = row.payload
            if let local = byID[dto.id] {
                if dto.updatedAt > local.updatedAt { dto.apply(to: local) }   // 远端新 → 覆盖
            } else {
                let f = dto.makeFootprint()
                context.insert(f)
                context.insert(Card(footprint: f))
            }
        }
    }

    private func pullWishes(_ context: ModelContext, token: String) async throws {
        let data = try await request("rest/v1/sync_wishes?select=payload", method: "GET", bearer: token)
        struct Row: Decodable { let payload: WishDTO }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let rows = (try? dec.decode([Row].self, from: data)) ?? []
        guard !rows.isEmpty else { return }
        let locals = (try? context.fetch(FetchDescriptor<Wish>())) ?? []
        let have = Set(locals.map(\.id))
        for row in rows where !have.contains(row.payload.id) {
            let d = row.payload
            let w = Wish(placeName: d.placeName,
                         coordinate: .init(latitude: d.latitude, longitude: d.longitude),
                         cityName: d.cityName, countryCode: d.countryCode, note: d.note)
            w.id = d.id; w.createdAt = d.createdAt
            context.insert(w)
        }
    }

    // MARK: - HTTP

    private func request(_ path: String, method: String,
                         json: [String: Any]? = nil, jsonArray: [[String: Any]]? = nil,
                         bearer: String? = nil, prefer: String? = nil) async throws -> Data {
        guard let base = LumiPostConfig.url, let key = LumiPostConfig.anonKey else {
            throw LumiCloudError.disabled
        }
        // path 可能带 query，不能用 appendingPathComponent（会转义 ?）
        guard let url = URL(string: base.absoluteString + "/" + path) else {
            throw LumiCloudError.badResponse(-1, "bad url")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json { req.httpBody = try JSONSerialization.data(withJSONObject: json) }
        if let jsonArray { req.httpBody = try JSONSerialization.data(withJSONObject: jsonArray) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw LumiCloudError.badResponse(-1, nil) }
        guard (200...299).contains(http.statusCode) else {
            struct E: Decodable { let message: String?; let msg: String?; let errorDescription: String?
                enum CodingKeys: String, CodingKey { case message, msg, errorDescription = "error_description" } }
            let e = try? JSONDecoder().decode(E.self, from: data)
            throw LumiCloudError.badResponse(http.statusCode, e?.message ?? e?.msg ?? e?.errorDescription)
        }
        return data
    }
}
