import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// 统一日志：用 OSLog 后端，按子系统分类，便于 Console.app 过滤
///
/// 用法：
///   Logger.app.info("PetVM bootstrap")
///   Logger.widget.warn("budget exhausted")
public enum Logger {

    public static let subsystem = "com.yourname.deskpet"

    #if canImport(OSLog)

    public static let app      = LoggerBox(category: "app")
    public static let widget   = LoggerBox(category: "widget")
    public static let event    = LoggerBox(category: "event")
    public static let game     = LoggerBox(category: "game")
    public static let activity = LoggerBox(category: "activity")
    public static let perf     = LoggerBox(category: "perf")

    /// 包装 OSLog，提供 info/warn/error/debug 四档
    public final class LoggerBox: Sendable {
        private let log: OSLog
        init(category: String) {
            self.log = OSLog(subsystem: subsystem, category: category)
        }
        public func debug(_ msg: String)   { os_log("%{public}@", log: log, type: .debug, msg) }
        public func info(_ msg: String)    { os_log("%{public}@", log: log, type: .info, msg) }
        public func warn(_ msg: String)    { os_log("%{public}@", log: log, type: .default, msg) }
        public func error(_ msg: String)   { os_log("%{public}@", log: log, type: .error, msg) }
    }

    #else

    // 非 Apple 平台兜底（例如跑 macOS 测试时）
    public static let app      = LoggerBox(category: "app")
    public static let widget   = LoggerBox(category: "widget")
    public static let event    = LoggerBox(category: "event")
    public static let game     = LoggerBox(category: "game")
    public static let activity = LoggerBox(category: "activity")
    public static let perf     = LoggerBox(category: "perf")

    public final class LoggerBox: Sendable {
        private let category: String
        init(category: String) { self.category = category }
        public func debug(_ msg: String) { print("[\(category)] DEBUG  \(msg)") }
        public func info(_ msg: String)  { print("[\(category)] INFO   \(msg)") }
        public func warn(_ msg: String)  { print("[\(category)] WARN   \(msg)") }
        public func error(_ msg: String) { print("[\(category)] ERROR  \(msg)") }
    }

    #endif
}
