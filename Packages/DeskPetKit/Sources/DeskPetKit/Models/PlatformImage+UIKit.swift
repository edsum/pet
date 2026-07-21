import Foundation

#if canImport(UIKit)
import UIKit

public extension PlatformImage {
    /// 跨平台 PNG 编码
    var pngDataCompat: Data? { self.pngData() }
}
#endif
