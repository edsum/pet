import SpriteKit

/// 抚摸节奏游戏：跟着节拍点击宠物，30 秒计连击
///
/// 屏幕底部有 4 个节拍点（左/中左/中右/右），
/// 节拍圆环从顶部下落到判定线时点中对应位置 → 命中得分
final class RhythmScene: MinigameScene {

    enum Physics: Int { case note = 0b0001 }

    private let lanes = 4
    private var laneX: [CGFloat] = []
    private let judgeLineY: CGFloat = 120
    private let judgeWindow: CGFloat = 60      // 距判定线 60 点内都算命中

    private var spawnTimer: TimeInterval = 0
    private let baseSpawnInterval: TimeInterval = 0.8

    private var combo: Int = 0
    private var maxCombo: Int = 0

    override func onGameStart() {
        physicsWorld.gravity = .zero

        // 计算 4 条轨道 X 坐标
        let padding: CGFloat = 60
        let usable = size.width - padding * 2
        let step = usable / CGFloat(lanes - 1)
        laneX = (0..<lanes).map { padding + step * CGFloat($0) }

        // 判定线
        let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 4))
        line.fillColor = .systemGray
        line.strokeColor = .clear
        line.position = CGPoint(x: size.width / 2, y: judgeLineY)
        line.alpha = 0.4
        addChild(line)

        // 4 个轨道按钮（视觉提示）
        for (i, x) in laneX.enumerated() {
            let node = SKShapeNode(circleOfRadius: 28)
            node.fillColor = [.systemBlue, .systemPurple, .systemPink, .systemOrange][i]
            node.alpha = 0.4
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = CGPoint(x: x, y: judgeLineY)
            node.name = "lane-\(i)"
            addChild(node)
        }
    }

    override func updateEachFrame(dt: TimeInterval) {
        spawnTimer += dt
        // 难度递增：节拍越来越快
        let interval = max(0.35, baseSpawnInterval * (remaining / gameDuration))
        if spawnTimer >= interval {
            spawnTimer = 0
            spawnNote()
        }

        // 清理漏掉的音符
        for child in children where child.name == "note" {
            if child.position.y < judgeLineY - 100 {
                child.removeFromParent()
                miss()
            }
        }
    }

    override func handleTouch(at point: CGPoint) {
        // 离触摸点最近的轨道
        guard let (idx, _) = nearestLane(to: point) else { return }
        flashLane(idx)

        // 找该轨道上离判定线最近的 note
        guard let hit = nearestNote(inLane: idx) else {
            // 空打 → 断连击
            combo = 0
            return
        }

        let dy = abs(hit.position.y - judgeLineY)
        if dy <= judgeWindow {
            // 命中
            hit.removeFromParent()
            combo += 1
            maxCombo = max(maxCombo, combo)

            let delta: Int
            if dy < 20 {
                delta = 30               // perfect
                spawnFloat(text: "Perfect!", at: hit.position, color: .systemYellow)
            } else if dy < 40 {
                delta = 20               // great
                spawnFloat(text: "Great", at: hit.position, color: .systemGreen)
            } else {
                delta = 10               // good
                spawnFloat(text: "Good", at: hit.position, color: .systemTeal)
            }
            score += delta + combo       // 连击加成
            onScoreChange?(score)
        } else {
            // 太远 → 断连击
            combo = 0
        }
    }

    // MARK: 生成与查找

    private func spawnNote() {
        let lane = Int.random(in: 0..<lanes)
        let colors: [GameColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange]
        let note = SKShapeNode(circleOfRadius: 22)
        note.fillColor = colors[lane]
        note.strokeColor = .white
        note.lineWidth = 2
        note.position = CGPoint(x: laneX[lane], y: size.height + 30)
        note.name = "note"
        note.physicsBody = SKPhysicsBody(circleOfRadius: 22)
        note.physicsBody?.velocity = CGVector(dx: 0, dy: -300)
        note.physicsBody?.collisionBitMask = 0
        addChild(note)
    }

    private func nearestLane(to p: CGPoint) -> (Int, CGFloat)? {
        laneX.enumerated()
            .map { ($0.offset, abs($0.element - p.x)) }
            .min(by: { $0.1 < $1.1 })
    }

    private func nearestNote(inLane lane: Int) -> SKNode? {
        let targetX = laneX[lane]
        return children
            .filter { $0.name == "note" && abs($0.position.x - targetX) < 5 }
            .filter { $0.position.y > judgeLineY - 80 && $0.position.y < judgeLineY + 80 }
            .min(by: { abs($0.position.y - judgeLineY) < abs($1.position.y - judgeLineY) })
    }

    private func flashLane(_ idx: Int) {
        if let node = childNode(withName: "lane-\(idx)") {
            node.run(.sequence([
                .fadeAlpha(to: 1.0, duration: 0.05),
                .fadeAlpha(to: 0.4, duration: 0.2)
            ]))
        }
    }

    private func miss() {
        combo = 0
        spawnFloat(text: "Miss", at: CGPoint(x: size.width / 2, y: judgeLineY),
                   color: .systemRed)
    }

    private func spawnFloat(text: String, at p: CGPoint, color: GameColor) {
        let label = SKLabelNode(text: text)
        label.fontColor = color
        label.fontSize = 18
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
