import Foundation

// MARK: - App Groups 共享容器统一入口

public enum SharedStore {
    /// Must match the App Groups entitlement for the app, widget, and watch targets.
    public static let groupID = "group.com.eavic.test"

    public static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.temporaryDirectory   // 单元测试兜底
    }

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: PetState 持久化

    private static let stateKey = "petState.v1"
    private static let stateURL: URL =
        containerURL.appendingPathComponent("petState.json")

    public static func loadState() -> PetState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PetState.self, from: data) else {
            return PetState()
        }
        return state
    }

    public static func saveState(_ state: PetState) {
        var s = state
        s.lastUpdate = Date()
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: stateURL, options: .atomic)
        defaults.set(Date().timeIntervalSince1970, forKey: "lastSaveTimestamp")
    }

    // MARK: 形象帧图

    public static var avatarsDir: URL {
        let url = containerURL.appendingPathComponent("Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
