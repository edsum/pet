import Foundation

// MARK: - 系统事件类型

public enum PetEvent: Sendable {
    case chargingStarted
    case chargingStopped
    case batteryLow            // <= 20%
    case lowPowerModeChanged(Bool)
    case audioRouteChanged      // 耳机/蓝牙
    case enterForeground
    case enterBackground
    case nightfall
    case morning
    case stepGoalReached        // HealthKit 步数达标
    case calendarBusy           // 日程进行中

    /// 直接来自用户的互动
    case userFed(Food)
    case userPetted
    case userPlayed(game: Minigame, score: Int)
    case userBathed
}

public enum Food: String, CaseIterable, Sendable {
    case fish, meat, vegetable, snack, fruit

    public var hungerBoost: Int {
        switch self {
        case .fish, .meat: 30
        case .vegetable, .fruit: 20
        case .snack: 15
        }
    }
    public var happinessBoost: Int {
        self == .snack ? 8 : 3
    }
    public var price: Int {
        self == .meat ? 8 : (self == .snack ? 3 : 5)
    }
}

public enum Minigame: String, CaseIterable, Sendable {
    case catchBall      // 接球
    case bathing        // 洗澡
    case petting        // 抚摸节奏
}
