import Foundation

/// 每日签到记录
public struct CheckInRecord: Codable, Equatable, Sendable {
    public let date: Date            // 签到的日期（startOfDay）
    public let day: Int              // 第几天（1-based，连续签到的第 N 天）
    public let reward: Reward

    public struct Reward: Codable, Equatable, Sendable {
        public let coins: Int
        public let exp: Int

        public init(coins: Int, exp: Int) {
            self.coins = coins; self.exp = exp
        }
    }

    public init(date: Date, day: Int, reward: Reward) {
        self.date = date; self.day = day; self.reward = reward
    }
}

/// 签到状态机
public struct CheckInStatus: Codable, Equatable, Sendable {
    public var records: [CheckInRecord]      // 历史签到记录
    public var currentStreak: Int             // 当前连续签到天数
    public var longestStreak: Int             // 最长连续签到
    public var lastCheckInDay: Date?          // 最近一次签到日（startOfDay）

    public static let initial = CheckInStatus(records: [], currentStreak: 0,
                                              longestStreak: 0, lastCheckInDay: nil)
}

/// 签到规则：连续签到奖励递增，第 7 天大奖
public enum CheckInRules {

    /// 第 N 天（1-based）的奖励
    public static func reward(forDay day: Int) -> CheckInRecord.Reward {
        switch day {
        case 1...3:    return .init(coins: 20,  exp: 10)
        case 4...6:    return .init(coins: 40,  exp: 20)
        case 7:        return .init(coins: 100, exp: 50)    // 7 日大奖
        default:       return .init(coins: 50,  exp: 25)    // 后续保持
        }
    }

    /// 判断"今天"是否还能签到
    public static func canCheckIn(_ status: CheckInStatus, now: Date = Date()) -> Bool {
        let today = Calendar.current.startOfDay(for: now)
        return status.lastCheckInDay != today
    }

    /// 执行签到，返回新状态 + 本次奖励
    public static func checkIn(_ status: CheckInStatus, now: Date = Date())
        -> (CheckInStatus, CheckInRecord.Reward) {
        let today = Calendar.current.startOfDay(for: now)

        // 计算连续天数：如果昨天签过 → +1，否则重置为 1
        var newStreak = 1
        if let last = status.lastCheckInDay {
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
               cal.isDate(last, inSameDayAs: yesterday) || cal.isDate(last, inSameDayAs: today) {
                newStreak = status.currentStreak + 1
            }
        }

        // 连续 7 天后循环：第 8 天回到第 1 天
        let dayInCycle = ((newStreak - 1) % 7) + 1
        let reward = self.reward(forDay: dayInCycle)

        var newStatus = status
        newStatus.records.append(.init(date: today, day: dayInCycle, reward: reward))
        newStatus.currentStreak = newStreak
        newStatus.longestStreak = max(newStreak, status.longestStreak)
        newStatus.lastCheckInDay = today
        return (newStatus, reward)
    }
}
