import WidgetKit
import SwiftUI
import ActivityKit
import DeskPetKit

/// 宠物 Live Activity：锁屏卡片 + 灵动岛（紧凑/最小/扩展）
struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(backgroundTint(context.attributes.kind))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityPetAvatar(
                        state: activityPetState(from: context.state),
                        kind: context.attributes.kind,
                        isCharging: context.state.isCharging,
                        batteryPercent: context.state.batteryPercent,
                        size: 40
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(batteryText(context.state))
                            .font(.title3.bold())
                        Text(context.state.isCharging ? "充电中" : context.state.detail)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.kind.verb)
                            .font(.headline)
                        Text(context.state.subtitle)
                            .font(.caption)
                            .lineLimit(1)
                        ProgressView(value: context.state.progress)
                            .tint(context.state.isCharging ? chargeStageColor(context.state.batteryPercent) : .white)
                            .frame(width: 178)
                    }
                    .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: context.state.isCharging ? "bolt.fill" : context.attributes.kind.icon)
            } compactTrailing: {
                Text(batteryText(context.state))
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: context.state.isCharging ? "bolt.fill" : context.attributes.kind.icon)
            }
            .keylineTint(.white)
        }
    }

    private func batteryText(_ state: PetActivityAttributes.ContentState) -> String {
        if let batteryPercent = state.batteryPercent {
            return "\(batteryPercent)%"
        }
        return "--"
    }

    private func backgroundTint(_ kind: PetActivityAttributes.Kind) -> Color {
        switch kind {
        case .status: return Color(red: 0.28, green: 0.48, blue: 0.22)
        case .charging: return Color(red: 0.20, green: 0.60, blue: 0.30)
        case .bathing:  return Color(red: 0.20, green: 0.50, blue: 0.80)
        case .sleeping: return Color(red: 0.25, green: 0.20, blue: 0.45)
        case .stepGoal: return Color(red: 0.85, green: 0.45, blue: 0.20)
        case .expedition: return Color(red: 0.30, green: 0.45, blue: 0.22)
        }
    }
}

// MARK: - 锁屏卡片视图

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<PetActivityAttributes>

    var body: some View {
        let pet = activityPetState(from: context.state)

        HStack(spacing: 14) {
            VStack(spacing: 6) {
                ActivityPetAvatar(
                    state: pet,
                    kind: context.attributes.kind,
                    isCharging: context.state.isCharging,
                    batteryPercent: context.state.batteryPercent,
                    size: 64
                )
                Text(context.state.petName ?? pet.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 74)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.kind.verb)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(context.state.subtitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                ProgressView(value: context.state.progress)
                    .tint(context.state.isCharging ? chargeStageColor(context.state.batteryPercent) : .white)
                    .background(.white.opacity(0.15), in: Capsule())

                MetricsRow(state: context.state)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BatteryStatusColumn(state: context.state)
                .frame(width: 64)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
    }
}

private struct ActivityPetAvatar: View {
    let state: PetState
    let kind: PetActivityAttributes.Kind
    let isCharging: Bool
    let batteryPercent: Int?
    let size: CGFloat

    var body: some View {
        if isCharging {
            TimelineView(.periodic(from: .now, by: 0.35)) { timeline in
                avatarContent(tick: Int(timeline.date.timeIntervalSinceReferenceDate * 5))
            }
        } else {
            avatarContent(tick: 0)
        }
    }

    @ViewBuilder
    private func avatarContent(tick: Int) -> some View {
        let shake = isCharging ? shakeOffset(tick) : .zero

        ZStack {
            if isCharging {
                BottomLightningStrike(size: size, tick: tick)
            }

            PetAvatarView(state: displayState, size: size * 0.86, disableAnimation: true)
                .colorMultiply(isCharging ? chargeStageColor(batteryPercent) : .white)
                .overlay {
                    if isCharging {
                        Circle()
                            .fill(Color.red.opacity(redWashOpacity))
                            .frame(width: size * 0.72, height: size * 0.72)
                    }
                }
                .overlay {
                    if isCharging {
                        BodyElectricBolts(size: size * 0.76, tick: tick)
                    }
                }
                .offset(x: shake.width, y: shake.height)
                .rotationEffect(.degrees(isCharging ? Double(shake.width) * 1.7 : 0))
                .animation(.easeInOut(duration: 0.12), value: tick)

            if isCharging {
                Text(percentText)
                    .font(.system(size: max(8, size * 0.18), weight: .black))
                    .monospacedDigit()
                    .padding(.horizontal, max(4, size * 0.06))
                    .padding(.vertical, max(2, size * 0.025))
                    .background(.black.opacity(0.42), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
                    .offset(x: size * 0.23, y: -size * 0.34)
            } else {
                Image(systemName: kind.icon)
                    .font(.system(size: size * 0.20, weight: .bold))
                    .padding(size * 0.055)
                    .background(.black.opacity(0.32), in: Circle())
                    .offset(x: size * 0.27, y: -size * 0.30)
            }
        }
        .frame(width: size, height: size)
    }

    private var displayState: PetState {
        var pet = state
        if isCharging {
            pet.mood = .idle
        }
        return pet
    }

    private var percentText: String {
        guard let batteryPercent else { return "--" }
        return "\(batteryPercent)%"
    }

    private var redWashOpacity: Double {
        guard isCharging else { return 0 }
        return 0.40 * (1 - chargeStageProgress(batteryPercent))
    }

    private func shakeOffset(_ tick: Int) -> CGSize {
        let values: [CGFloat] = [-3.0, 2.5, -2.0, 3.5, -1.0, 0.5]
        let x = values[abs(tick) % values.count]
        let y = values[abs(tick / 2) % values.count] * 0.25
        return CGSize(width: x, height: y)
    }
}

private struct BottomLightningStrike: View {
    let size: CGFloat
    let tick: Int

    var body: some View {
        let active = tick % 3 != 1

        Path { path in
            path.move(to: CGPoint(x: size * 0.50, y: size * 1.04))
            path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.76))
            path.addLine(to: CGPoint(x: size * 0.55, y: size * 0.74))
            path.addLine(to: CGPoint(x: size * 0.45, y: size * 0.46))
            path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.66))
            path.addLine(to: CGPoint(x: size * 0.51, y: size * 0.58))
        }
        .trim(from: 0, to: active ? 1 : 0.45)
        .stroke(
            LinearGradient(colors: [.white, .yellow, .orange],
                           startPoint: .bottom,
                           endPoint: .top),
            style: StrokeStyle(lineWidth: max(2, size * 0.055), lineCap: .round, lineJoin: .round)
        )
        .shadow(color: .yellow.opacity(active ? 0.85 : 0.45), radius: active ? 7 : 3)
        .opacity(active ? 1 : 0.55)
    }
}

private struct BodyElectricBolts: View {
    let size: CGFloat
    let tick: Int

    var body: some View {
        ZStack {
            electricPath(points: [
                CGPoint(x: size * 0.16, y: size * 0.34),
                CGPoint(x: size * 0.34, y: size * 0.25),
                CGPoint(x: size * 0.29, y: size * 0.47),
                CGPoint(x: size * 0.48, y: size * 0.39)
            ])
            .opacity(tick % 2 == 0 ? 1 : 0.35)

            electricPath(points: [
                CGPoint(x: size * 0.64, y: size * 0.24),
                CGPoint(x: size * 0.50, y: size * 0.42),
                CGPoint(x: size * 0.70, y: size * 0.48),
                CGPoint(x: size * 0.58, y: size * 0.68)
            ])
            .opacity(tick % 3 == 0 ? 1 : 0.42)

            electricPath(points: [
                CGPoint(x: size * 0.24, y: size * 0.68),
                CGPoint(x: size * 0.40, y: size * 0.58),
                CGPoint(x: size * 0.47, y: size * 0.78),
                CGPoint(x: size * 0.63, y: size * 0.62)
            ])
            .opacity(tick % 3 == 1 ? 1 : 0.38)
        }
        .frame(width: size, height: size)
    }

    private func electricPath(points: [CGPoint]) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(.yellow, style: StrokeStyle(lineWidth: max(1.4, size * 0.034), lineCap: .round, lineJoin: .round))
        .overlay {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(.white, style: StrokeStyle(lineWidth: max(0.8, size * 0.016), lineCap: .round, lineJoin: .round))
        }
        .shadow(color: .yellow.opacity(0.8), radius: 3)
    }
}

private struct MetricsRow: View {
    let state: PetActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            if state.showSteps {
                MetricPill(icon: "figure.walk", text: stepsText)
            }
            if state.showWeather {
                MetricPill(icon: weatherIcon, text: weatherText)
            }
            MetricPill(icon: state.isCharging ? "bolt.fill" : batteryIcon, text: batteryText)
        }
    }

    private var stepsText: String {
        guard let steps = state.steps else { return "步 --" }
        if steps >= 10_000 {
            return String(format: "%.1f万步", Double(steps) / 10_000)
        }
        return "\(steps)步"
    }

    private var weatherText: String {
        state.weather ?? "天气--"
    }

    private var weatherIcon: String {
        let weather = state.weather ?? ""
        if weather.contains("雨") { return "cloud.rain.fill" }
        if weather.contains("雪") { return "snowflake" }
        if weather.contains("云") { return "cloud.fill" }
        if weather.contains("热") { return "sun.max.fill" }
        if weather.contains("冷") { return "thermometer.low" }
        if weather.contains("风") { return "wind" }
        return "sun.max.fill"
    }

    private var batteryText: String {
        guard let batteryPercent = state.batteryPercent else { return "电 --" }
        return "\(batteryPercent)%"
    }

    private var batteryIcon: String {
        guard let batteryPercent = state.batteryPercent else { return "battery.0" }
        switch batteryPercent {
        case 80...100: return "battery.100"
        case 50..<80: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }
}

private struct MetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        } icon: {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.16), in: Capsule())
    }
}

private struct BatteryStatusColumn: View {
    let state: PetActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 4) {
            if state.isCharging {
                ChargingPulse(size: 30)
            } else {
                Image(systemName: batteryIcon)
                    .font(.title3.weight(.bold))
            }

            Text(percentLine)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(state.isCharging ? "充电中" : rightDetail)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
    }

    private var percentLine: String {
        if let batteryPercent = state.batteryPercent {
            return "\(batteryPercent)%"
        }
        return "--"
    }

    private var rightDetail: String {
        state.detail.isEmpty ? "状态同步" : state.detail
    }

    private var batteryIcon: String {
        guard let batteryPercent = state.batteryPercent else { return "battery.0" }
        switch batteryPercent {
        case 80...100: return "battery.100"
        case 50..<80: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }
}

private struct ChargingPulse: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let pulse = Int(timeline.date.timeIntervalSinceReferenceDate) % 2 == 0
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.56, weight: .black))
                .foregroundStyle(.white, Color.yellow)
                .frame(width: size, height: size)
                .background(Color.green.opacity(pulse ? 0.96 : 0.58), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
                .scaleEffect(pulse ? 1.12 : 0.94)
                .opacity(pulse ? 1 : 0.82)
                .animation(.easeInOut(duration: 0.85), value: pulse)
        }
    }
}

private func activityPetState(from state: PetActivityAttributes.ContentState) -> PetState {
    if let petID = state.petID {
        let pets = PetStorage.loadAll()
        if let pet = pets.first(where: { $0.petID == petID }) {
            return pet
        }
    }
    return SharedStore.loadState()
}

private func chargeStageProgress(_ batteryPercent: Int?) -> Double {
    let percent = min(100, max(0, batteryPercent ?? 0))
    let bucket = (percent / 10) * 10
    return Double(bucket) / 100.0
}

private func chargeStageColor(_ batteryPercent: Int?) -> Color {
    let progress = chargeStageProgress(batteryPercent)
    return Color(
        red: 1.0,
        green: 0.18 + 0.82 * progress,
        blue: 0.16 + 0.84 * progress
    )
}
