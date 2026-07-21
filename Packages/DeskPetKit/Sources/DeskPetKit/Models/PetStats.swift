import Foundation

// MARK: - 五项基础数值

public struct PetStats: Codable, Equatable, Sendable {
    public var energy: Int       // 体力  0-100
    public var hunger: Int       // 饱腹  0-100（100 = 很饱）
    public var happiness: Int    // 心情  0-100
    public var cleanliness: Int  // 清洁  0-100
    public var health: Int       // 健康  0-100

    public init(energy: Int, hunger: Int, happiness: Int,
                cleanliness: Int, health: Int) {
        self.energy = energy; self.hunger = hunger
        self.happiness = happiness; self.cleanliness = cleanliness
        self.health = health
    }

    public static let initial = PetStats(
        energy: 80, hunger: 70, happiness: 80, cleanliness: 80, health: 100
    )

    /// 数值数组（用于 UI 进度条）
    public var asArray: [(label: String, value: Int, icon: String)] {
        [
            ("体力", energy, "bolt.fill"),
            ("饱腹", hunger, "fork.knife"),
            ("心情", happiness, "face.smiling"),
            ("清洁", cleanliness, "drop.fill"),
            ("健康", health, "heart.fill"),
        ]
    }
}

// MARK: - 工具：把数值钳到 0~100

@inlinable
public func clamp(_ v: Int, _ lo: Int = 0, _ hi: Int = 100) -> Int {
    min(max(v, lo), hi)
}
