import SpriteKit

/// 接球小游戏：拖动宠物接住下落的球，30 秒计分
///
/// - 普通球 🟠：+10 分
/// - 金球 🟡：+30 分（随机出现）
/// - 炸弹 💣：-20 分（要躲开）
final class CatchBallScene: MinigameScene {

    enum Physics: UInt32 {
        case pet = 0b0001
        case ball = 0b0010
    }

    private var petNode: SKSpriteNode!
    private var petRadius: CGFloat = 50
    private var spawnInterval: TimeInterval = 0.9
    private var gameSpawnTimer: TimeInterval = 0

    override func onGameStart() {
        physicsWorld.gravity = .zero          // 我们手动控制球的下落速度

        // 玩家操控的宠物（用 emoji，复用兜底形象思路）
        petNode = makeEmojiNode("🐱", size: petRadius * 2)
        petNode.position = CGPoint(x: size.width / 2, y: petRadius + 20)
        petNode.physicsBody = SKPhysicsBody(circleOfRadius: petRadius)
        petNode.physicsBody?.isDynamic = false
        petNode.physicsBody?.categoryBitMask = Physics.pet.rawValue
        petNode.physicsBody?.contactTestBitMask = Physics.ball.rawValue
        addChild(petNode)

        // 监听接触
        physicsWorld.contactDelegate = self
    }

    override func updateEachFrame(dt: TimeInterval) {
        gameSpawnTimer += dt
        // 难度递增：剩余时间越短，球出得越快
        let dynamicInterval = max(0.35, spawnInterval * (remaining / gameDuration))
        if gameSpawnTimer >= dynamicInterval {
            gameSpawnTimer = 0
            spawnBall()
        }

        // 清理掉到底的球
        for child in children where child.name == "ball" {
            if child.position.y < -50 {
                child.removeFromParent()
            }
        }
    }

    override func handleDrag(from start: CGPoint, to current: CGPoint) {
        // 只允许水平移动，限制在屏幕内
        let half = petRadius
        let x = min(max(current.x, half), size.width - half)
        petNode.position = CGPoint(x: x, y: petNode.position.y)
    }

    // MARK: 球生成

    private func spawnBall() {
        let roll = Int.random(in: 0..<10)
        let emoji: String
        let isBomb: Bool
        let isGold: Bool

        if roll == 0 {
            emoji = "💣"; isBomb = true; isGold = false
        } else if roll <= 2 {
            emoji = "⭐️"; isBomb = false; isGold = true
        } else {
            emoji = "🎾"; isBomb = false; isGold = false
        }

        let ball = makeEmojiNode(emoji, size: 44)
        ball.name = "ball"
        ball.position = CGPoint(x: CGFloat.random(in: 30...(size.width - 30)),
                                y: size.height + 30)
        ball.userData = ["isBomb": isBomb, "isGold": isGold]

        ball.physicsBody = SKPhysicsBody(circleOfRadius: 22)
        ball.physicsBody?.categoryBitMask = Physics.ball.rawValue
        ball.physicsBody?.contactTestBitMask = Physics.pet.rawValue
        ball.physicsBody?.collisionBitMask = 0
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: -250)

        addChild(ball)
    }

    private func makeEmojiNode(_ text: String, size: CGFloat) -> SKSpriteNode {
        // 用 SKLabelNode 渲染 emoji，转成 sprite
        let label = SKLabelNode(text: text)
        label.fontSize = size
        label.verticalAlignmentMode = .center
        return label.asSprite()
    }
}

// MARK: - 接触检测

extension CatchBallScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        let petMask = Physics.pet.rawValue
        let ballMask = Physics.ball.rawValue

        // 找出 ball 节点
        var ballNode: SKNode?
        if contact.bodyA.categoryBitMask == ballMask { ballNode = contact.bodyA.node }
        if contact.bodyB.categoryBitMask == ballMask { ballNode = contact.bodyB.node }
        guard (contact.bodyA.categoryBitMask == petMask || contact.bodyB.categoryBitMask == petMask),
              let ball = ballNode, ball.name == "ball" else { return }

        let isBomb = ball.userData?["isBomb"] as? Bool ?? false
        let isGold  = ball.userData?["isGold"] as? Bool ?? false

        ball.removeFromParent()

        if isBomb {
            score = max(0, score - 20)
            flash(color: .red)
            spawnFloat(text: "-20", at: petNode.position, color: .red)
        } else {
            let delta = isGold ? 30 : 10
            score += delta
            flash(color: isGold ? .systemYellow : .systemGreen)
            spawnFloat(text: "+\(delta)", at: petNode.position,
                       color: isGold ? .systemYellow : .systemGreen)
        }
        onScoreChange?(score)
    }

    private func flash(color: GameColor) {
        guard let view = view else { return }
        let flash = SKSpriteNode(color: color, size: view.bounds.size)
        flash.alpha = 0.3
        flash.zPosition = -10
        flash.position = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0, duration: 0.2), .removeFromParent()]))
    }

    private func spawnFloat(text: String, at p: CGPoint, color: GameColor) {
        let label = SKLabelNode(text: text)
        label.fontColor = color
        label.fontSize = 24
        label.position = p
        label.alpha = 1
        addChild(label)
        label.run(.sequence([
            .moveBy(x: 0, y: 60, duration: 0.8),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}

// MARK: - SKLabelNode 转 SKSpriteNode 工具

private extension SKLabelNode {
    func asSprite() -> SKSpriteNode {
        let node = SKSpriteNode()
        let view = SKView()
        let texture = view.texture(from: self)
        node.texture = texture
        node.size = self.frame.size
        return node
    }
}
