import WidgetKit
import SwiftUI
import DeskPetKit

// MARK: - StandBy Widget（iPhone 横屏充电时的床头柜模式）

/// StandBy 复用 HomePetWidget 的 medium 尺寸布局；
/// 系统在 StandBy 模式下会自动放大显示，所以单独提供一个 Widget 即可。
struct StandByPetWidget: Widget {
    let kind = "DeskPet.StandByWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            StandByPetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("桌宠·床头")
        .description("StandBy 模式下放在床头柜，宠物会陪你睡觉。")
        .supportedFamilies([.systemMedium])
    }
}

struct StandByPetView: View {
    let entry: PetEntry

    var body: some View {
        let s = entry.state
        ZStack {
            // 床头夜色背景
            LinearGradient(colors: [Color.black, Color(red: 0.10, green: 0.12, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)

            HStack(spacing: 24) {
                // 左：宠物形象（夜间默认睡觉动画）
                VStack(spacing: 8) {
                    PetAvatarView(state: s, size: 110, disableAnimation: true)
                    Text("💤")
                        .font(.system(size: 32))
                        .opacity(s.mood == .sleeping ? 1 : 0.2)
                }

                // 右：名字 + 时间
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(entry.date, style: .time)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(s.mood.line())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
        }
    }
}

#Preview(as: .systemMedium) {
    StandByPetWidget()
} timeline: {
    PetEntry(date: .now, state: {
        var s = PetState.preview
        s.mood = .sleeping
        return s
    }())
}
