import AppIntents

/// 把「点亮这里」注册成系统级快捷指令，安装后即出现在「快捷指令」App
/// 与 Spotlight，并可加到锁屏 / 控制中心 / Action Button。
///
/// 约束：每条 phrase 都必须包含 `\(.applicationName)`（AppIntents 要求）。
struct LumiShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LightUpHereIntent(),
            phrases: [
                "用 \(.applicationName) 点亮这里",
                "在 \(.applicationName) 点亮这里",
                "\(.applicationName) 点亮当前位置",
            ],
            shortTitle: "点亮这里",
            systemImageName: "mappin.and.ellipse")
    }
}
