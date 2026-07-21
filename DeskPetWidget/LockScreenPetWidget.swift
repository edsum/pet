import WidgetKit
import SwiftUI
import DeskPetKit

// MARK: - 锁屏 Widget（accessoryCircular / accessoryRectangular）

struct LockScreenPetWidget: Widget {
    let kind = "DeskPet.LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            LockScreenPetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("桌宠·锁屏")
        .description("锁屏也能看见你的小宠物。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenPetView: View {
    let entry: PetEntry
    @SwiftUI.Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.state
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                PetAvatarView(state: s, size: 60, disableAnimation: true)
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PetAvatarView(state: s, size: 36, disableAnimation: true)
                VStack(alignment: .leading) {
                    Text(s.name).font(.caption.bold())
                    Text(s.mood.line()).font(.caption2)
                }
            }
        default:
            Text("🐾 \(s.name)")
        }
    }
}

#Preview(as: .accessoryCircular) {
    LockScreenPetWidget()
} timeline: {
    PetEntry(date: .now, state: PetState.preview)
}
