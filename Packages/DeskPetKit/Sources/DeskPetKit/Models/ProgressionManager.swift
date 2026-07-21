import Foundation

/// 持久化签到 / 成就 / 已购商品 的总体进度
public struct GameProgress: Codable, Equatable, Sendable {
    public var checkIn: CheckInStatus
    public var achievements: AchievementProgress
    public var owned: OwnedItems
    public var totalCoinsEarned: Int          // 累计获得金币（成就用）
    public var stepGoalsCount: Int            // 步数达标次数（成就用）

    public static let initial = GameProgress(
        checkIn: .initial,
        achievements: .initial,
        owned: .initial,
        totalCoinsEarned: 0,
        stepGoalsCount: 0
    )
}

/// 进度管理：所有"养成外围系统"的入口
@MainActor
public final class ProgressionManager: ObservableObject {

    @Published public private(set) var progress: GameProgress

    public init() {
        self.progress = ProgressionStore.load()
    }

    // MARK: 签到

    /// 今天能否签到
    public var canCheckInToday: Bool {
        CheckInRules.canCheckIn(progress.checkIn)
    }

    /// 执行签到，返回本次奖励
    @discardableResult
    public func checkIn() -> CheckInRecord.Reward {
        let (newStatus, reward) = CheckInRules.checkIn(progress.checkIn)
        progress.checkIn = newStatus
        addCoins(reward.coins, exp: reward.exp)
        Logger.app.info("Check-in day \(newStatus.currentStreak): +\(reward.coins) coins")
        save()
        return reward
    }

    // MARK: 成就

    /// 计算 metric 字典（从事件日志聚合）
    public func currentMetrics(petLevel: Int,
                                petCount: Int,
                                eventLog: [PetEventLogEntry]) -> [Achievement.Metric: Int] {
        var metrics: [Achievement.Metric: Int] = [:]
        for e in eventLog {
            switch e.kind {
            case .fed:       metrics[.totalFeedings, default: 0] += 1
            case .played:    metrics[.totalGames, default: 0] += 1
            case .bathed:    metrics[.totalBaths, default: 0] += 1
            case .petted:    metrics[.totalPetting, default: 0] += 1
            case .stepGoal:  metrics[.stepGoals, default: 0] += 1
            default: break
            }
        }
        metrics[.level]       = petLevel
        metrics[.petsOwned]   = petCount
        metrics[.checkInDays] = progress.checkIn.records.count
        metrics[.streakDays]  = progress.checkIn.currentStreak
        metrics[.coinsEarned] = progress.totalCoinsEarned
        return metrics
    }

    /// 检查新成就，返回本次新解锁的列表
    @discardableResult
    public func checkAchievements(metrics: [Achievement.Metric: Int]) -> [Achievement] {
        let newly = AchievementChecker.check(metrics: metrics, progress: progress.achievements)
        guard !newly.isEmpty else { return [] }
        AchievementChecker.mark(unlocked: newly, in: &progress.achievements)
        for ach in newly {
            addCoins(ach.reward.coins, exp: ach.reward.exp)
        }
        save()
        return newly
    }

    // MARK: 商店

    /// 购买商品，返回是否成功
    @discardableResult
    public func buy(_ item: ShopItem, pet: inout PetState) -> Bool {
        guard pet.level >= item.requiredLevel else {
            Logger.app.warn("Shop: level too low for \(item.id)")
            return false
        }
        guard pet.coins >= item.price else {
            Logger.app.warn("Shop: not enough coins for \(item.id)")
            return false
        }
        pet.coins -= item.price

        // 应用效果
        switch item.effect {
        case .feed(let hunger, let happiness):
            pet.stats.hunger = clamp(pet.stats.hunger + hunger)
            pet.stats.happiness = clamp(pet.stats.happiness + happiness)
        case .outfit(let hat, let accessory):
            if let hat { pet.appearance.outfit.hat = hat }
            if let accessory { pet.appearance.outfit.accessory = accessory }
            progress.owned.outfits.insert(item.id)
        case .background(let id):
            pet.appearance.outfit.background = id
            progress.owned.backgrounds.insert(id)
        case .heal(let amount):
            pet.stats.health = clamp(pet.stats.health + amount)
        case .energyBoost(let amount):
            pet.stats.energy = clamp(pet.stats.energy + amount)
        }
        Logger.app.info("Shop: bought \(item.id)")
        save()
        return true
    }

    /// 是否已购买（装扮/背景类）
    public func isOwned(_ item: ShopItem) -> Bool {
        switch item.category {
        case .outfit:     return progress.owned.outfits.contains(item.id)
        case .background: return progress.owned.backgrounds.contains(item.id)
        default:          return false
        }
    }

    // MARK: 累计金币（成就用）

    public func addCoins(_ amount: Int, exp: Int = 0) {
        progress.totalCoinsEarned += max(0, amount)
    }

    public func noteStepGoalReached() {
        progress.stepGoalsCount += 1
        save()
    }

    // MARK: 持久化

    public func save() {
        ProgressionStore.save(progress)
    }
}

/// GameProgress 文件存储
public enum ProgressionStore {

    private static var url: URL {
        SharedStore.containerURL.appendingPathComponent("gameProgress.json")
    }

    public static func load() -> GameProgress {
        guard let data = try? Data(contentsOf: url),
              let progress = try? JSONDecoder().decode(GameProgress.self, from: data) else {
            return .initial
        }
        return progress
    }

    public static func save(_ progress: GameProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
