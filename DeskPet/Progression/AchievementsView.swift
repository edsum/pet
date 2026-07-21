import SwiftUI
import DeskPetKit

/// 成就列表页：分"已解锁"和"未解锁"两区
struct AchievementsView: View {

    @EnvironmentObject var vm: PetViewModel

    var body: some View {
        List {
            let unlocked = unlockedAchievements()
            let locked = lockedAchievements()

            Section("已解锁 \(unlocked.count)") {
                ForEach(unlocked) { ach in
                    achievementRow(ach, isUnlocked: true)
                }
            }

            Section("未解锁 \(locked.count)") {
                ForEach(locked) { ach in
                    achievementRow(ach, isUnlocked: false)
                }
            }
        }
        .navigationTitle("成就")
    }

    private func unlockedAchievements() -> [Achievement] {
        let ids = vm.progression.progress.achievements.unlockedIDs
        return AchievementLibrary.all.filter { ids.contains($0.id) }
    }

    private func lockedAchievements() -> [Achievement] {
        let ids = vm.progression.progress.achievements.unlockedIDs
        return AchievementLibrary.all.filter { !ids.contains($0.id) }
    }

    private func achievementRow(_ ach: Achievement, isUnlocked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ach.icon)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .foregroundStyle(isUnlocked ? .yellow : .gray.opacity(0.5))
                .background(isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1),
                            in: Circle())
                .symbolEffect(.pulse, options: isUnlocked ? .repeating : .nonRepeating)

            VStack(alignment: .leading, spacing: 4) {
                Text(ach.title).font(.headline)
                Text(ach.desc).font(.caption).foregroundStyle(.secondary)
                if !isUnlocked {
                    let current = currentMetricValue(ach.metric)
                    ProgressView(value: Double(current), total: Double(ach.goal))
                        .tint(Color.accentColor)
                        .frame(height: 6)
                    Text("\(current) / \(ach.goal)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .opacity(isUnlocked ? 1 : 0.7)
    }

    private func currentMetricValue(_ metric: Achievement.Metric) -> Int {
        let metrics = vm.currentMetrics()
        return metrics[metric] ?? 0
    }
}
