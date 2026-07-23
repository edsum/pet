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

    // MARK: 设备状态（App 写入，Widget / Live Activity 补偿读取）

    private static let batteryPercentKey = "deviceStatus.batteryPercent"
    private static let isChargingKey = "deviceStatus.isCharging"
    private static let deviceStatusUpdatedAtKey = "deviceStatus.updatedAt"

    public static func loadDeviceStatus() -> DeviceStatus {
        let percent = defaults.object(forKey: batteryPercentKey) as? Int
        let timestamp = defaults.double(forKey: deviceStatusUpdatedAtKey)
        return DeviceStatus(
            batteryPercent: percent,
            isCharging: defaults.bool(forKey: isChargingKey),
            updatedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        )
    }

    public static func saveDeviceStatus(batteryLevel: Double?, isCharging: Bool) {
        if let batteryLevel {
            let percent = min(100, max(0, Int((batteryLevel * 100).rounded())))
            defaults.set(percent, forKey: batteryPercentKey)
        }
        defaults.set(isCharging, forKey: isChargingKey)
        defaults.set(Date().timeIntervalSince1970, forKey: deviceStatusUpdatedAtKey)
    }

    // MARK: 形象帧图

    public static var avatarsDir: URL {
        let url = containerURL.appendingPathComponent("Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

public struct DeviceStatus: Equatable, Sendable {
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var updatedAt: Date?

    public init(
        batteryPercent: Int? = nil,
        isCharging: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.updatedAt = updatedAt
    }
}

// MARK: - 小组件显示设置

public enum WidgetDisplaySettings {
    public static let showStepsKey = "widgetDisplay.showSteps"
    public static let showWeatherKey = "widgetDisplay.showWeather"

    public static var showSteps: Bool {
        SharedStore.defaults.bool(forKey: showStepsKey)
    }

    public static var showWeather: Bool {
        SharedStore.defaults.bool(forKey: showWeatherKey)
    }
}
