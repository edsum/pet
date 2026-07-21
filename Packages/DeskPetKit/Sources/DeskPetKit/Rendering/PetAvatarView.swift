import SwiftUI

// MARK: - 背景渐变色（按 mood 与时间）

public extension PetState {
    var backgroundColors: [Color] {
        switch mood {
        case .sleeping, .tired, .sick:  return [Color(red: 0.16, green: 0.20, blue: 0.35),
                                                Color(red: 0.08, green: 0.10, blue: 0.22)]
        case .eating:                   return [Color(red: 1.00, green: 0.85, blue: 0.55),
                                                Color(red: 1.00, green: 0.70, blue: 0.40)]
        case .playing, .excited, .dancing: return [Color(red: 1.00, green: 0.80, blue: 0.85),
                                                   Color(red: 0.85, green: 0.75, blue: 1.00)]
        case .hungry, .sad:             return [Color(red: 0.85, green: 0.85, blue: 0.85),
                                                Color(red: 0.70, green: 0.70, blue: 0.72)]
        default:                         return [Color(red: 0.85, green: 0.95, blue: 1.00),
                                                Color(red: 0.70, green: 0.85, blue: 0.95)]
        }
    }
}

// MARK: - 主形象视图（App 与 Widget 共用）

public struct PetAvatarView: View {

    public let state: PetState
    public var size: CGFloat = 120
    public var disableAnimation: Bool = false   // Widget 环境下关闭持续动画

    @State private var breathe: Bool = false

    public init(state: PetState, size: CGFloat = 120, disableAnimation: Bool = false) {
        self.state = state
        self.size = size
        self.disableAnimation = disableAnimation
    }

    public var body: some View {
        Group {
            if let img = AssetStore.loadFrame(mood: state.mood, petID: state.petID) {
                #if canImport(UIKit)
                Image(uiImage: img).resizable().scaledToFit()
                #else
                Image(nsImage: img).resizable().scaledToFit()
                #endif
            } else {
                // 兜底：SF Symbol 占位（首次生成形象前显示）
                ZStack {
                    Circle().fill(Color.orange.opacity(0.85))
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(breathe ? 1.04 : 1.0, anchor: .bottom)
        .rotationEffect(.degrees(breathe ? 1.5 : -1.5), anchor: .bottom)
        .onAppear {
            guard !disableAnimation else { return }
            withAnimation(.easeInOut(duration: state.mood.breatheDuration)
                            .repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - 数值条（UI 组件，App 与 Widget 都用）

public struct StatBarsView: View {
    public let stats: PetStats

    public init(stats: PetStats) { self.stats = stats }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(stats.asArray, id: \.label) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.icon).frame(width: 14)
                    Text(item.label).font(.caption2).frame(width: 28, alignment: .leading)
                    ProgressView(value: Double(item.value), total: 100)
                        .tint(color(of: item.value))
                }
            }
        }
    }

    private func color(of value: Int) -> Color {
        switch value {
        case 0..<20:   return .red
        case 20..<50:  return .orange
        default:       return .green
        }
    }
}
