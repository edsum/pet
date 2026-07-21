import SwiftUI
import Charts
import DeskPetKit

/// 统计图表页：用 Swift Charts 显示过去 30 天的互动记录
struct StatsView: View {

    @EnvironmentObject var vm: PetViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    overviewCards
                    dailyInteractionsChart
                    kindBreakdownChart
                    streakCard
                }
                .padding()
            }
            .navigationTitle("统计")
        }
        .onAppear { vm.refreshEventLog() }
    }

    // MARK: 数据

    private var summary: PetStatsSummary {
        let entries = vm.eventLog.filter { $0.petID == vm.state.petID }
        return StatsAggregator.summarize(entries: entries, for: vm.state.petID, days: 30)
    }

    // MARK: 顶部 4 张卡片

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: 12) {
            statCard(title: "总互动", value: summary.totalInteractions, icon: "hand.raised.fill", color: .blue)
            statCard(title: "喂食", value: summary.totalFeedings, icon: "fork.knife", color: .orange)
            statCard(title: "游戏", value: summary.totalGames, icon: "gamecontroller.fill", color: .purple)
            statCard(title: "升级", value: summary.totalLevelUps, icon: "star.fill", color: .yellow)
        }
    }

    private func statCard(title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Spacer()
            }
            Text("\(value)").font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 每日互动柱状图

    private var dailyInteractionsChart: some View {
        let data = last30DaysData()

        return VStack(alignment: .leading, spacing: 8) {
            Label("最近 30 天互动", systemImage: "chart.bar.fill")
                .font(.headline)
            Chart(data, id: \.day) { item in
                BarMark(
                    x: .value("日期", item.day, unit: .day),
                    y: .value("次数", item.count)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private struct DailyCount: Identifiable {
        let id = UUID()
        let day: Date
        let count: Int
    }

    /// 把 byDay 字典填充成连续 30 天（没数据的填 0），方便 Chart 显示
    private func last30DaysData() -> [DailyCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var data: [DailyCount] = []
        for i in (0..<30).reversed() {
            let day = cal.date(byAdding: .day, value: -i, to: today)!
            let count = summary.byDay[day] ?? 0
            data.append(DailyCount(day: day, count: count))
        }
        return data
    }

    // MARK: 类型分布

    private var kindBreakdownChart: some View {
        let data = summary.byKind
            .map { (kind: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return VStack(alignment: .leading, spacing: 8) {
            Label("互动类型分布", systemImage: "chart.pie.fill")
                .font(.headline)
            Chart(data, id: \.kind) { item in
                SectorMark(
                    angle: .value("次数", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("类型", item.kind.label))
            }
            .frame(height: 220)

            // 图例
            VStack(alignment: .leading, spacing: 4) {
                ForEach(data, id: \.kind) { item in
                    HStack {
                        Image(systemName: item.kind.icon).frame(width: 20)
                        Text(item.kind.label)
                        Spacer()
                        Text("\(item.count)").bold()
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 连续打卡

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("连续互动").font(.caption).foregroundStyle(.secondary)
                Text("\(summary.currentStreak) 天").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("最长 \(summary.longestStreak) 天").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: summary.currentStreak)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
