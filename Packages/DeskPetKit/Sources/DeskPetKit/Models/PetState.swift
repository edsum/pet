import Foundation

// MARK: - 唯一数据源：PetState

public struct PetState: Codable, Equatable, Sendable, Identifiable {

    public var id: UUID { petID }
    public var petID: UUID
    public var name: String
    public var appearance: PetAppearance

    // 养成数值
    public var stats: PetStats
    public var level: Int
    public var exp: Int
    public var coins: Int

    // ★ 进化形态（M9 新增）
    public var form: PetForm

    // ★ 进化历史记录（每次进化的时间）
    public var evolutionHistory: [Date]

    // 状态机
    public var mood: PetMood
    public var lastUpdate: Date

    // 记忆
    public var createdAt: Date
    public var totalInteractions: Int
    public var streakDays: Int

    public init(petID: UUID = UUID(),
                name: String = "小毛",
                appearance: PetAppearance = .default,
                stats: PetStats = .initial,
                level: Int = 1, exp: Int = 0, coins: Int = 100,
                form: PetForm = .baby,
                evolutionHistory: [Date] = [],
                mood: PetMood = .idle,
                lastUpdate: Date = Date(),
                createdAt: Date = Date(),
                totalInteractions: Int = 0, streakDays: Int = 0) {
        self.petID = petID
        self.name = name
        self.appearance = appearance
        self.stats = stats
        self.level = level; self.exp = exp; self.coins = coins
        self.form = form
        self.evolutionHistory = evolutionHistory
        self.mood = mood; self.lastUpdate = lastUpdate
        self.createdAt = createdAt
        self.totalInteractions = totalInteractions
        self.streakDays = streakDays
    }

    public static let preview = PetState()
}

// MARK: - 升级

public extension PetState {

    /// 第 n 级升到 n+1 所需经验
    func expToNext() -> Int { level * 100 }

    /// 增加经验，处理升级 + ★ 自动检测进化
    /// 返回 true 表示本次升级触发了进化
    @discardableResult
    mutating func addExp(_ amount: Int) -> Bool {
        var evolved = false
        exp += amount
        while exp >= expToNext() {
            exp -= expToNext()
            level += 1
            coins += 30
            // ★ 检查是否触发进化
            let newForm = PetForm.form(for: level)
            if newForm != form {
                form = newForm
                evolutionHistory.append(Date())
                evolved = true
            }
        }
        return evolved
    }
}

// MARK: - 挂起时间补偿（懒结算）

public extension PetState {

    /// 把"从上次更新到 now"之间的被动变化一次性结算
    mutating func reconcile(now: Date = Date()) {
        let seconds = max(0, now.timeIntervalSince(lastUpdate))
        let hours = seconds / 3600
        guard hours > 0 else { return }

        let sleeping = isNight(now) || mood == .sleeping

        stats.energy      = clamp(stats.energy      + Int(hours * (sleeping ? 8 : -2)))
        stats.hunger      = clamp(stats.hunger      - Int(hours * 3))
        stats.happiness   = clamp(stats.happiness   - Int(hours * 2))
        stats.cleanliness = clamp(stats.cleanliness - Int(hours * 1))

        let lows = [stats.energy, stats.hunger, stats.happiness, stats.cleanliness]
                    .filter { $0 <= 10 }.count
        let healthDelta = lows > 0 ? -3 * Int(hours) : Int(hours)
        stats.health = clamp(stats.health + healthDelta)

        mood = computeMood(now: now)
        lastUpdate = now
    }

    /// 重新决策当前情绪
    mutating func computeMood(now: Date = Date()) -> PetMood {
        if stats.health <= 20 { return .sick }
        if stats.hunger <= 20 { return .hungry }
        if stats.cleanliness <= 20 { return .dirty }
        if stats.energy <= 20 { return .tired }
        if (isNight(now) && stats.energy < 80) { return .sleeping }
        if stats.happiness <= 30 { return .sad }
        if mood.isActivity { return mood }     // 用户动作不被数值打断
        return stats.happiness >= 70 ? .happy : .idle
    }
}

// MARK: - 时间工具

public func isNight(_ date: Date = Date()) -> Bool {
    let hour = Calendar.current.component(.hour, from: date)
    return hour >= 22 || hour < 7
}
