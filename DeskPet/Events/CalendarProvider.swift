import Foundation
import EventKit
import DeskPetKit

/// 日程监听：当用户有进行中的事件时，让宠物变 "quiet"（嘘）
///
/// 权限：NSCalendarsUsageDescription
final class CalendarProvider: NSObject, SystemEventProvider {

    private let store = EKEventStore()
    private var timer: Timer?
    private var onEvent: ((SystemSignal) -> Void)?
    private var wasBusy = false

    @MainActor
    func requestAuthorization() async -> Bool {
        // iOS 17+ 用 full_access 系列；老 API 自动降级
        let granted: EKAuthorizationStatus
        if #available(iOS 17.0, *) {
            granted = EKEventStore.authorizationStatus(for: .event)
            if granted == .notDetermined {
                let result = try? await store.requestFullAccessToEvents()
                return result ?? false
            }
        } else {
            granted = EKEventStore.authorizationStatus(for: .event)
            if granted == .notDetermined {
                return await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }
        }
        return granted == .authorized || granted == .fullAccess
    }

    func start(onEvent: @escaping (SystemSignal) -> Void) {
        self.onEvent = onEvent
        // 每 60 秒检查一次当前是否有进行中的事件（够用，省电）
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkCurrentEvent()
        }
        // 立刻查一次
        checkCurrentEvent()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onEvent = nil
    }

    // MARK: 查询

    private func checkCurrentEvent() {
        let now = Date()
        let cal = Calendar.current
        let endOfTomorrow = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now)) ?? now

        let predicate = store.predicateForEvents(withStart: now,
                                                  end: endOfTomorrow,
                                                  calendars: nil)
        let events = store.events(matching: predicate)

        // 当前正在进行中（带 5 分钟缓冲，事件刚开始或快结束也算）
        let active = events.first { event in
            event.startDate <= now.addingTimeInterval(5 * 60)
                && event.endDate >= now.addingTimeInterval(-5 * 60)
            && !event.isAllDay              // 不算全天事件（否则一整天都 quiet 了）
        }

        let busy = active != nil
        if busy != wasBusy {
            wasBusy = busy
            onEvent?(.calendarBusy(busy, until: active?.endDate))
        }
    }
}
