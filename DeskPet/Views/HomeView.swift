import SwiftUI
import SpriteKit
import DeskPetKit

struct HomeView: View {

    @EnvironmentObject var vm: PetViewModel
    @Binding var showSwitcher: Bool

    var body: some View {
        let s = vm.state
        ZStack {
            LinearGradient(colors: s.backgroundColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topHUD

                // ★ SpriteKit 主舞台
                PetSceneView(scene: vm.scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: s.mood) { _, newMood in
                        vm.scene.sync(state: s)
                    }
                    .onChange(of: s.petID) { _, _ in
                        vm.scene.sync(state: s)
                    }

                bottomBar
            }
        }
        .overlay(DebugOverlay())
        .navigationTitle(s.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSwitcher = true
                } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
            }
        }
    }

    // MARK: 顶部 HUD

    private var topHUD: some View {
        HStack(spacing: 12) {
            Label("Lv.\(vm.state.level)", systemImage: "star.fill")
                .font(.subheadline.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Label(vm.state.mood.rawValue, systemImage: moodIcon(vm.state.mood))
                .font(.subheadline.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Label("\(vm.state.coins)", systemImage: "bitcoinsign.circle.fill")
                .font(.subheadline.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: 底部数值条 + 快捷按钮

    private var bottomBar: some View {
        VStack(spacing: 8) {
            StatBarsView(stats: vm.state.stats)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                actionButton(title: "摸摸", icon: "hand.draw") { vm.pet() }
                actionButton(title: "喂食", icon: "fork.knife") { vm.feed(.fish) }
                actionButton(title: "洗澡", icon: "drop") { vm.bathe() }
                actionButton(title: "接球", icon: "figure.play") { vm.play(game: .catchBall, score: 60) }
            }
        }
        .padding()
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
