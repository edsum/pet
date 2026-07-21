import Foundation
import WeatherKit
import CoreLocation
import DeskPetKit

/// 天气监听：根据当前天气改变宠物 mood 和背景
///
/// 权限：WeatherKit 需要在 Apple Developer 后台启用服务，并配置 bundle id
/// Info.plist：NSLocationWhenInUseUsageDescription
final class WeatherProvider: NSObject, SystemEventProvider, CLLocationManagerDelegate {

    private let location = CLLocationManager()
    private let weatherService = WeatherService.shared
    private var onEvent: ((SystemSignal) -> Void)?
    private var lastCondition: WeatherCondition?
    private var timer: Timer?

    @MainActor
    func requestAuthorization() async -> Bool {
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyKilometer
        let status = location.authorizationStatus
        switch status {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
            return false       // 异步授权，下次再试
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func start(onEvent: @escaping (SystemSignal) -> Void) {
        self.onEvent = onEvent
        // 每 30 分钟拉一次天气（够用，省电）
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        fetchWeather()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onEvent = nil
    }

    // MARK: 拉天气

    private func fetchWeather() {
        guard let coord = location.location?.coordinate else {
            location.requestLocation()
            return
        }
        let point = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        Task { [weak self] in
            do {
                let weather = try await self?.weatherService.weather(for: point)
                let current = weather?.currentWeather
                let condition = Self.map(current)
                if condition != self?.lastCondition {
                    self?.lastCondition = condition
                    self?.onEvent?(.weatherChanged(condition: condition))
                }
            } catch {
                // 静默失败：天气拿不到不影响其他功能
            }
        }
    }

    /// 把 WeatherKit 的 condition 简化成 7 种
    private static func map(_ w: CurrentWeather?) -> WeatherCondition {
        guard let w = w else { return .clear }
        switch w.condition {
        case .clear, .mostlyClear:           return .clear
        case .cloudy, .mostlyCloudy, .partlyCloudy: return .cloudy
        case .rain, .heavyRain, .drizzle:    return .rain
        case .snow, .heavySnow, .flurries:   return .snow
        default:
            if w.temperature.converted(to: .celsius).value >= 32 { return .hot }
            if w.temperature.converted(to: .celsius).value <= 5  { return .cold }
            return .cloudy
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { await MainActor.run { self.fetchWeather() } }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        // 拿到位置后下一次 timer 触发会查天气
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) { }
}
