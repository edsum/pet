import WidgetKit
import SwiftUI
import DeskPetKit

// MARK: - Timeline Entry / Provider

struct PetEntry: TimelineEntry {
    let date: Date
    let state: PetState
}

struct PetTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, state: PetState.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        var state = currentSelectedPet()
        state.reconcile()
        SharedStore.saveState(state)
        completion(PetEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        var state = currentSelectedPet()
        state.reconcile()

        // 预演未来 6 小时，每 15 分钟一个 entry（覆盖昼夜/能量变化，不耗 reload 预算）
        var entries: [PetEntry] = []
        for i in 0..<24 {
            let t = Date.now.addingTimeInterval(TimeInterval(i) * 15 * 60)
            var s = state
            s.reconcile(now: t)
            entries.append(PetEntry(date: t, state: s))
        }
        SharedStore.saveState(state)

        let next = Date.now.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    /// ★ 多宠物支持：取 PetManager 选中的那只
    private func currentSelectedPet() -> PetState {
        let all = PetStorage.loadAll()
        guard !all.isEmpty else {
            return SharedStore.loadState()    // 兜底老数据
        }
        if let id = PetStorage.loadCurrentID(),
           let pet = all.first(where: { $0.petID == id }) {
            return pet
        }
        return all[0]
    }
}

// MARK: - 桌面主 Widget（systemSmall / medium / large）

struct HomePetWidget: Widget {
    let kind = "DeskPet.HomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetTimelineProvider()) { entry in
            HomePetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("桌宠")
        .description("一只陪你一起的电子宠物，会随充电、电量、昼夜变化。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct HomePetView: View {
    let entry: PetEntry
    @SwiftUI.Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.state
        ZStack {
            LinearGradient(colors: s.backgroundColors, startPoint: .top, endPoint: .bottom)

            switch family {
            case .systemSmall:
                VStack(spacing: 6) {
                    PetAvatarView(state: s, size: 80, disableAnimation: true)
                    Text(s.mood.line(personality: s.appearance.personality))
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

            case .systemMedium:
                HStack(spacing: 16) {
                    VStack {
                        PetAvatarView(state: s, size: 100, disableAnimation: true)
                        Text(s.name).font(.caption.bold()).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.mood.line(personality: s.appearance.personality))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        StatBarsView(stats: s.stats)
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()

            default: // systemLarge
                VStack(spacing: 12) {
                    PetAvatarView(state: s, size: 160, disableAnimation: true)
                    Text(s.mood.line(personality: s.appearance.personality))
                        .font(.headline).foregroundStyle(.white)
                    StatBarsView(stats: s.stats)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 16) {
                        Label("Lv.\(s.level)", systemImage: "star.fill")
                        Label("\(s.coins)", systemImage: "bitcoinsign.circle.fill")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                }
                .padding()
            }
        }
    }
}

// MARK: - 预览

#Preview(as: .systemMedium) {
    HomePetWidget()
} timeline: {
    PetEntry(date: .now, state: PetState.preview)
}
