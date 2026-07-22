import Foundation

/// 多宠物存储：与 SharedStore 同目录，但独立文件
public enum PetStorage {

    private static var petsURL: URL {
        SharedStore.containerURL.appendingPathComponent("pets.json")
    }
    private static var currentIDURL: URL {
        SharedStore.containerURL.appendingPathComponent("currentPetID.txt")
    }
    /// 兼容老的单宠物文件（M7 之前的 petState.json）
    private static var legacyURL: URL {
        SharedStore.containerURL.appendingPathComponent("petState.json")
    }

    // MARK: 多宠物

    public static func loadAll() -> [PetState] {
        guard let data = try? Data(contentsOf: petsURL),
              let pets = try? JSONDecoder().decode([PetState].self, from: data) else {
            return []
        }
        return pets
    }

    public static func saveAll(_ pets: [PetState]) {
        guard let data = try? JSONEncoder().encode(pets) else { return }
        try? data.write(to: petsURL, options: .atomic)
    }

    // MARK: 当前选中

    public static func loadCurrentID() -> UUID? {
        guard let data = try? Data(contentsOf: currentIDURL),
              let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let uuid = UUID(uuidString: str) else { return nil }
        return uuid
    }

    public static func saveCurrentID(_ id: UUID) {
        try? id.uuidString.write(to: currentIDURL, atomically: true, encoding: .utf8)
    }

    /// Mutates the currently selected pet and persists both the multi-pet store
    /// and the legacy single-pet snapshot used by older widget code paths.
    @discardableResult
    public static func updateCurrent(_ transform: (inout PetState) -> Void) -> PetState {
        var pets = loadAll()

        if pets.isEmpty {
            var state = loadLegacySinglePet() ?? SharedStore.loadState()
            transform(&state)
            saveAll([state])
            saveCurrentID(state.petID)
            SharedStore.saveState(state)
            return state
        }

        let selectedID = loadCurrentID()
        let index = selectedID.flatMap { id in pets.firstIndex { $0.petID == id } } ?? 0

        transform(&pets[index])
        saveAll(pets)
        saveCurrentID(pets[index].petID)
        SharedStore.saveState(pets[index])
        return pets[index]
    }

    // MARK: 兼容老数据

    /// 读老的单宠物格式（用于 M8 升级迁移）
    public static func loadLegacySinglePet() -> PetState? {
        guard FileManager.default.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              let pet = try? JSONDecoder().decode(PetState.self, from: data) else {
            return nil
        }
        return pet
    }

    /// 迁移成功后删除老文件
    public static func clearLegacy() {
        try? FileManager.default.removeItem(at: legacyURL)
    }
}
