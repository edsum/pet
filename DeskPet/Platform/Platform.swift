import SwiftUI

/// 平台适配工具：同一份 SwiftUI 代码在 iOS / macOS 下行为不同
///
/// Mac Catalyst 把 iOS App 直接搬到 macOS，本文件集中处理"Mac 特性"
enum Platform {

    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    /// Mac Catalyst 下：是否在 MenuBar 模式
    static var supportsMenuBar: Bool { isMac }

    /// Mac Catalyst 下默认窗口尺寸
    static var defaultMacWindowSize: CGSize {
        CGSize(width: 720, height: 900)
    }
}
