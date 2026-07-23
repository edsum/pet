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
    private var statusSnapshot: PetActivityAttributes.ContentState?

    // MARK: 检查可用性

    public var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: 锁屏状态

    public func startStatus(
        petName: String,
        petID: UUID? = nil,
        steps: Int? = nil,
        weather: String? = nil,
        batteryLevel: Double? = nil,
        isCharging: Bool = false
    ) async throws {
        guard isAvailable else { return }

        let state = makeStatusState(
            previous: statusSnapshot,
            steps: steps,
            weather: weather,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            subtitle: nil,
            petID: petID,
            petName: petName
        )
        statusSnapshot = state

        if let activity = await primaryActivity(for: .status) {
            await activity.update(.init(state: state, staleDate: nil))
            return
        }

        let attrs = PetActivityAttributes(petName: petName, kind: .status)
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.status] = activity
    }

    public func updateStatus(
        petName: String? = nil,
        petID: UUID? = nil,
        steps: Int? = nil,
        weather: String? = nil,
        batteryLevel: Double? = nil,
        isCharging: Bool? = nil,
        subtitle: String? = nil
    ) async {
        guard isAvailable else { return }
        let state = makeStatusState(
            previous: statusSnapshot,
            steps: steps,
            weather: weather,
            batteryLevel: batteryLevel,
            isCharging: isCharging ?? statusSnapshot?.isCharging ?? false,
            subtitle: subtitle,
            petID: petID,
            petName: petName
        )
        statusSnapshot = state

        if let activity = await primaryActivity(for: .status) {
            await activity.update(.init(state: state, staleDate: nil))
        } else {
            try? await startStatus(
                petName: state.petName ?? petName ?? "小毛",
                petID: state.petID ?? petID,
                steps: state.steps,
                weather: state.weather,
                batteryLevel: state.batteryPercent.map { Double($0) / 100 },
                isCharging: state.isCharging
            )
        }
    }

    // MARK: 充电进食

    /// 开始充电活动
    public func startCharging(petName: String) async throws {
        try await startCharging(petName: petName, petID: nil)
    }

    public func startCharging(petName: String, petID: UUID?) async throws {
        guard isAvailable else { return }
        let attrs = PetActivityAttributes(petName: petName, kind: .charging)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.eating.rawValue,
            progress: 0,
            subtitle: "正在充电进食中…",
            detail: "⚡️",
            isCharging: true,
            updatedAt: Date(),
            petID: petID,
            petName: petName,
            showSteps: WidgetDisplaySettings.showSteps,
            showWeather: WidgetDisplaySettings.showWeather
        )
        if let activity = await primaryActivity(for: .charging) {
            await activity.update(.init(state: state, staleDate: nil))
            try? await startStatus(petName: petName, petID: petID, isCharging: true)
            return
        }

        let activity = try Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        activities[.charging] = activity
        try? await startStatus(petName: petName, petID: petID, isCharging: true)
    }

    /// 更新充电进度（batteryLevel: 0~1）
    public func updateCharging(batteryLevel: Double) async {
        let percent = batteryPercent(from: batteryLevel)
        let state = PetActivityAttributes.ContentState(
            mood: PetMood.eating.rawValue,
            progress: batteryLevel,
            subtitle: batteryLevel >= 1 ? "吃饱啦！" : "正在充电进食中…",
            detail: "⚡️ \(percent)%",
            steps: statusSnapshot?.steps,
            weather: statusSnapshot?.weather,
            batteryPercent: percent,
            isCharging: true,
            updatedAt: Date(),
            petID: statusSnapshot?.petID,
            petName: statusSnapshot?.petName,
            showSteps: WidgetDisplaySettings.showSteps,
            showWeather: WidgetDisplaySettings.showWeather
        )
        if let activity = activities[.charging] {
            await activity.update(.init(state: state, staleDate: nil))
        }
        await updateStatus(
            batteryLevel: batteryLevel,
            isCharging: true,
            subtitle: batteryLevel >= 1 ? "电量已充满，精神满格" : "正在充电，能量补给中"
        )
    }

    /// 结束充电活动
    public func endCharging(
        petName: String? = nil,
        petID: UUID? = nil,
        batteryLevel: Double? = nil
    ) async {
        for activity in existingActivities(for: .charging) {
            await endActivitySafely(activity)
        }
        activities.removeValue(forKey: .charging)
        await updateStatus(
            petName: petName,
            petID: petID,
            batteryLevel: batteryLevel,
            isCharging: false,
            subtitle: "电量状态已更新"
        )
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

    // MARK: 家园探险（短时活动）

    public func startExpedition(petName: String, rewardCoins: Int) async throws {
        guard isAvailable else { return }
        guard activities[.expedition] == nil else { return }

        let attrs = PetActivityAttributes(petName: petName, kind: .expedition)
        let activity = try Activity.request(
            attributes: attrs,
            content: .init(
                state: .init(
                    mood: PetMood.playing.rawValue,
                    progress: 0,
                    subtitle: "出发寻找能量石…",
                    detail: "地图展开"
                ),
                staleDate: nil
            ),
            pushType: nil
        )
        activities[.expedition] = activity

        Task { @MainActor [weak self] in
            let updates: [(Double, String, String)] = [
                (0.25, "穿过树屋小径", "发现脚印"),
                (0.55, "打开补给泡泡", "+\(max(1, rewardCoins / 2))"),
                (0.85, "快回到家园啦", "背包发光"),
                (1.00, "探险完成！", "+\(rewardCoins) 能量石")
            ]

            for update in updates {
                try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
                await activity.update(.init(
                    state: .init(
                        mood: PetMood.playing.rawValue,
                        progress: update.0,
                        subtitle: update.1,
                        detail: update.2
                    ),
                    staleDate: nil
                ))
            }

            await self?.endActivitySafely(activity)
            self?.activities.removeValue(forKey: .expedition)
        }
    }

    // MARK: 全部清空（App 启动时清理上次残留）

    public func endAll() async {
        for activity in existingActivities() {
            await endActivitySafely(activity)
        }
        activities.removeAll()
        statusSnapshot = nil
    }

    /// 安全结束一个 Activity（隔离到 nonisolated 上下文，规避 Swift 6 数据竞争告警）
    private nonisolated func endActivitySafely(_ activity: Activity<PetActivityAttributes>) async {
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func makeStatusState(
        previous: PetActivityAttributes.ContentState?,
        steps: Int?,
        weather: String?,
        batteryLevel: Double?,
        isCharging: Bool,
        subtitle: String?,
        petID: UUID?,
        petName: String?
    ) -> PetActivityAttributes.ContentState {
        let batteryPercent = batteryLevel.map(batteryPercent(from:)) ?? previous?.batteryPercent
        let wasCharging = previous?.isCharging == true
        let progress = batteryPercent.map { Double($0) / 100 } ?? (wasCharging && !isCharging ? 0 : previous?.progress ?? 0)
        let mood: String
        if isCharging {
            mood = PetMood.eating.rawValue
        } else if wasCharging {
            mood = PetMood.happy.rawValue
        } else {
            mood = previous?.mood ?? PetMood.happy.rawValue
        }
        let detail: String
        if let batteryPercent {
            detail = isCharging ? "⚡️ \(batteryPercent)%" : "\(batteryPercent)% 电量"
        } else {
            detail = wasCharging && !isCharging ? "" : previous?.detail ?? ""
        }
        let statusSubtitle = subtitle ?? (isCharging ? "正在充电，能量补给中" : "锁屏状态同步中")

        return PetActivityAttributes.ContentState(
            mood: mood,
            progress: min(max(progress, 0), 1),
            subtitle: statusSubtitle,
            detail: detail,
            steps: steps ?? previous?.steps,
            weather: weather ?? previous?.weather,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            updatedAt: Date(),
            petID: petID ?? previous?.petID,
            petName: petName ?? previous?.petName,
            showSteps: WidgetDisplaySettings.showSteps,
            showWeather: WidgetDisplaySettings.showWeather
        )
    }

    private func batteryPercent(from batteryLevel: Double) -> Int {
        min(100, max(0, Int((batteryLevel * 100).rounded())))
    }

    private func primaryActivity(
        for kind: PetActivityAttributes.Kind
    ) async -> Activity<PetActivityAttributes>? {
        let matches = existingActivities(for: kind)
        guard let primary = matches.first else { return nil }

        for duplicate in matches.dropFirst() {
            await endActivitySafely(duplicate)
        }
        activities[kind] = primary
        return primary
    }

    private func existingActivities(
        for kind: PetActivityAttributes.Kind? = nil
    ) -> [Activity<PetActivityAttributes>] {
        var result: [Activity<PetActivityAttributes>] = []
        var seen = Set<String>()

        func append(_ activity: Activity<PetActivityAttributes>) {
            switch activity.activityState {
            case .active, .stale:
                break
            case .ended, .dismissed:
                return
            @unknown default:
                return
            }
            guard kind == nil || activity.attributes.kind == kind else { return }
            guard seen.insert(activity.id).inserted else { return }
            result.append(activity)
        }

        for activity in activities.values {
            append(activity)
        }
        for activity in Activity<PetActivityAttributes>.activities {
            append(activity)
        }
        return result
    }

    #endif
}
