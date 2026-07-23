import Foundation
import SwiftUI
import Combine
import DeskPetKit
import SpriteKit

#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class PetViewModel: ObservableObject {

    @Published public var state: PetState = .preview
    @Published private(set) var eventLog: [PetEventLogEntry] = []

    /// 多宠物管理
    let manager = PetManager()

    /// ★ M9 养成外围系统：签到 / 成就 / 商店 / 进化
    let progression = ProgressionManager()

    /// SpriteKit 场景（App 内互动用）
    let scene: PetScene = PetScene()

    private var cancellables = Set<AnyCancellable>()

    // MARK: 生命周期

    func bootstrap() {
        // 多宠物：迁移老数据 + 加载
        manager.migrateFromSinglePetIfNeeded()
        manager.load()
        refreshCurrentPet()

        Logger.app.info("PetVM bootstrap: pet=\(state.name) lv=\(state.level)")

        // 初始化 SpriteKit 场景
        scene.size = CGSize(width: 400, height: 600)
        scene.bootstrap(initial: state)
        bindSceneCallbacks()
        startZzzTimer()
        bindCloudSync()

        // 加载事件日志
        refreshEventLog()
    }

    /// 把 manager.current 同步到 self.state
    func refreshCurrentPet() {
        guard let pet = manager.current else { return }
        state = pet
        scene.sync(state: pet)
        SharedStore.saveState(pet)
        syncLiveActivityPetSnapshot()
    }

    func reconcile() {
        manager.mutateCurrent { $0.reconcile() }
        refreshCurrentPet()
        persist()
    }

    func persist() {
        SharedStore.saveState(state)
        manager.update(state)
        // ★ 同步到 iCloud（异步、不阻塞 UI）
        CloudSync.shared.upload(state)
        // ★ 推送到 Apple Watch
        WatchSync.shared.push(state: state)
        // ★ 走节流器：普通事件 4/h、25/天；重要事件直接放行
        WidgetReloadThrottle.shared.reloadAll(isCritical: false)
        syncLiveActivityPetSnapshot()
    }

    // MARK: 用户互动（带事件日志）

    func feed(_ food: Food, animate: Bool = true) {
        guard state.coins >= food.price else {
            if animate { scene.performDenied() }
            return
        }
        let prevLevel = state.level
        state.apply(.userFed(food))
        logEvent(.fed, detail: "喂了 \(food.rawValue)")
        if state.level > prevLevel {
            logEvent(.leveledUp, detail: "升到 Lv.\(state.level)")
        }
        scene.sync(state: state)
        if animate { scene.performFeeding(food: food) }
        // 商店购物类 coins 减少 → progression 需要感知
        persist()
        Logger.app.info("feed(\(food.rawValue)): coins=\(state.coins)")
    }

    func pet(animate: Bool = true) {
        state.apply(.userPetted)
        logEvent(.petted, detail: "摸了摸头")
        scene.sync(state: state)
        if animate { scene.performAffection() }
        persist()
    }

    func play(game: Minigame, score: Int) {
        let prevLevel = state.level
        state.apply(.userPlayed(game: game, score: score))
        logEvent(.played, detail: "\(game.rawValue) 得 \(score) 分")
        if state.level > prevLevel {
            logEvent(.leveledUp, detail: "升到 Lv.\(state.level)")
        }
        scene.sync(state: state)
        scene.performReward(text: "+\(min(30, score / 3))")
        persist()
        Logger.game.info("play(\(game.rawValue)) score=\(score) exp=\(state.exp)")
    }

    @discardableResult
    func startExpedition() -> (coins: Int, exp: Int)? {
        guard state.stats.energy >= 12, state.stats.hunger >= 10 else {
            state.mood = state.stats.energy < 12 ? .tired : .hungry
            scene.sync(state: state)
            scene.performDenied()
            persist()
            return nil
        }

        let prevLevel = state.level
        let rewardCoins = Int.random(in: 12...28)
        let rewardExp = Int.random(in: 18...32)

        state.stats.energy = clamp(state.stats.energy - 12)
        state.stats.hunger = clamp(state.stats.hunger - 8)
        state.stats.happiness = clamp(state.stats.happiness + 6)
        state.coins += rewardCoins
        state.mood = .playing
        state.addExp(rewardExp)
        logEvent(.played, detail: "家园探险带回 \(rewardCoins) 能量石")
        if state.level > prevLevel {
            logEvent(.leveledUp, detail: "探险后升到 Lv.\(state.level)")
        }

        scene.sync(state: state)
        scene.performExpedition()
        persist()

        Task { @MainActor in
            try? await ActivityController.shared.startExpedition(
                petName: state.name,
                rewardCoins: rewardCoins
            )
        }

        return (rewardCoins, rewardExp)
    }

    @discardableResult
    func claimDailySupply() -> CheckInRecord.Reward? {
        guard progression.canCheckInToday else { return nil }

        let reward = progression.checkIn()
        let prevLevel = state.level
        state.coins += reward.coins
        state.addExp(reward.exp)
        logEvent(.revived, detail: "领取每日补给 +\(reward.coins)")
        if state.level > prevLevel {
            logEvent(.leveledUp, detail: "补给后升到 Lv.\(state.level)")
        }
        scene.sync(state: state)
        scene.performReward(text: "+\(reward.coins)")
        persist()
        refreshAchievements()
        return reward
    }

    @discardableResult
    func luckyDraw() -> (coins: Int, exp: Int) {
        let rewardCoins = [8, 10, 12, 16, 20, 30].randomElement() ?? 10
        let rewardExp = [6, 8, 10, 12, 15].randomElement() ?? 8
        let prevLevel = state.level

        state.coins += rewardCoins
        state.addExp(rewardExp)
        state.mood = .excited
        logEvent(.played, detail: "免费抽获得 \(rewardCoins) 能量石")
        if state.level > prevLevel {
            logEvent(.leveledUp, detail: "抽奖后升到 Lv.\(state.level)")
        }
        scene.sync(state: state)
        scene.performReward(text: "+\(rewardCoins)")
        persist()
        return (rewardCoins, rewardExp)
    }

    func bathe() {
        state.apply(.userBathed)
        logEvent(.bathed, detail: "洗了个澡")
        scene.sync(state: state)
        scene.performBathing()
        persist()
    }

    // MARK: 系统事件接入（被 EventEngine 调）

    func handle(event: PetEvent) {
        state.apply(event)
        let critical: Bool
        switch event {
        case .chargingStarted, .chargingStopped, .batteryLow, .stepGoalReached:
            critical = true
            logEvent(.charging, detail: "充电状态变化")
            if case .stepGoalReached = event {
                logEvent(.stepGoal, detail: "今日步数达标")
            }
        default:
            critical = false
        }
        SharedStore.saveState(state)
        manager.update(state)
        scene.sync(state: state)
        if case .chargingStarted = event {
            scene.performCharging()
        } else if case .batteryLow = event {
            scene.performDenied()
        } else if case .stepGoalReached = event {
            scene.performReward(text: "+15")
        }
        WidgetReloadThrottle.shared.reloadAll(isCritical: critical)
        syncLiveActivityPetSnapshot()
        Logger.event.info("handle event: \(event)")
    }

    func applyEnvironment(_ env: DeskPetKit.Environment) {
        EventRuleEngine.shared.apply(environment: env, to: &state)
        scene.sync(state: state)
        if env.isCharging {
            scene.performCharging()
        } else if env.hasHeadphones {
            scene.performReward(text: "♪")
        }
        persist()
    }

    /// ★ 由 Orchestrator 调用：直接设置 mood（绕过 apply，避免事件循环）
    func setMood(_ mood: PetMood) {
        state.mood = mood
        scene.sync(state: state)
        persist()
    }

    /// ★ 由 Orchestrator 调用：根据当前数值重新计算 mood
    func recomputeMood() {
        state.mood = state.computeMood()
        scene.sync(state: state)
        persist()
    }

    // MARK: 事件日志

    func refreshEventLog() {
        eventLog = EventLogStore.loadAll()
    }

    private func logEvent(_ kind: PetEventLogEntry.Kind, detail: String) {
        let entry = PetEventLogEntry(petID: state.petID, kind: kind, detail: detail)
        eventLog = EventLogStore.append(entry)
        // ★ 每次记日志后顺带检查成就
        refreshAchievements()
    }

    // MARK: 成就检测

    /// 重新计算 metric 并触发新成就解锁
    @discardableResult
    public func refreshAchievements() -> [Achievement] {
        let metrics = progression.currentMetrics(petLevel: state.level,
                                                  petCount: manager.pets.count,
                                                  eventLog: eventLog)
        let newly = progression.checkAchievements(metrics: metrics)
        // 把成就奖励的金币和经验同步到宠物
        for ach in newly {
            state.coins += ach.reward.coins
            state.addExp(ach.reward.exp)
        }
        if !newly.isEmpty {
            persist()
        }
        return newly
    }

    /// 给 UI 用的 metric 快照
    public func currentMetrics() -> [Achievement.Metric: Int] {
        progression.currentMetrics(petLevel: state.level,
                                    petCount: manager.pets.count,
                                    eventLog: eventLog)
    }

    // MARK: Scene 回调绑定

    private func bindSceneCallbacks() {
        scene.onPet = { [weak self] in
            self?.pet(animate: false)
        }
        scene.onJump = nil
        scene.onFeed = { [weak self] in
            self?.feed(.fish)
        }
        scene.onDragBegan = nil
        scene.onDragEnded = nil
    }

    // MARK: 睡觉时持续冒 Zzz

    private var zzzTimer: Timer?

    private func startZzzTimer() {
        zzzTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scene.spawnZzz() }
        }
    }

    // MARK: iCloud 同步

    private func bindCloudSync() {
        CloudSync.shared.onSyncComplete = { [weak self] remoteState in
            guard let self else { return }
            if remoteState.lastUpdate > self.state.lastUpdate {
                Logger.app.info("Adopting remote state from iCloud")
                self.state = remoteState
                self.scene.sync(state: remoteState)
                SharedStore.saveState(remoteState)
                self.manager.update(remoteState)
                self.syncLiveActivityPetSnapshot()
            }
        }
    }

    private func syncLiveActivityPetSnapshot() {
        let pet = state
        Task { @MainActor in
            await ActivityController.shared.updateStatus(
                petName: pet.name,
                petID: pet.petID
            )
        }
    }
}
