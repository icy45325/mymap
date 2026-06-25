import Foundation

extension String {
    /// 运行时按「中文源文」作 key 取当前系统语言的本地化文案；目录缺失则回退原文。
    ///
    /// 用于把**动态 / 经手参数 / 枚举返回**的中文字符串接入 String Catalog
    /// （`Text("中文字面量")` 由 SwiftUI 自动本地化，无需用本属性）。
    var localized: String { NSLocalizedString(self, comment: "") }
}
