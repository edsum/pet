import Foundation

/// 统计数据：从事件日志聚合
public struct PetStatsSummary {
    public let totalInteractions: Int
    public let totalFeedings: Int
    public let totalGames: Int
    public let totalBaths: Int
    public let totalPetting: Int
    public let totalLevelUps: Int
    public let byDay: [Date: Int]            // 每天交互数
    public let byKind: [PetEventLogEntry.Kind: Int]   // 按类型分组
    public let currentStreak: Int             // 连续互动天数
    public let longestStreak: Int
}

public enum StatsAggregator {

    /// 从事件日志聚合指定宠物的统计
    public static func summarize(entries: [PetEventLogEntry],
                                  for petID: UUID,
                                  days: Int = 30) -> PetStatsSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let petEntries = entries
            .filter { $0.petID == petID && $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        var byKind: [PetEventLogEntry.Kind: Int] = [:]
        var byDay: [Date: Int] = [:]
        let cal = Calendar.current

        for e in petEntries {
            byKind[e.kind, default: 0] += 1
            let dayStart = cal.startOfDay(for: e.timestamp)
            byDay[dayStart, default: 0] += 1
        }

        // 计算连续天数
        let (current, longest) = computeStreak(entries: petEntries)

        return PetStatsSummary(
            totalInteractions: petEntries.count,
            totalFeedings: byKind[.fed] ?? 0,
            totalGames: byKind[.played] ?? 0,
            totalBaths: byKind[.bathed] ?? 0,
            totalPetting: byKind[.petted] ?? 0,
            totalLevelUps: byKind[.leveledUp] ?? 0,
            byDay: byDay,
            byKind: byKind,
            currentStreak: current,
            longestStreak: longest
        )
    }

    // MARK: 连续天数

    private static func computeStreak(entries: [PetEventLogEntry]) -> (current: Int, longest: Int) {
        let cal = Calendar.current
        let daySet = Set(entries.map { cal.startOfDay(for: $0.timestamp) })

        // 当前连续：从今天/昨天往前数
        var current = 0
        var cursor = cal.startOfDay(for: Date())
        if daySet.contains(cursor) || daySet.contains(cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor) {
            while daySet.contains(cursor) {
                current += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            }
        }

        // 最长：把所有日期排序后找最长连续
        let sorted = daySet.sorted()
        var longest = 0
        var runLength = 0
        var prev: Date? = nil
        for day in sorted {
            if let prev = prev, cal.date(byAdding: .day, value: 1, to: prev) == day {
                runLength += 1
            } else {
                runLength = 1
            }
            longest = max(longest, runLength)
            prev = day
        }

        return (current, longest)
    }
}
