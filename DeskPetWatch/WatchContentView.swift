import SwiftUI
import DeskPetKit

/// Watch 主界面：圆盘表盘 + 五项数值环
struct WatchContentView: View {

    @EnvironmentObject var store: WatchStore

    var body: some View {
        TabView {
            mainView
            statsView
            moodView
        }
        .tabViewStyle(.page)
    }

    // MARK: 第 1 页：宠物形象 + 状态

    private var mainView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(store.state.moodBackgroundColor)
                    .frame(width: 100, height: 100)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .symbolEffect(.bounce)

            Text(store.state.name)
                .font(.headline)

            Text(store.state.mood.line(personality: store.state.appearance.personality))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Label("Lv.\(store.state.level)", systemImage: "star.fill")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 4)
    }

    // MARK: 第 2 页：五项数值环

    private var statsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("数值").font(.caption.bold())
            ForEach(store.state.stats.asArray, id: \.label) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.icon).frame(width: 12)
                    Text(item.label).font(.caption2).frame(width: 30, alignment: .leading)
                    ProgressView(value: Double(item.value), total: 100)
                        .tint(item.value < 20 ? .red : (item.value < 50 ? .orange : .green))
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: 第 3 页：心情标签 + 同步时间

    private var moodView: some View {
        VStack(spacing: 8) {
            Image(systemName: moodIcon(store.state.mood))
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text(store.state.mood.rawValue)
                .font(.headline)

            if store.lastUpdate > Date.distantPast {
                Text("更新于")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(store.lastUpdate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func moodIcon(_ mood: PetMood) -> String {
        switch mood {
        case .happy, .excited:     return "face.smiling"
        case .sleeping, .tired:    return "moon.zzz"
        case .hungry:              return "fork.knife"
        case .sick:                return "cross.case"
        case .dirty:               return "drop"
        case .sad:                 return "face.dashed"
        case .eating:              return "mouth"
        case .playing:             return "party.popper"
        case .dancing:             return "music.note"
        case .quiet:               return "speaker.slash"
        default:                   return "pawprint"
        }
    }
}

// MARK: - PetMood 便捷背景色

extension PetMood {
    var moodBackgroundColor: Color {
        switch self {
        case .sleeping, .tired, .sick:   return Color(red: 0.16, green: 0.20, blue: 0.35)
        case .eating:                    return Color(red: 1.00, green: 0.70, blue: 0.40)
        case .playing, .excited, .dancing: return Color(red: 0.85, green: 0.75, blue: 1.00)
        case .hungry, .sad:              return Color(red: 0.70, green: 0.70, blue: 0.72)
        default:                          return Color(red: 0.70, green: 0.85, blue: 0.95)
        }
    }
}
