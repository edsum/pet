import SwiftUI
import DeskPetKit

/// 签到页：显示本月签到日历 + 连续天数 + 今日签到按钮
struct CheckInView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var showRewardToast = false
    @State private var todayReward: CheckInRecord.Reward?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakCard
                calendarCard
                rewardListCard
            }
            .padding()
        }
        .navigationTitle("每日签到")
        .overlay(alignment: .top) {
            if showRewardToast, let r = todayReward {
                rewardToast(r)
            }
        }
    }

    // MARK: 连续签到卡

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("已连续签到").font(.caption).foregroundStyle(.secondary)
                Text("\(vm.progression.progress.checkIn.currentStreak) 天")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("最长 \(vm.progression.progress.checkIn.longestStreak) 天")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 本月日历

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月签到").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(currentMonthDays(), id: \.self) { day in
                    dayCell(day)
                }
            }
            if vm.progression.canCheckInToday {
                Button {
                    checkInNow()
                } label: {
                    Label("今日签到", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            } else {
                Label("今日已签到，明天再来", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ day: Int) -> some View {
        let cal = Calendar.current
        guard let date = cal.date(from: cal.dateComponents([.year, .month], from: Date()))?
                .addingTimeInterval(TimeInterval(day - 1) * 86400) else {
            return AnyView(Text("\(day)").font(.caption).frame(height: 32))
        }
        let dayStart = cal.startOfDay(for: date)
        let isCheckedIn = vm.progression.progress.checkIn.records.contains { $0.date == dayStart }
        let isToday = cal.isDateInToday(date)
        let isFuture = date > Date()

        return AnyView(
            VStack(spacing: 2) {
                Text("\(day)").font(.caption2)
                Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(isCheckedIn ? .green : (isFuture ? .gray.opacity(0.3) : .gray))
            }
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(isToday ? Color.accentColor.opacity(0.2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
        )
    }

    private func currentMonthDays() -> [Int] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: Date()) ?? 1..<29
        return Array(range)
    }

    // MARK: 奖励说明

    private var rewardListCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连续签到奖励").font(.headline)
            ForEach(1...7, id: \.self) { day in
                let r = CheckInRules.reward(forDay: day)
                HStack {
                    Image(systemName: day == 7 ? "gift.fill" : "calendar")
                        .foregroundStyle(day == 7 ? .pink : .accentColor)
                    Text("第 \(day) 天").frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("+\(r.coins) 💰").foregroundStyle(.orange)
                    Text("+\(r.exp) EXP").foregroundStyle(.purple)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 签到动作

    private func checkInNow() {
        let reward = vm.progression.checkIn()
        // 同步奖励到宠物
        vm.state.coins += reward.coins
        vm.state.addExp(reward.exp)
        vm.persist()
        vm.refreshAchievements()

        todayReward = reward
        withAnimation { showRewardToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showRewardToast = false }
        }
    }

    private func rewardToast(_ r: CheckInRecord.Reward) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "gift.fill").font(.title)
            Text("签到成功！").font(.headline)
            Text("+\(r.coins) 💰  +\(r.exp) EXP").font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
