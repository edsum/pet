import UIKit
import AVFoundation
import Combine
import DeskPetKit
import SpriteKit

#if canImport(WidgetKit)
import WidgetKit
#endif

/// 监听系统事件，转换为 PetEvent 后驱动 PetViewModel
final class EventEngine {

    static let shared = EventEngine()

    private weak var vm: PetViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var batteryPollTimer: Timer?
    private var lastKnownIsCharging: Bool?
    private var didSendLowBatteryEvent = false

    private enum BatterySyncReason {
        case startup
        case stateChanged
        case levelChanged
        case poll
        case becameActive
        case enteredBackground
    }

    private init() {}

    func start() {
        self.vm = PetViewModelAccessor.shared.vm
        UIDevice.current.isBatteryMonitoringEnabled = true

        // App 启动时清理上次没正常结束的 Live Activity
        Task { @MainActor in
            await ActivityController.shared.endAll()
            await self.syncBatteryStatus(reason: .startup, forceStatusUpdate: true)
        }

        observeBattery()
        observeLowPowerMode()
        observeAudioRoute()
        observeLifecycle()
    }

    // MARK: 充电 / 电量（带 Live Activity）

    private func observeBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        let center = NotificationCenter.default
        center.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.syncBatteryStatus(reason: .stateChanged, forceStatusUpdate: true)
                }
            }
            .store(in: &cancellables)

        center.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.syncBatteryStatus(reason: .levelChanged, forceStatusUpdate: true)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func syncBatteryStatus(
        reason: BatterySyncReason,
        forceStatusUpdate: Bool = false
    ) async {
        UIDevice.current.isBatteryMonitoringEnabled = true

        let level = currentBatteryLevel()
        let isCharging = currentIsCharging()
        let persistedStatus = SharedStore.loadDeviceStatus()
        let previousIsCharging = lastKnownIsCharging ?? persistedStatus.isCharging
        let didChangeCharging = previousIsCharging != isCharging

        lastKnownIsCharging = isCharging
        SharedStore.saveDeviceStatus(batteryLevel: level, isCharging: isCharging)

        let pet = vm?.state
        let name = pet?.name ?? "小毛"
        let petID = pet?.petID

        if isCharging {
            if didChangeCharging {
                vm?.handle(event: .chargingStarted)
                spawnChargingEffects()
            }
            if didChangeCharging
                || reason == .startup
                || reason == .becameActive
                || reason == .enteredBackground {
                try? await ActivityController.shared.startCharging(petName: name, petID: petID)
            }
            if let level {
                await ActivityController.shared.updateCharging(batteryLevel: level)
            } else if forceStatusUpdate {
                await ActivityController.shared.updateStatus(
                    petName: name,
                    petID: petID,
                    isCharging: true,
                    subtitle: "正在充电，能量补给中"
                )
            }
            startBatteryPolling()
        } else {
            if didChangeCharging && previousIsCharging {
                vm?.handle(event: .chargingStopped)
            }
            await ActivityController.shared.endCharging(
                petName: name,
                petID: petID,
                batteryLevel: level
            )
            stopBatteryPolling()
        }

        if let level {
            if level <= 0.2 && !didSendLowBatteryEvent {
                vm?.handle(event: .batteryLow)
                didSendLowBatteryEvent = true
            } else if level > 0.25 {
                didSendLowBatteryEvent = false
            }
        }
    }

    /// 每 30 秒把当前电量推给 Live Activity（保持进度条更新）
    private func startBatteryPolling() {
        guard batteryPollTimer == nil else { return }
        batteryPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncBatteryStatus(reason: .poll, forceStatusUpdate: true)
            }
        }
    }

    private func stopBatteryPolling() {
        batteryPollTimer?.invalidate()
        batteryPollTimer = nil
    }

    private func currentBatteryLevel() -> Double? {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }
        return Double(level)
    }

    private func currentIsCharging() -> Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    // MARK: 低电量模式

    private func observeLowPowerMode() {
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                let on = ProcessInfo.processInfo.isLowPowerModeEnabled
                Task { @MainActor in
                    self?.vm?.handle(event: .lowPowerModeChanged(on))
                    if on {
                        // 开启低电量模式 → 启动睡觉活动
                        let name = self?.vm?.state.name ?? "小毛"
                        try? await ActivityController.shared.startSleeping(petName: name)
                    } else {
                        await ActivityController.shared.endSleeping()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: 音频路由（戴耳机 → 跳舞 + 音符粒子）

    private func observeAudioRoute() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
                let hasHeadphones = outputs.contains { $0.portType == .headphones || $0.portType == .bluetoothA2DP }
                let env = DeskPetKit.Environment(hasHeadphones: hasHeadphones)
                Task { @MainActor in
                    self?.vm?.applyEnvironment(env)
                    if hasHeadphones { self?.spawnNotesLoop() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: 前后台

    private func observeLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.vm?.reconcile()
                    await self?.syncBatteryStatus(reason: .becameActive, forceStatusUpdate: true)
                    self?.vm?.handle(event: .enterForeground)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.syncBatteryStatus(reason: .enteredBackground, forceStatusUpdate: true)
                    self?.vm?.handle(event: .enterBackground)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: 场景效果（系统事件 → SpriteKit 粒子）

    private func spawnChargingEffects() {
        Task { @MainActor in
            guard let pet = vm?.scene.pet else { return }
            vm?.scene.spawnSymbols(text: "⚡️",
                                   at: CGPoint(x: pet.position.x,
                                               y: pet.position.y + pet.size/2),
                                   count: 5, spread: 40)
        }
    }

    private var notesTimer: Timer?
    private func spawnNotesLoop() {
        notesTimer?.invalidate()
        notesTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let pet = self?.vm?.scene.pet else { return }
                self?.vm?.scene.spawnNotes(at: CGPoint(x: pet.position.x + 30,
                                                       y: pet.position.y + pet.size/2))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.notesTimer?.invalidate()
            self?.notesTimer = nil
        }
    }
}

/// 解决 EventEngine 单例与 PetViewModel 的注入顺序
final class PetViewModelAccessor: @unchecked Sendable {
    static let shared = PetViewModelAccessor()
    var vm: PetViewModel?
    private init() {}
}
