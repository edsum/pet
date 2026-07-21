import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 形象帧图读写（PNG 文件）

public enum AssetStore {

    public static func avatarDir(for petID: UUID) -> URL {
        let dir = SharedStore.avatarsDir
            .appendingPathComponent(petID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 保存某个 mood 的帧图
    public static func save(frame image: PlatformImage, mood: PetMood, petID: UUID) throws {
        guard let data = image.pngDataCompat else { return }
        let url = avatarDir(for: petID).appendingPathComponent("\(mood.assetName).png")
        try data.write(to: url, options: .atomic)
    }

    public static func loadFrame(mood: PetMood, petID: UUID) -> PlatformImage? {
        let url = avatarDir(for: petID).appendingPathComponent("\(mood.assetName).png")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return PlatformImage(contentsOfFile: url.path)
    }

    /// 删除某只宠物的所有形象
    public static func deleteAll(petID: UUID) {
        try? FileManager.default.removeItem(at: avatarDir(for: petID))
    }
}
