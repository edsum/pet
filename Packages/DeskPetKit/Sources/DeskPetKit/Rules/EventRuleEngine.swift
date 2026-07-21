import Foundation

// MARK: - 运行环境快照（规则引擎的输入）

public struct Environment: Sendable {
    public var isCharging: Bool
    public var batteryLevel: Double          // 0~1
    public var isLowPowerMode: Bool
    public var hasHeadphones: Bool
    public var isNight: Bool

    public init(isCharging: Bool = false,
                batteryLevel: Double = 1,
                isLowPowerMode: Bool = false,
                hasHeadphones: Bool = false,
                isNight: Bool = false) {
        self.isCharging = isCharging
        self.batteryLevel = batteryLevel
        self.isLowPowerMode = isLowPowerMode
        self.hasHeadphones = hasHeadphones
        self.isNight = isNight
    }
}

// MARK: - 一条规则

public struct EventRule: Sendable {
    public let id: String
    public let condition: @Sendable (PetState, Environment) -> Bool
    public let apply: @Sendable (inout PetState) -> Void

    public init(id: String,
                condition: @escaping @Sendable (PetState, Environment) -> Bool,
                apply: @escaping @Sendable (inout PetState) -> Void) {
        self.id = id
        self.condition = condition
        self.apply = apply
    }
}

// MARK: - 规则引擎

public final class EventRuleEngine: @unchecked Sendable {

    public static let shared = EventRuleEngine()

    public var rules: [EventRule] = [
        // 充电 → 吃饭（边充电边进食，养成感与系统事件结合）
        EventRule(
            id: "charging-eating",
            condition: { _, env in env.isCharging },
            apply: { $0.mood = .eating }
        ),
        // 低电量 → 累
        EventRule(
            id: "low-battery-tired",
            condition: { _, env in env.batteryLevel <= 0.2 },
            apply: { $0.mood = .tired }
        ),
        // 低电量模式 → 睡觉节能
        EventRule(
            id: "low-power-sleep",
            condition: { _, env in env.isLowPowerMode },
            apply: { $0.mood = .sleeping }
        ),
        // 戴耳机 → 跳舞
        EventRule(
            id: "headphones-dance",
            condition: { _, env in env.hasHeadphones },
            apply: { $0.mood = .dancing; $0.stats.happiness = clamp($0.stats.happiness + 2) }
        ),
        // 夜晚 + 体力不足 → 睡觉
        EventRule(
            id: "night-sleep",
            condition: { state, env in env.isNight && state.stats.energy < 80 },
            apply: { $0.mood = .sleeping }
        ),
    ]

    public init() {}

    /// 把环境快照"灌"进 state，按规则顺序匹配应用
    public func apply(environment env: Environment, to state: inout PetState) {
        for rule in rules where rule.condition(state, env) {
            rule.apply(&state)
        }
    }
}

// MARK: - 用户互动事件处理（不走规则引擎，直接结算）

public extension PetState {

    mutating func apply(_ event: PetEvent) {
        switch event {
        case .chargingStarted:
            mood = .eating
            stats.happiness = clamp(stats.happiness + 3)

        case .chargingStopped:
            stats.happiness = clamp(stats.happiness + 5)
            mood = .happy

        case .batteryLow:
            mood = .tired

        case .lowPowerModeChanged(let on):
            if on { mood = .sleeping }

        case .audioRouteChanged:
            break  // 由 Environment.hasHeadphones 规则处理

        case .enterForeground:
            reconcile()                      // 进前台先结算
            totalInteractions += 1
            if stats.happiness >= 70 { mood = .happy }

        case .enterBackground:
            mood = .idle
            lastUpdate = Date()

        case .nightfall:
            if stats.energy < 80 { mood = .sleeping }

        case .morning:
            mood = .happy

        case .stepGoalReached:
            stats.happiness = clamp(stats.happiness + 10)
            coins += 15
            addExp(30)

        case .calendarBusy:
            mood = .quiet

        case .userFed(let food):
            guard coins >= food.price else { return }
            coins -= food.price
            stats.hunger = clamp(stats.hunger + food.hungerBoost)
            stats.happiness = clamp(stats.happiness + food.happinessBoost)
            mood = .eating
            addExp(5)

        case .userPetted:
            stats.happiness = clamp(stats.happiness + 8)
            stats.energy = clamp(stats.energy - 2)
            mood = .happy
            addExp(3)

        case .userPlayed(let game, let score):
            let baseExp: Int
            switch game {
            case .catchBall: baseExp = 20
            case .bathing:   baseExp = 10
            case .petting:   baseExp = 8
            }
            addExp(baseExp + score / 5)
            stats.happiness = clamp(stats.happiness + 15)
            stats.energy = clamp(stats.energy - 15)
            coins += min(30, score / 3)
            mood = .playing

        case .userBathed:
            stats.cleanliness = clamp(stats.cleanliness + 40)
            stats.happiness = clamp(stats.happiness + 5)
            coins += 5
            mood = .happy
        }
        lastUpdate = Date()
    }
}
