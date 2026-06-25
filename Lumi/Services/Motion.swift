import SwiftUI
import CoreMotion

/// 设备倾斜（roll/pitch，归一到 -1...1），驱动徽章全息流光。
/// deviceMotion 无需权限；不可用时数值恒为 0，由调用方的自动扫光兜底。
@MainActor
final class MotionTilt: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    private let mgr = CMMotionManager()

    func start() {
        guard mgr.isDeviceMotionAvailable, !mgr.isDeviceMotionActive else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 50.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            // 平滑 + 限幅
            let r = max(-1, min(1, m.attitude.roll / 0.8))
            let p = max(-1, min(1, m.attitude.pitch / 0.8))
            self.roll += (r - self.roll) * 0.18
            self.pitch += (p - self.pitch) * 0.18
        }
    }

    func stop() { mgr.stopDeviceMotionUpdates() }
}
