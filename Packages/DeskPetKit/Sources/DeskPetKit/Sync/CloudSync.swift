import Foundation

/// iCloud 同步管理
///
/// 策略：
///   - 不用 NSPersistentCloudKitContainer（我们用 JSON 文件存储，不需要 CoreData）
///   - 改用 NSUbiquitousKeyValueStore 同步"小数据"（PetState）
///   - 形象帧图较大，用 NSFileProvider/CloudKit 文件同步（后续扩展）
///
/// 使用前：
///   1. 在 Capabilities 里开 iCloud → 勾选 "Key-Value Storage"
///   2. （可选）开 CloudKit 用于大文件同步
@MainActor
public final class CloudSync: NSObject {

    public static let shared = CloudSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let key = "petState.cloud.v1"
    private let lastSyncKey = "petState.cloud.lastSync"

    /// 是否启用（取决于用户是否登录 iCloud + 是否开了 capability）
    public private(set) var isEnabled = false

    /// 同步状态变化时通知 UI
    public var onSyncComplete: ((PetState) -> Void)?

    private override init() {
        super.init()
        // 检测 iCloud 可用性
        isEnabled = FileManager.default.ubiquityIdentityToken != nil
        guard isEnabled else {
            Logger.app.info("CloudSync: iCloud unavailable")
            return
        }

        // 监听远端变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(remoteChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
        Logger.app.info("CloudSync: enabled")
    }

    // MARK: 上传本地状态

    /// 把当前 PetState 推到 iCloud（每次本地变更后调用）
    public func upload(_ state: PetState) {
        guard isEnabled else { return }
        do {
            let data = try JSONEncoder().encode(state)
            // NSUbiquitousKVStore 只接受 Data/String 等基本类型
            store.set(data, forKey: key)
            store.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
            Logger.app.info("CloudSync: uploaded v=\(state.level) coins=\(state.coins)")
        } catch {
            Logger.app.error("CloudSync upload failed: \(error)")
        }
    }

    // MARK: 下载远端状态

    /// 从 iCloud 拉取最新状态（App 启动时调用）
    public func download() -> PetState? {
        guard isEnabled else { return nil }
        guard let data = store.data(forKey: key) else { return nil }
        do {
            let state = try JSONDecoder().decode(PetState.self, from: data)
            Logger.app.info("CloudSync: downloaded v=\(state.level)")
            return state
        } catch {
            Logger.app.error("CloudSync download failed: \(error)")
            return nil
        }
    }

    /// 启动时合并：取远端和本地较新的那个
    public func mergeWithLocal(_ local: PetState) -> PetState {
        guard isEnabled else { return local }
        guard let remote = download() else { return local }

        // 取 lastUpdate 更新的那个
        let merged = remote.lastUpdate > local.lastUpdate ? remote : local
        Logger.app.info("CloudSync: merged (remote=\(remote.lastUpdate) local=\(local.lastUpdate))")
        return merged
    }

    // MARK: 远端变化回调

    @objc nonisolated func remoteChanged(_ note: Notification) {
        Task { @MainActor in
            guard let state = self.download() else { return }
            Logger.app.info("CloudSync: external change received")
            self.onSyncComplete?(state)
        }
    }
}
