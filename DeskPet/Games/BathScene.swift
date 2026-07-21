import SpriteKit

/// 洗澡小游戏：在宠物身上画圈擦掉泡泡，30 秒内擦完越多分越高
final class BathScene: MinigameScene {

    private var petNode: SKNode!
    private var bubbles: [SKNode] = []

    /// 拖动累计角度，转满一圈 = 擦掉一个泡泡
    private var lastAngle: CGFloat? = nil
    private var accumulatedAngle: CGFloat = 0
    private let anglePerBubble: CGFloat = .pi * 2   // 转 1 圈擦 1 个

    override func onGameStart() {
        // 宠物（中央）
        let pet = SKLabelNode(text: "🐶")
        pet.fontSize = 120
        pet.verticalAlignmentMode = .center
        pet.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(pet)
        petNode = pet

        // 一圈泡泡（围在宠物身上）
        spawnBubbles(count: 8)
    }

    private func spawnBubbles(count: Int) {
        for i in 0..<count {
            let bubble = SKLabelNode(text: "🫧")
            bubble.fontSize = CGFloat.random(in: 32...52)
            bubble.verticalAlignmentMode = .center
            bubble.name = "bubble"
            bubble.position = CGPoint(
                x: petNode.position.x + CGFloat.random(in: -60...60),
                y: petNode.position.y + CGFloat.random(in: -60...60)
            )
            bubble.alpha = 0
            bubble.run(.fadeIn(withDuration: 0.3))
            addChild(bubble)
            bubbles.append(bubble)
        }
    }

    override func handleDrag(from start: CGPoint, to current: CGPoint) {
        let center = petNode.position
        let v = CGVector(dx: current.x - center.x, dy: current.y - center.y)
        let angle = atan2(v.dy, v.dx)

        if let last = lastAngle {
            var delta = angle - last
            if delta > .pi { delta -= .pi * 2 }
            if delta < -.pi { delta += .pi * 2 }
            accumulatedAngle += abs(delta)

            // 每转 N 圈擦掉一个泡泡
            if accumulatedAngle >= anglePerBubble {
                accumulatedAngle = 0
                popBubble()
            }

            // 画水珠拖尾（视觉反馈）
            spawnWaterTrail(at: current)
        }
        lastAngle = angle
    }

    override func handleTouch(at point: CGPoint) {
        lastAngle = nil
        accumulatedAngle = 0
    }

    private func popBubble() {
        guard let bubble = bubbles.first else { return }
        bubbles.removeFirst()

        // 爆开动画
        let pop = SKAction.scale(to: 1.6, duration: 0.1)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        bubble.run(.sequence([pop, fade, remove]))

        score += 10
        onScoreChange?(score)
        spawnFloat(text: "+10", at: bubble.position, color: .systemTeal)

        // 空了 → 再来一波
        if bubbles.isEmpty {
            run(.sequence([
                .wait(forDuration: 0.5),
                .run { [weak self] in self?.spawnBubbles(count: 10) }
            ]))
        }
    }

    private func spawnWaterTrail(at p: CGPoint) {
        let drop = SKLabelNode(text: "💧")
        drop.fontSize = CGFloat.random(in: 16...24)
        drop.verticalAlignmentMode = .center
        drop.position = p
        drop.alpha = 0.8
        addChild(drop)
        drop.run(.sequence([
            .moveBy(x: CGFloat.random(in: -10...10), y: -40, duration: 0.6),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    private func spawnFloat(text: String, at p: CGPoint, color: GameColor) {
        let label = SKLabelNode(text: text)
        label.fontColor = color
        label.fontSize = 20
        label.verticalAlignmentMode = .center
        label.position = p
        addChild(label)
        label.run(.sequence([
            .moveBy(x: 0, y: 40, duration: 0.7),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }
}
