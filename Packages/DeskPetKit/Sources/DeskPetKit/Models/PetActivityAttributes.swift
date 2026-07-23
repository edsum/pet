import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Live Activity 的"静态"部分（活动开始后不变）
public struct PetActivityAttributes: Codable, Hashable, Sendable {

    /// 宠物名字（活动开始时确定，期间不变）
    public var petName: String

    /// 活动类型（决定图标、文案、动画）
    public var kind: Kind

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case status          // 锁屏状态卡片
        case charging        // 充电进食中
        case bathing         // 洗澡中
        case sleeping        // 睡觉中
        case stepGoal        // 步数达标庆祝
        case expedition      // 家园探险

        public var icon: String {
            switch self {
            case .status:   return "pawprint.circle.fill"
            case .charging: return "bolt.circle.fill"
            case .bathing:  return "drop.fill"
            case .sleeping: return "moon.zzz.fill"
            case .stepGoal: return "figure.walk"
            case .expedition: return "map.fill"
            }
        }

        public var verb: String {
            switch self {
            case .status: return "桌宠状态"
            case .charging: return "充电进食中"
            case .bathing:  return "洗澡中"
            case .sleeping: return "睡觉中"
            case .stepGoal: return "今日步数达标"
            case .expedition: return "家园探险中"
            }
        }
    }

    public init(petName: String, kind: Kind) {
        self.petName = petName; self.kind = kind
    }
}

#if canImport(ActivityKit)
extension PetActivityAttributes: ActivityAttributes {

    /// 动态部分（活动期间会更新）
    public struct ContentState: Codable, Hashable, Sendable {
        public var mood: String           // PetMood.rawValue
        public var progress: Double       // 0~1
        public var subtitle: String       // 一句话副标题
        public var detail: String         // 详细信息（如"⚡️ 87%")
        public var steps: Int?            // 今日步数
        public var weather: String?       // 天气概况
        public var batteryPercent: Int?   // 电量百分比
        public var isCharging: Bool       // 是否正在充电
        public var updatedAt: Date?       // 最近一次状态更新时间
        public var petID: UUID?           // 当前宠物 id（切换宠物时更新）
        public var petName: String?       // 当前宠物名（attributes 固定后的动态补偿）
        public var showSteps: Bool        // 是否在小组件显示步数
        public var showWeather: Bool      // 是否在小组件显示天气

        public init(
            mood: String,
            progress: Double,
            subtitle: String,
            detail: String = "",
            steps: Int? = nil,
            weather: String? = nil,
            batteryPercent: Int? = nil,
            isCharging: Bool = false,
            updatedAt: Date? = nil,
            petID: UUID? = nil,
            petName: String? = nil,
            showSteps: Bool = false,
            showWeather: Bool = false
        ) {
            self.mood = mood; self.progress = progress
            self.subtitle = subtitle; self.detail = detail
            self.steps = steps; self.weather = weather
            self.batteryPercent = batteryPercent; self.isCharging = isCharging
            self.updatedAt = updatedAt
            self.petID = petID; self.petName = petName
            self.showSteps = showSteps; self.showWeather = showWeather
        }
    }
}
#endif
