import Foundation
import Combine
import DeskPetKit

/// 统一编排所有 SystemEventProvider
///
/// 用法：App 启动后 `SystemEventOrchestrator.shared.bootstrap(vm:)`，
/// 之后所有系统信号自动转成 PetEvent 喂给 ViewModel
final class SystemEventOrchestrator {

    static let shared = SystemEventOrchestrator()

    private weak var vm: PetViewModel?
    private var providers: [SystemEventProvider] = []
    private var cancellables = Set<AnyCancellable>()

    // 防止步数信号抖动：每次启动只奖励一次
    private var stepRewardedToday = false

    private init() {}

    @MainActor
    func bootstrap(vm: PetViewModel) {
        self.vm = vm

        Task {
            // 日程（不需要 entitlement，先做）
            let calendar = CalendarProvider()
            if await calendar.requestAuthorization() {
                calendar.start { [weak self] signal in
                    Task { @MainActor in self?.handle(signal) }
                }
                providers.append(calendar)
            }

            // 步数
            let health = HealthProvider()
            if await health.requestAuthorization() {
                health.start { [weak self] signal in
                    Task { @MainActor in self?.handle(signal) }
                }
                providers.append(health)
            }

            // 勿扰
            let focus = FocusModeProvider()
            if await focus.requestAuthorization() {
                focus.start { [weak self] signal in
                    Task { @MainActor in self?.handle(signal) }
                }
                providers.append(focus)
            }

            // 天气
            let weather = WeatherProvider()
            if await weather.requestAuthorization() {
                weather.start { [weak self] signal in
                    Task { @MainActor in self?.handle(signal) }
                }
                providers.append(weather)
            }
        }
    }

    func stop() {
        providers.forEach { $0.stop() }
        providers.removeAll()
    }

    // MARK: 信号路由

    @MainActor
    private func handle(_ signal: SystemSignal) {
        switch signal {
        case .calendarBusy(let busy, _):
            if busy {
                vm?.handle(event: .calendarBusy)
            } else {
                // 会议结束 → 回到默认情绪
                vm?.recomputeMood()
            }

        case .stepCount(let steps):
            // -1 是约定信号：达到 5000 步
            if steps == -1, !stepRewardedToday {
                stepRewardedToday = true
                vm?.handle(event: .stepGoalReached)
                // 启动 5 秒庆祝 Live Activity
                let name = vm?.state.name ?? "小毛"
                Task { @MainActor in
                    try? await ActivityController.shared.startStepGoalCelebration(
                        petName: name, steps: 5000)
                }
            }

        case .focusModeActive(let active):
            if active {
                vm?.setMood(.quiet)
            } else {
                vm?.recomputeMood()
            }

        case .weatherChanged(let condition):
            applyWeather(condition)
        }
    }

    @MainActor
    private func applyWeather(_ condition: WeatherCondition) {
        let petPosition = vm?.scene.pet?.position ?? .zero

        switch condition {
        case .rain:
            vm?.setMood(.curious)
            vm?.scene.spawnSymbols(text: "☔️",
                                   at: petPosition,
                                   count: 3, spread: 30)
        case .snow:
            vm?.scene.spawnSymbols(text: "❄️",
                                   at: petPosition,
                                   count: 5, spread: 50)
            vm?.setMood(.excited)
        case .hot:
            vm?.setMood(.tired)
        case .cold:
            vm?.setMood(.sleeping)
        default:
            vm?.recomputeMood()
        }
    }
}
