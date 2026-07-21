import Foundation

// MARK: - 情绪枚举（决定动画与对话）

public enum PetMood: String, Codable, CaseIterable, Sendable {
    case idle, happy, excited, curious
    case hungry, sleepy, tired, sick, dirty, sad
    case eating, playing, sleeping, dancing, quiet

    /// 用于文件命名 / Asset 查找
    public var assetName: String { rawValue }

    /// 适合的呼吸动画周期（秒），睡觉/疲倦用慢周期
    public var breatheDuration: Double {
        switch self {
        case .sleeping, .tired, .sick: 3.4
        case .excited, .dancing, .playing: 0.9
        default: 1.6
        }
    }

    /// 是否是"用户在主动进行的动作"
    public var isActivity: Bool {
        switch self {
        case .eating, .playing, .dancing, .sleeping: true
        default: false
        }
    }
}

// MARK: - 装扮（帽子 / 配饰 / 围巾等）

public struct PetOutfit: Codable, Equatable, Sendable {
    public var hat: String?
    public var accessory: String?     // 如 "bow", "headphones"
    public var background: String?    // 主题场景 id

    public init(hat: String? = nil, accessory: String? = nil, background: String? = nil) {
        self.hat = hat; self.accessory = accessory; self.background = background
    }
}

// MARK: - 性格（影响对话语气）

public enum PetPersonality: String, Codable, CaseIterable, Sendable {
    case lively      // 活泼
    case calm        // 高冷
    case clingy      // 黏人
    case goofy       // 憨厚
}

// MARK: - 形象

public struct PetAppearance: Codable, Equatable, Sendable {
    public var style: Style           // 形象风格
    public var color: String          // 主色 hex
    public var outfit: PetOutfit
    public var personality: PetPersonality

    public enum Style: String, Codable, CaseIterable, Sendable {
        case clay        // 粘土
        case illustration // 插画
        case animation    // 动画
    }

    public init(style: Style = .clay,
                color: String = "#FFC078",
                outfit: PetOutfit = .init(),
                personality: PetPersonality = .lively) {
        self.style = style; self.color = color
        self.outfit = outfit; self.personality = personality
    }

    public static let `default` = PetAppearance()
}
