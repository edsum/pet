import Foundation

/// 商店商品
public struct ShopItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let desc: String
    public let icon: String                // SF Symbol / emoji
    public let price: Int                  // 金币
    public let category: Category
    public let effect: Effect              // 购买后的效果
    public let requiredLevel: Int          // 等级门槛

    public enum Category: String, Codable, CaseIterable, Sendable, Hashable {
        case food          // 食物（一次性，立即加数值）
        case outfit        // 装扮（永久，存到外观）
        case background    // 背景（永久）
        case booster       // 增益（限时）
        case consumable    // 消耗品
    }

    /// 购买后效果
    public enum Effect: Codable, Equatable, Sendable, Hashable {
        case feed(hunger: Int, happiness: Int)
        case outfit(hat: String?, accessory: String?)
        case background(id: String)
        case heal(amount: Int)
        case energyBoost(amount: Int)
    }

    public init(id: String, name: String, desc: String, icon: String,
                price: Int, category: Category, effect: Effect,
                requiredLevel: Int = 1) {
        self.id = id; self.name = name; self.desc = desc; self.icon = icon
        self.price = price; self.category = category; self.effect = effect
        self.requiredLevel = requiredLevel
    }
}

/// 已购买的物品（永久装扮）
public struct OwnedItems: Codable, Equatable, Sendable {
    public var outfits: Set<String>      // 已拥有的装扮 ID
    public var backgrounds: Set<String>  // 已拥有的背景 ID
    public var consumables: [String: Int]  // 消耗品库存：itemID → 数量

    public static let initial = OwnedItems(outfits: [], backgrounds: ["default"], consumables: [:])
}

/// 商店库
public enum ShopLibrary {

    public static let all: [ShopItem] = [
        // MARK: 食物（一次性）
        .init(id: "food_fish",  name: "小鱼干",  desc: "+25 饱腹",
              icon: "🐟", price: 5,  category: .food,
              effect: .feed(hunger: 25, happiness: 2)),
        .init(id: "food_meat",  name: "鸡胸肉", desc: "+35 饱腹，+5 心情",
              icon: "🍗", price: 8,  category: .food,
              effect: .feed(hunger: 35, happiness: 5)),
        .init(id: "food_cake",  name: "蛋糕",   desc: "+20 饱腹，+15 心情",
              icon: "🍰", price: 15, category: .food,
              effect: .feed(hunger: 20, happiness: 15)),
        .init(id: "food_fruit", name: "水果拼盘", desc: "+15 饱腹，+10 心情",
              icon: "🍓", price: 10, category: .food,
              effect: .feed(hunger: 15, happiness: 10)),

        // MARK: 装扮（永久）
        .init(id: "hat_bow",        name: "蝴蝶结",  desc: "可爱加倍",
              icon: "🎀", price: 50,  category: .outfit,
              effect: .outfit(hat: "bow", accessory: nil)),
        .init(id: "hat_crown",      name: "小皇冠",  desc: "王者风范",
              icon: "👑", price: 200, category: .outfit,
              effect: .outfit(hat: "crown", accessory: nil),
              requiredLevel: 10),
        .init(id: "hat_party",      name: "派对帽",  desc: "派对动物",
              icon: "🥳", price: 80,  category: .outfit,
              effect: .outfit(hat: "party", accessory: nil)),
        .init(id: "acc_headphones", name: "耳机",    desc: "动感十足",
              icon: "🎧", price: 100, category: .outfit,
              effect: .outfit(hat: nil, accessory: "headphones")),
        .init(id: "acc_glasses",    name: "墨镜",    desc: "酷酷的",
              icon: "🕶️", price: 120, category: .outfit,
              effect: .outfit(hat: nil, accessory: "glasses")),

        // MARK: 背景（永久）
        .init(id: "bg_meadow", name: "草地",   desc: "阳光下的草地",
              icon: "🌱", price: 80,  category: .background,
              effect: .background(id: "meadow")),
        .init(id: "bg_space",  name: "太空",   desc: "星辰大海",
              icon: "🚀", price: 300, category: .background,
              effect: .background(id: "space"), requiredLevel: 15),
        .init(id: "bg_beach",  name: "海滩",   desc: "夏日沙滩",
              icon: "🏖️", price: 150, category: .background,
              effect: .background(id: "beach"), requiredLevel: 5),

        // MARK: 增益（消耗）
        .init(id: "boost_energy", name: "能量饮料", desc: "+40 体力",
              icon: "⚡️", price: 30, category: .booster,
              effect: .energyBoost(amount: 40)),
        .init(id: "boost_heal",   name: "药水",     desc: "+30 健康",
              icon: "💊", price: 50, category: .booster,
              effect: .heal(amount: 30)),
    ]
}
