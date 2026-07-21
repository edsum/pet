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

    private init() {}

    func start() {
        self.vm = PetViewModelAccessor.shared.vm

        // App 启动时清理上次没正常结束的 Live Activity
        Task { @MainActor in
            await ActivityController.shared.endAll()
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
                let state = UIDevice.current.batteryState
                Task { @MainActor in
                    if state == .charging || state == .full {
                        self.vm?.handle(event: .chargingStarted)
                        self.spawnChargingEffects()
                        // 启动充电 Live Activity
                        let name = self.vm?.state.name ?? "小毛"
                        try? await ActivityController.shared.startCharging(petName: name)
                        self.startBatteryPolling()
                    } else if state == .unplugged {
                        self.vm?.handle(event: .chargingStopped)
                        await ActivityController.shared.endCharging()
                        self.stopBatteryPolling()
                    }
                }
            }
            .store(in: &cancellables)

        center.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                let level = UIDevice.current.batteryLevel
                if level >= 0 && level <= 0.2 {
                    Task { @MainActor in self?.vm?.handle(event: .batteryLow) }
                }
            }
            .store(in: &cancellables)
    }

    /// 每 30 秒把当前电量推给 Live Activity（保持进度条更新）
    private func startBatteryPolling() {
        batteryPollTimer?.invalidate()
        batteryPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let level = UIDevice.current.batteryLevel
            Task { @MainActor in
                await ActivityController.shared.updateCharging(batteryLevel: Double(level))
            }
        }
    }

    private func stopBatteryPolling() {
        batteryPollTimer?.invalidate()
        batteryPollTimer = nil
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
                    self?.vm?.handle(event: .enterForeground)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.vm?.handle(event: .enterBackground) }
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
