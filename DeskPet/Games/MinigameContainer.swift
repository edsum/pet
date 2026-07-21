import SwiftUI
import SpriteKit

/// 小游戏的 SwiftUI 通用包装：负责显示 SKScene + 处理触摸 + 顶部 HUD
struct MinigameContainer<Scene: MinigameScene>: View {

    @StateObject var hud = MinigameHUD()
    let scene: Scene
    var onEnd: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            hudBar

            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = toScene(value.location, in: sceneSize)
                            if value.translation.width == 0 && value.translation.height == 0 {
                                scene.handleTouch(at: p)
                            } else {
                                scene.handleDrag(from: toScene(value.startLocation, in: sceneSize),
                                                 to: p)
                            }
                        }
                )
                .background(GeometryReader { proxy in
                    Color.clear.onAppear { scene.size = proxy.size; sceneSize = proxy.size }
                })
        }
        .background(Color.black.opacity(0.05))
        .onAppear {
            scene.onScoreChange = { hud.score = $0 }
            scene.onTimeChange  = { hud.timeLeft = $0 }
            scene.onGameEnd     = { onEnd($0) }
            scene.startGame()
        }
        .onDisappear { scene.endGame() }
    }

    @State private var sceneSize: CGSize = .zero

    private func toScene(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x, y: size.height - p.y)
    }

    private var hudBar: some View {
        HStack {
            Label("\(hud.score)", systemImage: "star.fill").font(.headline)
            Spacer()
            Label("\(Int(hud.timeLeft))s", systemImage: "clock")
                .font(.headline)
                .foregroundStyle(hud.timeLeft < 5 ? .red : .primary)
        }
        .padding()
        .background(.regularMaterial)
    }
}

@MainActor
final class MinigameHUD: ObservableObject {
    @Published var score: Int = 0
    @Published var timeLeft: TimeInterval = 30
}
