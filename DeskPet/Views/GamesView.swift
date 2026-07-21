import SwiftUI
import DeskPetKit

struct GamesView: View {

    @EnvironmentObject var vm: PetViewModel

    /// 当前激活的游戏（nil = 显示游戏列表）
    @State private var activeGame: Minigame?

    enum Minigame: String, CaseIterable, Identifiable {
        case catchBall, bathing, rhythm
        var id: String { rawValue }

        var title: String {
            switch self {
            case .catchBall: return "接球"
            case .bathing:   return "洗澡"
            case .rhythm:    return "节拍抚摸"
            }
        }
        var icon: String {
            switch self {
            case .catchBall: return "figure.disc.sports"
            case .bathing:   return "drop.degreesign.fill"
            case .rhythm:    return "music.note.list"
            }
        }
        var desc: String {
            switch self {
            case .catchBall: return "拖动宠物接住下落的球，躲开炸弹"
            case .bathing:   return "在宠物身上画圈，把泡泡擦掉"
            case .rhythm:    return "跟着节拍点对应的轨道"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let game = activeGame {
                    gameView(for: game)
                } else {
                    listContent
                }
            }
            .navigationTitle(activeGame == nil ? "互动" : activeGame!.title)
            .toolbar {
                if activeGame != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("返回") { activeGame = nil }
                    }
                }
            }
        }
    }

    // MARK: 列表

    private var listContent: some View {
        List {
            Section("投喂") {
                ForEach(Food.allCases, id: \.self) { food in
                    Button {
                        vm.feed(food)
                    } label: {
                        HStack {
                            Text(food.rawValue)
                            Spacer()
                            Text("+\(food.hungerBoost) 饱腹").font(.caption)
                            Text("💰\(food.price)").font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .disabled(vm.state.coins < food.price)
                }
            }

            Section("互动") {
                Button { vm.pet() } label: {
                    Label("摸摸头 (+8 心情)", systemImage: "hand.draw")
                }
                Button { vm.bathe() } label: {
                    Label("快速洗澡 (+40 清洁)", systemImage: "drop")
                }
            }

            Section("小游戏（30 秒一局）") {
                ForEach(Minigame.allCases) { game in
                    Button {
                        activeGame = game
                    } label: {
                        HStack {
                            Image(systemName: game.icon).frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(game.title).font(.body)
                                Text(game.desc).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: 游戏 View

    @ViewBuilder
    private func gameView(for game: Minigame) -> some View {
        switch game {
        case .catchBall:
            MinigameContainer(scene: CatchBallScene()) { score in
                vm.play(game: .catchBall, score: score)
                activeGame = nil
            }
        case .bathing:
            MinigameContainer(scene: BathScene()) { score in
                vm.play(game: .bathing, score: score)
                activeGame = nil
            }
        case .rhythm:
            MinigameContainer(scene: RhythmScene()) { score in
                vm.play(game: .petting, score: score)
                activeGame = nil
            }
        }
    }
}
