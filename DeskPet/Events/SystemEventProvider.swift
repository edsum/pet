import Foundation
import Combine

/// 系统事件提供者的统一协议
///
/// 每个子系统（日程/健康/勿扰/天气）实现这个协议，
/// 由 EventEngine 统一调度，避免散落的 NotificationCenter 订阅。
protocol SystemEventProvider: AnyObject {
    /// 请求权限；返回 true 表示已授权或无需授权
    @MainActor func requestAuthorization() async -> Bool
    /// 开始监听。监听到的变化通过 onEvent 回调上抛
    func start(onEvent: @escaping (SystemSignal) -> Void)
    /// 停止监听
    func stop()
}

/// 系统信号：所有 provider 上抛的统一格式
enum SystemSignal {
    case calendarBusy(Bool, until: Date?)     // 日程进行中 / 结束
    case stepCount(Int)                        // 今日步数（按天结算）
    case focusModeActive(Bool)                 // 勿扰/专注模式开/关
    case weatherChanged(condition: WeatherCondition)
}

enum WeatherCondition {
    case clear, cloudy, rain, snow, hot, cold, windy
}
