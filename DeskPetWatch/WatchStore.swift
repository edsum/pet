import Foundation
import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import DeskPetKit

/// Watch 端数据存储：通过 WatchConnectivity 接收 iOS 推送的 PetState
@MainActor
final class WatchStore: ObservableObject {

    @Published private(set) var state: PetState = .preview
    @Published private(set) var lastUpdate: Date = .distantPast
    @Published private(set) var isOnline: Bool = false

    init() {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    func update(with newState: PetState) {
        state = newState
        lastUpdate = Date()
        Logger.app.info("Watch: received \(newState.name) lv=\(newState.level)")
    }
}

#if canImport(WatchConnectivity)
extension WatchStore: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith activationState: WCSessionActivationState,
                              error: Error?) {
        Task { @MainActor in self.isOnline = (activationState == .activated) }
    }

    /// iOS 端实时推送
    nonisolated func session(_ session: WCSession,
                              didReceiveMessage message: [String: Any]) {
        guard let data = message["pet"] as? Data,
              let pet = try? JSONDecoder().decode(PetState.self, from: data) else { return }
        Task { @MainActor in self.update(with: pet) }
    }

    /// iOS 端后台推送（Watch 不在线时缓存）
    nonisolated func session(_ session: WCSession,
                              didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["pet"] as? Data,
              let pet = try? JSONDecoder().decode(PetState.self, from: data) else { return }
        Task { @MainActor in self.update(with: pet) }
    }
}
#endif
