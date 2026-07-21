import Foundation

/// 单条事件记录：用于统计图表
public struct PetEventLogEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let petID: UUID
    public let timestamp: Date
    public let kind: Kind
    public let detail: String        // 人类可读描述

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case fed            // 喂食
        case played         // 小游戏
        case bathed         // 洗澡
        case petted         // 摸头
        case leveledUp      // 升级
        case charging       // 充电进食
        case stepGoal       // 步数达标
        case sick           // 病了
        case revived        // 数值恢复

        public var icon: String {
            switch self {
            case .fed:        return "fork.knife"
            case .played:     return "gamecontroller.fill"
            case .bathed:     return "drop.fill"
            case .petted:     return "hand.draw.fill"
            case .leveledUp:  return "star.fill"
            case .charging:   return "bolt.fill"
            case .stepGoal:   return "figure.walk"
            case .sick:       return "cross.case.fill"
            case .revived:    return "heart.fill"
            }
        }

        public var label: String {
            switch self {
            case .fed:        return "喂食"
            case .played:     return "游戏"
            case .bathed:     return "洗澡"
            case .petted:     return "摸头"
            case .leveledUp:  return "升级"
            case .charging:   return "充电"
            case .stepGoal:   return "步数达标"
            case .sick:       return "生病"
            case .revived:    return "恢复"
            }
        }
    }

    public init(petID: UUID, kind: Kind, detail: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.petID = petID
        self.kind = kind
        self.detail = detail
        self.timestamp = timestamp
    }
}
