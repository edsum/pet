import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// iOS ↔ watchOS 数据同步
///
/// iOS 端是 sender，watchOS 端是 receiver（单向推送当前宠物状态）
@MainActor
public final class WatchSync: NSObject {

    public static let shared = WatchSync()

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    private override init() {
        super.init()
    }

    public func activate() {
        #if canImport(WatchConnectivity)
        guard let session = session else { return }
        session.delegate = self
        session.activate()
        Logger.app.info("WatchSync: activated")
        #endif
    }

    /// 把当前宠物状态推送到 Watch
    public func push(state: PetState) {
        #if canImport(WatchConnectivity)
        guard let session = session, session.activationState == .activated else { return }
        guard session.isReachable else {
            // Watch 不在线 → 用 message data，等下次激活时送达
            do {
                let data = try JSONEncoder().encode(state)
                try session.updateApplicationContext(["pet": data])
            } catch {
                Logger.app.error("WatchSync push failed: \(error)")
            }
            return
        }
        // Watch 在线 → 立即送达
        do {
            let data = try JSONEncoder().encode(state)
            session.sendMessage(["pet": data], replyHandler: nil)
        } catch {
            Logger.app.error("WatchSync push failed: \(error)")
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchSync: WCSessionDelegate {

    nonisolated public func session(_ session: WCSession,
                                     activationDidCompleteWith activationState: WCSessionActivationState,
                                     error: Error?) {
        Logger.app.info("WatchSync activated: \(activationState.rawValue)")
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
