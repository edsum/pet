import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// 统一管理宠物 Live Activity 的启动 / 更新 / 结束
///
/// 使用方式：
///   try await ActivityController.shared.startCharging(petName: "小毛")
///   await ActivityController.shared.updateCharging(batteryLevel: 0.8)
///   await ActivityController.shared.endCharging()
@MainActor
public final class ActivityController {

    public static let shared = ActivityController()
    private init() {}

    #if canImport(ActivityKit)

    /// 当前持有的活动（按 kind 索引）
    private var activities: [PetActivityAttributes.Kind: Activity<PetActivityAttributes>] = [:]

    // MARK: 检查可用性

    public var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: 充电进食

    /// 开始充电活动
    public func startCharging(petName: String) async throws {
        guard isAvailable else { return }
        let attrs = PetActivityAttributes(petName: petName, kind: .charging)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.eating.rawValue,
            progress: 0,
            subtitle: "正在充电进食中…",
            detail: "⚡️"
        )
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.charging] = activity
    }

    /// 更新充电进度（batteryLevel: 0~1）
    public func updateCharging(batteryLevel: Double) async {
        guard let activity = activities[.charging] else { return }
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.eating.rawValue,
            progress: batteryLevel,
            subtitle: batteryLevel >= 1 ? "吃饱啦！" : "正在充电进食中…",
            detail: "⚡️ \(Int(batteryLevel * 100))%"
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    /// 结束充电活动
    public func endCharging() async {
        guard let activity = activities[.charging] else { return }
        await endActivitySafely(activity)
        activities.removeValue(forKey: .charging)
    }

    // MARK: 洗澡

    public func startBathing(petName: String) async throws {
        guard isAvailable else { return }
        let attrs = PetActivityAttributes(petName: petName, kind: .bathing)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.happy.rawValue,
            progress: 0,
            subtitle: "正在洗澡，30 秒后变干净～"
        )
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.bathing] = activity
    }

    public func updateBathing(progress: Double) async {
        guard let activity = activities[.bathing] else { return }
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.happy.rawValue,
            progress: progress,
            subtitle: "快好了，香喷喷～"
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    public func endBathing() async {
        guard let activity = activities[.bathing] else { return }
        await endActivitySafely(activity)
        activities.removeValue(forKey: .bathing)
    }

    // MARK: 睡觉

    public func startSleeping(petName: String) async throws {
        guard isAvailable else { return }
        guard activities[.sleeping] == nil else { return }    // 已在睡 → 不重复开
        let attrs = PetActivityAttributes(petName: petName, kind: .sleeping)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.sleeping.rawValue,
            progress: 0,
            subtitle: "Zzz… 休息中"
        )
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.sleeping] = activity
    }

    public func endSleeping() async {
        guard let activity = activities[.sleeping] else { return }
        await endActivitySafely(activity)
        activities.removeValue(forKey: .sleeping)
    }

    // MARK: 步数达标（短时庆祝，5 秒后自动结束）

    public func startStepGoalCelebration(petName: String, steps: Int) async throws {
        guard isAvailable else { return }
        let attrs = PetActivityAttributes(petName: petName, kind: .stepGoal)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.excited.rawValue,
            progress: 1,
            subtitle: "今日走了 \(steps) 步！",
            detail: "🎉 +15 金币"
        )
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.stepGoal] = activity

        // 5 秒后自动结束
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            await self?.endActivitySafely(activity)
            self?.activities.removeValue(forKey: .stepGoal)
        }
    }

    // MARK: 全部清空（App 启动时清理上次残留）

    public func endAll() async {
        for (_, activity) in activities {
            await endActivitySafely(activity)
        }
        activities.removeAll()
    }

    /// 安全结束一个 Activity（隔离到 nonisolated 上下文，规避 Swift 6 数据竞争告警）
    private nonisolated func endActivitySafely(_ activity: Activity<PetActivityAttributes>) async {
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    #endif
}
