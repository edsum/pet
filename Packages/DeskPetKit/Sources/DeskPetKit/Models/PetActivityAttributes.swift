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
        case charging        // 充电进食中
        case bathing         // 洗澡中
        case sleeping        // 睡觉中
        case stepGoal        // 步数达标庆祝

        public var icon: String {
            switch self {
            case .charging: return "bolt.circle.fill"
            case .bathing:  return "drop.fill"
            case .sleeping: return "moon.zzz.fill"
            case .stepGoal: return "figure.walk"
            }
        }

        public var verb: String {
            switch self {
            case .charging: return "充电进食中"
            case .bathing:  return "洗澡中"
            case .sleeping: return "睡觉中"
            case .stepGoal: return "今日步数达标"
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

        public init(mood: String, progress: Double, subtitle: String, detail: String = "") {
            self.mood = mood; self.progress = progress
            self.subtitle = subtitle; self.detail = detail
        }
    }
}
#endif
