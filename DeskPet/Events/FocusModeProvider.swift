import Foundation
import DeskPetKit

/// 勿扰/专注模式监听：开启时宠物变 "quiet"（嘘，安静）
///
/// 简化版本：用 ProcessInfo 的低电量模式近似"专注模式"
/// （FamilyControls 需要 Apple 审批 entitlement，开发期用这个兜底）
final class FocusModeProvider: NSObject, SystemEventProvider {

    private var onEvent: ((SystemSignal) -> Void)?
    private var wasActive = false
    private var timer: Timer?

    @MainActor
    func requestAuthorization() async -> Bool {
        // 不需要权限申请：低电量模式是系统级开关
        return true
    }

    func start(onEvent: @escaping (SystemSignal) -> Void) {
        self.onEvent = onEvent
        // 每 60 秒检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkFocus()
        }
        checkFocus()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onEvent = nil
    }

    private func checkFocus() {
        // 用 ProcessInfo 的低电量模式作为"专注"近似
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if lowPower != wasActive {
            wasActive = lowPower
            onEvent?(.focusModeActive(lowPower))
        }
    }
}
