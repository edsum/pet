import SwiftUI
import DeskPetKit

/// SwiftUI 视图的 macOS 适配
/// 集中处理"在 Mac 上不需要"或"Mac 上需要不同布局"的部分
struct MacAdaptations {

    /// Mac 下隐藏某些 iOS 控件
    static func shouldShowStatusBar() -> Bool {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return false
        #else
        return true
        #endif
    }

    /// Mac 下默认窗口大小
    static var defaultWindowSize: CGSize? {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return CGSize(width: 720, height: 900)
        #else
        return nil
        #endif
    }
}
