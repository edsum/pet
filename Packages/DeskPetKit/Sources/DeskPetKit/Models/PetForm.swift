import Foundation

/// 宠物进化形态
///
/// 设计：3 阶进化（幼年 → 成年 → 终极）
/// 每阶段有不同体型、颜色、装饰
public enum PetForm: Int, Codable, CaseIterable, Sendable {
    case baby = 0      // Lv.1-4    幼年：小、圆、萌
    case teen = 1      // Lv.5-9    成长：变大，颜色加深
    case adult = 2     // Lv.10-19  成年：长出装饰（角/翅膀）
    case ultimate = 3  // Lv.20+    终极：发光，特效

    /// 根据等级返回当前形态
    public static func form(for level: Int) -> PetForm {
        switch level {
        case 0..<5:    return .baby
        case 5..<10:   return .teen
        case 10..<20:  return .adult
        default:       return .ultimate
        }
    }

    /// 升级到这个形态所需的等级
    public var requiredLevel: Int {
        switch self {
        case .baby:     return 1
        case .teen:     return 5
        case .adult:    return 10
        case .ultimate: return 20
        }
    }

    public var displayName: String {
        switch self {
        case .baby:     return "幼年"
        case .teen:     return "成长"
        case .adult:    return "成年"
        case .ultimate: return "终极"
        }
    }

    /// 形态对应的体型比例（用于 PetNode）
    public var sizeScale: CGFloat {
        switch self {
        case .baby:     return 0.75
        case .teen:     return 0.9
        case .adult:    return 1.0
        case .ultimate: return 1.1
        }
    }

    /// 形态对应的主色调（用于程序化绘制）
    public var bodyColor: String {
        switch self {
        case .baby:     return "#FFE4C4"      // 米白
        case .teen:     return "#FFD89C"      // 浅金
        case .adult:    return "#FFB347"      // 橙
        case .ultimate: return "#FFD700"      // 金色（终极）
        }
    }

    /// 是否带装饰
    public var hasAccessory: Bool {
        switch self {
        case .adult, .ultimate: return true   // 成年后有装饰
        default:                return false
        }
    }

    /// 是否带光晕（终极形态）
    public var hasGlow: Bool { self == .ultimate }
}

#if canImport(CoreGraphics)
import CoreGraphics
#endif
