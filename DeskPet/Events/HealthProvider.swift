import Foundation
import HealthKit
import DeskPetKit

/// 步数监听：今日步数 ≥ 5000 时，奖励宠物 exp + coins（每天结算一次）
///
/// 权限：NSHealthShareUsageDescription + Info.plist 配 NSHealthShareUsageDescription
final class HealthProvider: NSObject, SystemEventProvider {

    private let store = HKHealthStore()
    private var onEvent: ((SystemSignal) -> Void)?
    private var observerQuery: HKObserverQuery?
    private var lastRewardDate: Date?

    @MainActor
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let types: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!]
        return await withCheckedContinuation { cont in
            store.requestAuthorization(toShare: nil, read: types) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    func start(onEvent: @escaping (SystemSignal) -> Void) {
        self.onEvent = onEvent

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        // Observer Query：后台有新步数时由系统唤起
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, _ in
            self?.fetchTodaySteps()
        }
        store.execute(query)
        observerQuery = query

        // 启动时立刻拉一次
        fetchTodaySteps()
    }

    func stop() {
        if let q = observerQuery { store.stop(q) }
        observerQuery = nil
        onEvent = nil
    }

    // MARK: 查询今日步数

    private func fetchTodaySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let q = HKStatisticsQuery(quantityType: stepType,
                                  quantitySamplePredicate: predicate,
                                  options: .cumulativeSum) { [weak self] _, stats, _ in
            let steps = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            DispatchQueue.main.async {
                self?.handleSteps(steps)
            }
        }
        store.execute(q)
    }

    private func handleSteps(_ steps: Int) {
        onEvent?(.stepCount(steps))

        // 达到 5000 步且今天还没奖励过 → 触发奖励事件
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if steps >= 5000,
           let last = lastRewardDate,
           cal.isDate(last, inSameDayAs: today) == false || lastRewardDate == nil {
            lastRewardDate = today
            // 上抛一次"步数达标" → 由 EventEngine 转 PetEvent.stepGoalReached
            onEvent?(.stepCount(-1))   // 用 -1 作为"达标信号"约定
        }
    }
}
