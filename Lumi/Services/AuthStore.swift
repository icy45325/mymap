import Foundation
import AuthenticationServices

/// Sign in with Apple —— **纯客户端登录态，无后端**。
///
/// 存 Apple 的稳定用户标识（非密、每 App 唯一）+ 可选姓名（只在**首次**登录返回，已落本地）。
/// 不取邮箱（`requestedScopes` 只要 `.fullName`），保持隐私标签「Data Not Collected」。
/// 重装后 Apple 会返回同一 userID，重新登录即可恢复身份；跨设备/云端需后端（留 v1）。
@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    private let store = UserDefaults.standard
    private let kID = "lumi.auth.userID"
    private let kName = "lumi.auth.name"

    @Published private(set) var userID: String
    @Published private(set) var displayName: String

    var isLoggedIn: Bool { !userID.isEmpty }

    private init() {
        userID = store.string(forKey: kID) ?? ""
        displayName = store.string(forKey: kName) ?? ""
    }

    /// 处理 `SignInWithAppleButton` 的回调结果。
    func handle(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
        userID = cred.user
        store.set(userID, forKey: kID)
        if let n = cred.fullName {
            let full = [n.givenName, n.familyName].compactMap { $0 }.joined(separator: " ")
            if !full.isEmpty { displayName = full; store.set(full, forKey: kName) }
        }
        Haptics.success()
    }

    func signOut() {
        userID = ""; displayName = ""
        store.removeObject(forKey: kID); store.removeObject(forKey: kName)
    }

    /// 启动时校验：用户可能在系统设置撤销了授权 → 本地登出。
    func refreshCredentialState() {
        guard !userID.isEmpty else { return }
        let uid = userID
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: uid) { [weak self] state, _ in
            if state == .revoked || state == .notFound {
                Task { @MainActor in self?.signOut() }
            }
        }
    }
}
