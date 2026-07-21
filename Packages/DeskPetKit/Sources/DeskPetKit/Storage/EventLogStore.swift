import Foundation

/// 事件日志持久化：用 App Groups 共享文件存储
///
/// 限制：
///   - 最多保留 1000 条（FIFO）
///   - 自动清理 90 天前的记录
public enum EventLogStore {

    private static var url: URL {
        SharedStore.containerURL.appendingPathComponent("eventLog.json")
    }

    private static let maxEntries = 1000
    private static let retentionDays = 90

    // MARK: 读写

    public static func loadAll() -> [PetEventLogEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PetEventLogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    public static func loadAll(forPet petID: UUID) -> [PetEventLogEntry] {
        loadAll().filter { $0.petID == petID }
    }

    @discardableResult
    public static func append(_ entry: PetEventLogEntry) -> [PetEventLogEntry] {
        var all = loadAll()
        all.append(entry)
        all = prune(all)
        save(all)
        return all
    }

    public static func save(_ entries: [PetEventLogEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: 清理

    private static func prune(_ entries: [PetEventLogEntry]) -> [PetEventLogEntry] {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        let recent = entries.filter { $0.timestamp >= cutoff }
        // 如果还是超量，截断到最近 maxEntries 条
        if recent.count > maxEntries {
            return Array(recent.suffix(maxEntries))
        }
        return recent
    }
}
