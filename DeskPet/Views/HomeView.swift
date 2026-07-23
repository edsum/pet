import SwiftUI
import SpriteKit
import DeskPetKit

struct HomeView: View {

    @EnvironmentObject var vm: PetViewModel
    @Binding var showSwitcher: Bool

    @State private var showAvatarGenerator = false
    @State private var toastMessage: String?
    @State private var toastID = UUID()

    @AppStorage("homeWidgetPreviewEnabled") private var widgetPreviewEnabled = true
    @AppStorage("homeWallpaperSceneEnabled") private var wallpaperSceneEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                fantasyBackground

                VStack(spacing: 0) {
                    resourceHeader

                    ZStack {
                        PetSceneView(scene: vm.scene)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: vm.state.mood) { _, _ in
                                vm.scene.sync(state: vm.state)
                            }
                            .onChange(of: vm.state.petID) { _, _ in
                                vm.scene.sync(state: vm.state)
                            }
                            .onChange(of: vm.state.form) { _, _ in
                                vm.scene.sync(state: vm.state)
                            }

                        VStack {
                            rewardBubbles
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 18)

                        sideRail
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 14)
                            .padding(.top, 46)

                        statusPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.leading, 14)
                            .padding(.bottom, 12)

                        VStack(alignment: .trailing, spacing: 12) {
                            modeToggles
                            adventureButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 14)
                        .padding(.bottom, 16)

                        VStack {
                            Spacer()
                            moodBanner
                                .padding(.bottom, 270)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    taskDock
                }

                if let toastMessage {
                    toastView(toastMessage)
                        .id(toastID)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAvatarGenerator) {
                GenerateAvatarView()
                    .environmentObject(vm)
            }
        }
    }

    // MARK: 背景

    private var fantasyBackground: some View {
        ZStack {
            LinearGradient(
                colors: wallpaperSceneEnabled ? [
                    Color(red: 0.74, green: 0.88, blue: 0.62),
                    Color(red: 0.88, green: 0.78, blue: 0.52),
                    Color(red: 0.57, green: 0.73, blue: 0.68)
                ] : vm.state.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                guard wallpaperSceneEnabled else { return }

                var trunk = Path()
                trunk.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.05))
                trunk.addCurve(to: CGPoint(x: size.width * 0.62, y: size.height * 0.62),
                               control1: CGPoint(x: size.width * 0.24, y: size.height * 0.25),
                               control2: CGPoint(x: size.width * 0.46, y: size.height * 0.18))
                context.stroke(trunk,
                               with: .color(Color.white.opacity(0.18)),
                               style: StrokeStyle(lineWidth: 36, lineCap: .round))

                var branch = Path()
                branch.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.02))
                branch.addCurve(to: CGPoint(x: size.width * 0.16, y: size.height * 0.52),
                                control1: CGPoint(x: size.width * 0.70, y: size.height * 0.20),
                                control2: CGPoint(x: size.width * 0.36, y: size.height * 0.12))
                context.stroke(branch,
                               with: .color(Color.brown.opacity(0.13)),
                               style: StrokeStyle(lineWidth: 24, lineCap: .round))
            }
            .ignoresSafeArea()

            LinearGradient(colors: [.clear, Color.white.opacity(0.32)],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
        }
    }

    // MARK: 顶部资源栏

    private var resourceHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("手机精灵")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)

                Spacer()

                Menu {
                    Button {
                        showToast("Widget 小组件已准备")
                    } label: {
                        Label("小组件", systemImage: "square.grid.2x2.fill")
                    }
                    Button {
                        showAvatarGenerator = true
                    } label: {
                        Label("生成形象", systemImage: "wand.and.stars")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.bold())
                        .frame(width: 44, height: 36)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                }

                Button {
                    showSwitcher = true
                } label: {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2)
                        .frame(width: 44, height: 36)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                resourceChip(icon: "bolt.fill", value: "\(vm.state.stats.energy)", tint: .yellow)
                resourceChip(icon: "diamond.fill", value: "\(vm.state.coins)", tint: .cyan)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func resourceChip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(minWidth: 66)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: 中部家园

    private var rewardBubbles: some View {
        HStack(spacing: 12) {
            rewardBubble(title: "+10", subtitle: "摸摸", icon: "hand.draw.fill") {
                vm.pet()
                showToast("摸摸成功，心情提升")
            }

            rewardBubble(title: "+15", subtitle: "洗澡", icon: "drop.fill") {
                vm.bathe()
                showToast("洗白白，清洁恢复")
            }

            rewardBubble(title: "+50", subtitle: "探险", icon: "map.fill") {
                startAdventure()
            }
        }
    }

    private func rewardBubble(title: String,
                              subtitle: String,
                              icon: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text(subtitle)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: 82, height: 82)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var moodBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: bannerIcon)
                .font(.headline)
            Text(bannerText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.70, green: 0.38, blue: 0.30).opacity(0.78),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private var bannerText: String {
        if vm.state.stats.hunger <= 20 { return "饥饿中.." }
        if vm.state.stats.energy <= 20 { return "有点困.." }
        if vm.state.mood == .playing { return "探险中.." }
        return vm.state.mood.rawValue
    }

    private var bannerIcon: String {
        if vm.state.stats.hunger <= 20 { return "takeoutbag.and.cup.and.straw.fill" }
        if vm.state.stats.energy <= 20 { return "moon.zzz.fill" }
        return moodIcon(vm.state.mood)
    }

    // MARK: 左侧状态面板

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.state.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
            }

            Text(explorationStatus)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            compactStat(label: "饥饿", value: 100 - vm.state.stats.hunger, color: .orange)
            compactStat(label: "心情", value: vm.state.stats.happiness, color: .pink)
            compactStat(label: "健康", value: vm.state.stats.health, color: .green)

            VStack(spacing: 8) {
                panelButton(title: "轮换精灵", icon: "person.2.fill") {
                    showSwitcher = true
                }

                panelButton(title: "更换精灵", icon: "wand.and.stars") {
                    showAvatarGenerator = true
                }
            }
            .padding(.top, 2)
        }
        .frame(width: 172, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.24),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.18), lineWidth: 1))
    }

    private var explorationStatus: String {
        if vm.state.stats.hunger <= 20 { return "饥饿探险暂停" }
        if vm.state.stats.energy < 12 { return "体力不足暂停" }
        return "家园探险待命"
    }

    private func compactStat(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(label): \(value)%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.20))
                    Capsule().fill(color.opacity(0.88))
                        .frame(width: proxy.size.width * CGFloat(max(0, min(value, 100))) / 100)
                }
            }
            .frame(height: 10)
        }
    }

    private func panelButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [
                    Color(red: 0.98, green: 0.77, blue: 0.26),
                    Color(red: 0.94, green: 0.56, blue: 0.18)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 右侧入口

    private var sideRail: some View {
        VStack(spacing: 2) {
            sideLink(title: "月卡", icon: "seal.fill") {
                EvolutionView()
            }

            sideLink(title: "背包", icon: "backpack.fill") {
                ShopView()
            }

            sideLink(title: "邮件", icon: "envelope.fill", badge: vm.progression.canCheckInToday ? 1 : 0) {
                CheckInView()
            }

            sideButton(title: "游戏中心", icon: "gamecontroller.fill") {
                vm.play(game: .catchBall, score: 60)
                showToast("接球训练完成")
            }

            sideButton(title: "限量抢购", icon: "alarm.fill", badge: 1) {
                showToast("商店装扮已上新")
            }
        }
    }

    private func sideLink<Destination: View>(title: String,
                                             icon: String,
                                             badge: Int = 0,
                                             @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            sideRailLabel(title: title, icon: icon, badge: badge)
        }
        .buttonStyle(.plain)
    }

    private func sideButton(title: String,
                            icon: String,
                            badge: Int = 0,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sideRailLabel(title: title, icon: icon, badge: badge)
        }
        .buttonStyle(.plain)
    }

    private func sideRailLabel(title: String, icon: String, badge: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.20), in: Circle())

                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red, in: Circle())
                        .offset(x: 2, y: -2)
                }
            }

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 54)
        }
        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
    }

    // MARK: 模式开关和探险

    private var modeToggles: some View {
        VStack(spacing: 8) {
            modeToggle(title: "挂件", isOn: $widgetPreviewEnabled)
            modeToggle(title: "壁纸", isOn: $wallpaperSceneEnabled)
        }
    }

    private func modeToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .leading)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .scaleEffect(0.82)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.18), in: Capsule())
    }

    private var adventureButton: some View {
        Button {
            startAdventure()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text("开始探险")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 112, height: 112)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: 底部任务卡

    private var taskDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                dockButton(title: "每日任务",
                           subtitle: "80能量",
                           icon: "checklist",
                           tint: .cyan) {
                    claimSupply()
                }

                dockButton(title: "免费抽",
                           subtitle: "再抽 1 次",
                           icon: "gift.fill",
                           tint: .green) {
                    let reward = vm.luckyDraw()
                    showToast("免费抽 +\(reward.coins) 能量石")
                }

                NavigationLink {
                    AchievementsView()
                } label: {
                    dockCard(title: "装扮收集",
                             subtitle: "\(ownedOutfitCount)/\(outfitTotal)",
                             icon: "tshirt.fill",
                             tint: .blue,
                             badge: unlockedBadge)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(.white.opacity(0.82))
    }

    private func dockButton(title: String,
                            subtitle: String,
                            icon: String,
                            tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            dockCard(title: title,
                     subtitle: subtitle,
                     icon: icon,
                     tint: tint,
                     badge: title == "每日任务" && vm.progression.canCheckInToday ? 1 : 0)
        }
        .buttonStyle(.plain)
    }

    private func dockCard(title: String,
                          subtitle: String,
                          icon: String,
                          tint: Color,
                          badge: Int = 0) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red, in: Circle())
                        .offset(x: 7, y: -7)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 160)
        .frame(minHeight: 68)
        .padding(.horizontal, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private var ownedOutfitCount: Int {
        vm.progression.progress.owned.outfits.count
    }

    private var outfitTotal: Int {
        ShopLibrary.all.filter { $0.category == .outfit }.count
    }

    private var unlockedBadge: Int {
        max(0, AchievementLibrary.all.count - vm.progression.progress.achievements.unlockedIDs.count)
    }

    // MARK: 事件

    private func claimSupply() {
        if let reward = vm.claimDailySupply() {
            showToast("每日补给 +\(reward.coins) 能量石")
        } else {
            showToast("今日补给已领取")
        }
    }

    private func startAdventure() {
        if let reward = vm.startExpedition() {
            showToast("探险完成 +\(reward.coins) 能量石")
        } else {
            showToast("体力或饱腹不足")
        }
    }

    private func showToast(_ message: String) {
        toastID = UUID()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(message)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.70),
                        in: Capsule())
            .padding(.top, 18)

            Spacer()
        }
    }

    private func moodIcon(_ mood: PetMood) -> String {
        switch mood {
        case .happy, .excited:     return "face.smiling"
        case .sleeping, .sleepy, .tired: return "moon.zzz.fill"
        case .hungry:              return "fork.knife"
        case .sick:                return "cross.case.fill"
        case .dirty:               return "drop.fill"
        case .sad:                 return "face.dashed"
        case .eating:              return "mouth.fill"
        case .playing:             return "map.fill"
        case .dancing:             return "music.note"
        case .quiet:               return "speaker.slash.fill"
        case .curious:             return "questionmark.circle.fill"
        case .idle:                return "pawprint.fill"
        }
    }
}
