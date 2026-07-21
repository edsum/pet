import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Widget 刷新节流器：防止超过系统每天 40 次 reload 预算
///
/// 系统规则：
///   - TimelineProvider 提供的 entries 不计入预算
///   - WidgetCenter.reloadAllTimelines() / reloadTimelines() 计入预算
///   - 重要事件（充电/低电量）系统豁免，但我们没法查询剩余预算
///
/// 策略：
///   1. 重要事件（标记 isCritical）一律放行，不节流
///   2. 普通事件（用户互动、时间校准）走"令牌桶"
///      每小时最多 4 次、每天最多 25 次（留 15 次给系统回放）
public final class WidgetReloadThrottle: @unchecked Sendable {

    public static let shared = WidgetReloadThrottle()

    private let queue = DispatchQueue(label: "deskpet.widgetreload",
                                       qos: .utility,
                                       attributes: .concurrent)

    private let maxPerHour = 4
    private let maxPerDay  = 25
    private let calendar = Calendar.current

    private var hourlyStamps: [Date] = []
    private var dailyStamps: [Date] = []

    private init() {}

    // MARK: 节流后的 reload

    /// 节流调用 reloadAllTimelines
    /// - Parameter isCritical: 重要事件（充电/低电量/步数达标）不节流
    public func reloadAll(isCritical: Bool = false) {
        if isCritical {
            performReloadAll()
            return
        }
        queue.async(flags: .barrier) {
            guard self.canReload() else {
                Logger.widget.warn("reload skipped: budget exhausted")
                return
            }
            self.stamp()
            self.performReloadAll()
        }
    }

    /// 节流调用 reloadTimelines(ofKind:)
    public func reload(kind: String, isCritical: Bool = false) {
        if isCritical {
            performReload(kind: kind)
            return
        }
        queue.async(flags: .barrier) {
            guard self.canReload() else {
                Logger.widget.warn("reload(\(kind)) skipped: budget exhausted")
                return
            }
            self.stamp()
            self.performReload(kind: kind)
        }
    }

    // MARK: 预算检查

    /// 当前剩余预算（用于 Debug 覆盖层显示）
    public func remainingBudget() -> (hour: Int, day: Int) {
        queue.sync {
            purge()
            return (maxPerHour - hourlyStamps.count,
                    maxPerDay - dailyStamps.count)
        }
    }

    private func canReload() -> Bool {
        purge()
        return hourlyStamps.count < maxPerHour && dailyStamps.count < maxPerDay
    }

    private func stamp() {
        let now = Date()
        hourlyStamps.append(now)
        dailyStamps.append(now)
    }

    /// 清理 1 小时 / 1 天以前的记录
    private func purge() {
        let now = Date()
        hourlyStamps.removeAll { now.timeIntervalSince($0) > 3600 }
        if let dayStart = calendar.date(byAdding: .day, value: -1, to: now) {
            dailyStamps.removeAll { $0 < dayStart }
        }
    }

    // MARK: 真正调用 WidgetKit

    private func performReloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        Logger.widget.info("reloadAll: ok")
        #endif
    }

    private func performReload(kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        Logger.widget.info("reload(\(kind)): ok")
        #endif
    }
}
