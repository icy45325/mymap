import SwiftUI
import UIKit
import WidgetKit

/// 统一主题（Plus 权益）：**一套配置**同时驱动 全局高亮色（Tokens 四强调槽位）、
/// 地图配色、进度渐变 与 **配套 App 图标**。霓虹默认免费；极光 / 暖阳属 Plus。
///
/// 机制：`Color.nPink` 等令牌改为读 `ThemeCache` 静态缓存；切主题时
/// `ThemeStore.refresh()` 先写缓存再发布 → `LumiApp` 对根视图 `.id(applied)` 整树重建
/// （低频操作，可接受）。非 Plus 恒回落霓虹。
enum AppTheme: String, CaseIterable, Identifiable {
    case neon, aurora, sunset

    var id: String { rawValue }
    static let storageKey = "lumi.theme"

    var label: LocalizedStringKey {
        switch self {
        case .neon:   return "霓虹"
        case .aurora: return "极光"
        case .sunset: return "暖阳"
        }
    }
    var isFree: Bool { self == .neon }

    /// 配套 App 图标（asset catalog alternate icon；nil = 默认主图标）。
    var iconName: String? {
        switch self {
        case .neon:   return nil
        case .aurora: return "AppIcon-Aurora"
        case .sunset: return "AppIcon-Mono"
        }
    }
    /// 个性化页图标缩略图资源。
    var iconPreview: String {
        switch self {
        case .neon:   return "iconprev_classic"
        case .aurora: return "iconprev_aurora"
        case .sunset: return "iconprev_mono"
        }
    }

    // MARK: - 全局强调色（对应 Tokens 的 nPink / nPurple / nOrange / nCyan 槽位）

    struct Accents {
        let primary: Color    // 签名色（点亮 / 主强调，原 nPink 位）
        let secondary: Color  // 次强调（原 nPurple 位）
        let warm: Color       // 渐变高光（原 nOrange 位）
        let cool: Color       // 冷强调（心愿 / 链接，原 nCyan 位）
    }

    var accents: Accents {
        switch self {
        case .neon:
            return Accents(primary: Color(hex: 0xFF3D9A), secondary: Color(hex: 0x9B5DE5),
                           warm: Color(hex: 0xFF9A45), cool: Color(hex: 0x4DD9FF))
        case .aurora:
            return Accents(primary: Color(hex: 0x22D3A5), secondary: Color(hex: 0x38BDF8),
                           warm: Color(hex: 0x8FF2C2), cool: Color(hex: 0x4DD9FF))
        case .sunset:
            return Accents(primary: Color(hex: 0xFF9A45), secondary: Color(hex: 0xFF5E62),
                           warm: Color(hex: 0xFFD166), cool: Color(hex: 0x64D2FF))
        }
    }

    // MARK: - 地图色板（点阵地球 + 真实地图）

    struct Palette {
        let glow: Color
        let pinTop: Color, pinBottom: Color
        let dotNear: Color, dotMid: Color, dotFar: Color, dotBase: Color
        let litFill: Color, litStroke: Color
    }

    var palette: Palette {
        switch self {
        case .neon:
            return Palette(glow: Color(hex: 0x9B5DE5),
                           pinTop: Color(hex: 0xFF3D9A), pinBottom: Color(hex: 0xFF9A45),
                           dotNear: Color(hex: 0xE59BF0), dotMid: Color(hex: 0xB07FE0),
                           dotFar: Color(hex: 0x6E5FA0), dotBase: Color(hex: 0x46466A),
                           litFill: Color(hex: 0x9B5DE5), litStroke: Color(hex: 0xFF3D9A))
        case .aurora:
            return Palette(glow: Color(hex: 0x14B8A6),
                           pinTop: Color(hex: 0x22D3A5), pinBottom: Color(hex: 0x38BDF8),
                           dotNear: Color(hex: 0x9BF2E0), dotMid: Color(hex: 0x3ECFBF),
                           dotFar: Color(hex: 0x2A7E85), dotBase: Color(hex: 0x35506A),
                           litFill: Color(hex: 0x14B8A6), litStroke: Color(hex: 0x22D3A5))
        case .sunset:
            return Palette(glow: Color(hex: 0xFF9A45),
                           pinTop: Color(hex: 0xFF9A45), pinBottom: Color(hex: 0xFF5E62),
                           dotNear: Color(hex: 0xFFD9A0), dotMid: Color(hex: 0xF5A25D),
                           dotFar: Color(hex: 0x9A6A50), dotBase: Color(hex: 0x584A50),
                           litFill: Color(hex: 0xFF9A45), litStroke: Color(hex: 0xFFB84D))
        }
    }

    // MARK: - 当前生效

    /// 当前生效主题（由 ThemeStore 维护；令牌与地图都从这里读）。
    static var applied: AppTheme { ThemeCache.applied }

    /// 存储里的选择（未经 Plus 校验）。
    static var stored: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .neon
    }
}

/// 令牌静态缓存：`Color.nPink` 等每次访问都读这里，避免每次查 UserDefaults。
/// 只由 `ThemeStore.refresh()` 写入（主线程）。
enum ThemeCache {
    static private(set) var applied: AppTheme = .neon
    static private(set) var primary   = AppTheme.neon.accents.primary
    static private(set) var secondary = AppTheme.neon.accents.secondary
    static private(set) var warm      = AppTheme.neon.accents.warm
    static private(set) var cool      = AppTheme.neon.accents.cool

    static func apply(_ theme: AppTheme) {
        applied = theme
        let a = theme.accents
        primary = a.primary; secondary = a.secondary; warm = a.warm; cool = a.cool
    }
}

/// 主题状态机：对齐 存储选择 × Plus 权益 → 生效主题；发布变更供根视图整树重建；
/// 同步 App Group（小组件跟色 + Plus 门控标志）并刷新小组件。
@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var applied: AppTheme = .neon

    private init() {
        // 启动先按存储乐观应用（Plus 校验在 refreshEntitlement 完成后跟进对齐）。
        ThemeCache.apply(AppTheme.stored)
        applied = AppTheme.stored
    }

    /// 对齐生效主题（存储选择 × Plus）。`PlusStore.refreshEntitlement()` 与主题切换都走这里。
    func refresh(isPlus: Bool) {
        let target = isPlus ? AppTheme.stored : .neon
        ThemeCache.apply(target)
        if applied != target { applied = target }
        syncAppGroup(isPlus: isPlus, theme: target)
    }

    /// 用户选择主题（调用方已确保 Plus）：存储 + 生效 + 配套换 App 图标。
    func select(_ theme: AppTheme, isPlus: Bool) {
        UserDefaults.standard.set(theme.rawValue, forKey: AppTheme.storageKey)
        refresh(isPlus: isPlus)
        UIApplication.shared.setAlternateIconName(theme.iconName)   // 图标随主题（系统弹一次确认）
    }

    /// 把 Plus 标志与主题写进 App Group（小组件端读取），并刷新小组件时间线。
    private func syncAppGroup(isPlus: Bool, theme: AppTheme) {
        let d = UserDefaults(suiteName: LumiAppGroup.id)
        d?.set(isPlus, forKey: LumiAppGroup.plusKey)
        d?.set(theme.rawValue, forKey: LumiAppGroup.themeKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
