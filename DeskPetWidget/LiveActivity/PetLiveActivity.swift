import WidgetKit
import SwiftUI
import ActivityKit
import DeskPetKit

/// 宠物 Live Activity：锁屏卡片 + 灵动岛（紧凑/最小/扩展）
struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetActivityAttributes.self) { context in
            // 锁屏卡片
            LockScreenActivityView(context: context)
                .activityBackgroundTint(backgroundTint(context.attributes.kind))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 扩展态（长按）
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.kind.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percentText(context.state.progress))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.kind.verb)
                            .font(.headline)
                        Text(context.state.subtitle)
                            .font(.caption)
                        ProgressView(value: context.state.progress)
                            .tint(.white)
                            .frame(width: 180)
                    }
                    .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: context.attributes.kind.icon)
            } compactTrailing: {
                Text(percentText(context.state.progress))
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: context.attributes.kind.icon)
            }
            .keylineTint(.white)
        }
    }

    // MARK: 辅助

    private func percentText(_ p: Double) -> String {
        "\(Int(p * 100))%"
    }

    private func backgroundTint(_ kind: PetActivityAttributes.Kind) -> Color {
        switch kind {
        case .charging: return Color(red: 0.20, green: 0.60, blue: 0.30)
        case .bathing:  return Color(red: 0.20, green: 0.50, blue: 0.80)
        case .sleeping: return Color(red: 0.25, green: 0.20, blue: 0.45)
        case .stepGoal: return Color(red: 0.85, green: 0.45, blue: 0.20)
        }
    }
}

// MARK: - 锁屏卡片视图

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<PetActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // 左：图标 + 类型
            VStack(spacing: 6) {
                Image(systemName: context.attributes.kind.icon)
                    .font(.system(size: 36))
                Text(context.attributes.petName)
                    .font(.caption2)
            }
            .frame(width: 70)

            // 中：进度条 + 文案
            VStack(alignment: .leading, spacing: 8) {
                Text(context.attributes.kind.verb)
                    .font(.headline)
                Text(context.state.subtitle)
                    .font(.subheadline)
                ProgressView(value: context.state.progress)
                    .tint(.white)
            }

            // 右：百分比 / 详细
            VStack {
                Text(percentText(context.state.progress))
                    .font(.title.bold())
                if !context.state.detail.isEmpty {
                    Text(context.state.detail)
                        .font(.caption2)
                }
            }
            .frame(width: 60)
        }
        .padding()
        .foregroundStyle(.white)
    }

    private func percentText(_ p: Double) -> String {
        "\(Int(p * 100))%"
    }
}
