import Foundation

/// 多宠物管理：一个 App 养多只宠物
///
/// - 维护 [PetState] 数组
/// - 追踪"当前选中的宠物"
/// - 通过 SharedStore 持久化到 App Groups（Widget 共享）
@MainActor
public final class PetManager: ObservableObject {

    @Published public private(set) var pets: [PetState] = []
    @Published public private(set) var currentPetID: UUID?

    private let storage = PetStorage.self
    private let maxPets = 5

    public init() {}

    // MARK: 加载

    public func load() {
        pets = PetStorage.loadAll()
        let savedID = PetStorage.loadCurrentID()
        currentPetID = pets.first(where: { $0.petID == savedID })?.petID ?? pets.first?.petID
        // 首次启动没有任何宠物 → 创建默认宠物
        if pets.isEmpty {
            let first = PetState(name: "小毛")
            pets = [first]
            currentPetID = first.petID
            saveAll()
        }
    }

    public var current: PetState? {
        guard let id = currentPetID else { return pets.first }
        return pets.first(where: { $0.petID == id })
    }

    // MARK: 增删

    /// 新增一只宠物（不超过上限）
    @discardableResult
    public func addPet(name: String,
                       appearance: PetAppearance = .default) -> PetState? {
        guard pets.count < maxPets else {
            Logger.app.warn("PetManager: max pets reached")
            return nil
        }
        var new = PetState(name: name, appearance: appearance)
        // 新宠物初始等级/数值与原宠物独立
        new.createdAt = Date()
        pets.append(new)
        currentPetID = new.petID
        saveAll()
        Logger.app.info("PetManager: added pet \(name) (total \(pets.count))")
        return new
    }

    /// 删除宠物（至少保留一只）
    public func removePet(id: UUID) {
        guard pets.count > 1 else {
            Logger.app.warn("PetManager: cannot remove the last pet")
            return
        }
        pets.removeAll { $0.petID == id }
        AssetStore.deleteAll(petID: id)
        if currentPetID == id {
            currentPetID = pets.first?.petID
        }
        saveAll()
    }

    /// 切换当前宠物
    public func switchTo(id: UUID) {
        guard pets.contains(where: { $0.petID == id }) else { return }
        currentPetID = id
        PetStorage.saveCurrentID(id)
        Logger.app.info("PetManager: switched to \(id)")
    }

    // MARK: 更新单只宠物

    public func update(_ state: PetState) {
        guard let idx = pets.firstIndex(where: { $0.petID == state.petID }) else { return }
        pets[idx] = state
        saveAll()
    }

    public func mutateCurrent(_ transform: (inout PetState) -> Void) {
        guard let id = currentPetID,
              let idx = pets.firstIndex(where: { $0.petID == id }) else { return }
        transform(&pets[idx])
        saveAll()
    }

    // MARK: 持久化

    private func saveAll() {
        PetStorage.saveAll(pets)
        if let id = currentPetID {
            PetStorage.saveCurrentID(id)
        }
    }

    // MARK: 兼容性：迁移老的 single-pet 数据

    /// 第一次升级到多宠物版本时，把旧的 petState.json 迁移成多宠物格式
    public func migrateFromSinglePetIfNeeded() {
        if PetStorage.loadAll().isEmpty {
            if let legacy = PetStorage.loadLegacySinglePet() {
                pets = [legacy]
                currentPetID = legacy.petID
                saveAll()
                Logger.app.info("PetManager: migrated 1 legacy pet")
            }
        }
    }
}
