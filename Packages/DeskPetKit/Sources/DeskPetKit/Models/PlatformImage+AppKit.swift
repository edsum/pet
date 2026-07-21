#if canImport(AppKit)
import Foundation
import AppKit

public extension PlatformImage {
    /// 跨平台 PNG 编码（NSImage → TIFF → PNG）
    var pngDataCompat: Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
    }
}
#endif
