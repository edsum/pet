import Foundation

/// 成就定义
public struct Achievement: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let desc: String
    public let icon: String           // SF Symbol
    public let goal: Int
    public let metric: Metric
    public let reward: Reward

    public struct Reward: Codable, Equatable, Hashable, Sendable {
        public let coins: Int
        public let exp: Int
        public init(coins: Int, exp: Int) { self.coins = coins; self.exp = exp }
    }

    public enum Metric: String, Codable, CaseIterable, Sendable {
        case totalFeedings         // 累计喂食次数
        case totalGames            // 累计小游戏次数
        case totalBaths            // 累计洗澡次数
        case totalPetting          // 累计摸头次数
        case level                 // 当前等级
        case checkInDays           // 累计签到天数
        case streakDays            // 连续签到天数
        case stepGoals             // 步数达标次数
        case coinsEarned           // 累计获得金币
        case petsOwned             // 拥有宠物数量
    }

    public init(id: String, title: String, desc: String, icon: String,
                goal: Int, metric: Metric, reward: Reward) {
        self.id = id; self.title = title; self.desc = desc; self.icon = icon
        self.goal = goal; self.metric = metric; self.reward = reward
    }
}

/// 成就进度
public struct AchievementProgress: Codable, Equatable, Sendable {
    public var unlockedIDs: Set<String>      // 已解锁的成就 ID
    public var unlockedDates: [String: Date]  // 解锁时间

    public static let initial = AchievementProgress(unlockedIDs: [], unlockedDates: [:])
}

/// 内置成就库
public enum AchievementLibrary {

    public static let all: [Achievement] = [
        // 喂食相关
        .init(id: "feed_10",   title: "新手饲养员", desc: "累计喂食 10 次",
              icon: "fork.knife", goal: 10, metric: .totalFeedings, reward: .init(coins: 30, exp: 20)),
        .init(id: "feed_100",  title: "美食家", desc: "累计喂食 100 次",
              icon: "takeoutbag.and.cup.and.straw.fill", goal: 100, metric: .totalFeedings, reward: .init(coins: 100, exp: 50)),

        // 游戏相关
        .init(id: "game_10",   title: "玩家", desc: "玩 10 次小游戏",
              icon: "gamecontroller", goal: 10, metric: .totalGames, reward: .init(coins: 30, exp: 20)),
        .init(id: "game_100",  title: "游戏达人", desc: "玩 100 次小游戏",
              icon: "gamecontroller.fill", goal: 100, metric: .totalGames, reward: .init(coins: 100, exp: 50)),

        // 洗澡
        .init(id: "bath_10",   title: "香喷喷", desc: "洗 10 次澡",
              icon: "drop", goal: 10, metric: .totalBaths, reward: .init(coins: 30, exp: 20)),

        // 摸头
        .init(id: "pet_50",    title: "贴心伴侣", desc: "摸头 50 次",
              icon: "hand.draw", goal: 50, metric: .totalPetting, reward: .init(coins: 50, exp: 30)),

        // 等级
        .init(id: "level_5",   title: "小有所成", desc: "达到 Lv.5",
              icon: "star", goal: 5, metric: .level, reward: .init(coins: 50, exp: 0)),
        .init(id: "level_10",  title: "成长中", desc: "达到 Lv.10",
              icon: "star.fill", goal: 10, metric: .level, reward: .init(coins: 100, exp: 0)),
        .init(id: "level_20",  title: "高手", desc: "达到 Lv.20",
              icon: "star.circle.fill", goal: 20, metric: .level, reward: .init(coins: 200, exp: 0)),

        // 签到
        .init(id: "checkin_7",  title: "一周不间断", desc: "累计签到 7 天",
              icon: "calendar", goal: 7, metric: .checkInDays, reward: .init(coins: 50, exp: 30)),
        .init(id: "checkin_30", title: "月度常客", desc: "累计签到 30 天",
              icon: "calendar.badge.clock", goal: 30, metric: .checkInDays, reward: .init(coins: 200, exp: 100)),

        // 步数
        .init(id: "step_1",    title: "出门走走", desc: "步数达标 1 次",
              icon: "figure.walk", goal: 1, metric: .stepGoals, reward: .init(coins: 30, exp: 20)),
        .init(id: "step_30",   title: "运动健将", desc: "步数达标 30 次",
              icon: "figure.run", goal: 30, metric: .stepGoals, reward: .init(coins: 200, exp: 100)),

        // 拥有多只宠物
        .init(id: "pets_2",    title: "大家庭", desc: "拥有 2 只宠物",
              icon: "pawprint", goal: 2, metric: .petsOwned, reward: .init(coins: 50, exp: 30)),
        .init(id: "pets_5",    title: "动物园", desc: "拥有 5 只宠物",
              icon: "pawprint.fill", goal: 5, metric: .petsOwned, reward: .init(coins: 200, exp: 100)),
    ]
}

/// 成就检测器：根据统计指标检查新解锁的成就
public struct AchievementChecker {

    /// 输入当前的 metric 值，返回本次新解锁的成就
    public static func check(metrics: [Achievement.Metric: Int],
                              progress: AchievementProgress) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        for ach in AchievementLibrary.all {
            if progress.unlockedIDs.contains(ach.id) { continue }    // 已解锁
            let value = metrics[ach.metric] ?? 0
            if value >= ach.goal {
                newlyUnlocked.append(ach)
            }
        }
        return newlyUnlocked
    }

    /// 标记成已解锁
    public static func mark(unlocked achievements: [Achievement],
                              in progress: inout AchievementProgress) {
        for ach in achievements {
            progress.unlockedIDs.insert(ach.id)
            progress.unlockedDates[ach.id] = Date()
        }
    }
}
