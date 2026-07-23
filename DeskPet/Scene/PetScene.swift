import SpriteKit
import DeskPetKit

#if canImport(UIKit)
import UIKit
internal typealias SceneColor = UIColor
#elseif canImport(AppKit)
import AppKit
internal typealias SceneColor = NSColor
#endif

/// 宠物住的场景：包含地面/墙壁物理边界、PetNode、粒子发射器
final class PetScene: SKScene {

    // MARK: 物理位掩码

    enum Physics: UInt32 {
        case pet  = 0b0001
        case wall = 0b0010
        case ball = 0b0100
    }

    // MARK: 节点

    private(set) var pet: PetNode?
    private let boundaryRoot = SKNode()
    private var groundLine: CGFloat = 0
    private var hasAppliedViewSize = false

    // MARK: 闭包（由 View 层注入）

    /// 手势回调（由 Scene 解析后通知 ViewModel）
    var onPet: (() -> Void)?
    var onJump: (() -> Void)?
    var onFeed: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    // MARK: 初始化

    func bootstrap(initial state: PetState) {
        if pet != nil {
            sync(state: state)
            return
        }

        physicsWorld.gravity = CGVector(dx: 0, dy: -560)      // 接近真实重力
        physicsWorld.contactDelegate = self
        scaleMode = .resizeFill
        backgroundColor = .clear
        if boundaryRoot.parent == nil {
            addChild(boundaryRoot)
        }

        let pet = PetNode(state: state)
        pet.position = CGPoint(x: size.width * 0.63, y: size.height * 0.52)
        pet.name = "pet"
        addChild(pet)
        self.pet = pet
        sync(state: state)

        addGroundAndWalls()
    }

    func resize(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        size = newSize
        addGroundAndWalls()

        guard let pet else { return }
        let half = pet.size / 2
        let needsRecentering = !hasAppliedViewSize
            || pet.position.x < half
            || pet.position.x > newSize.width - half
            || pet.position.y < half
            || pet.position.y > newSize.height - half

        if needsRecentering {
            pet.position = CGPoint(x: newSize.width * 0.63,
                                   y: newSize.height * 0.52)
            pet.physicsBody?.velocity = .zero
            hasAppliedViewSize = true
        }
    }

    // MARK: 边界

    private func addGroundAndWalls() {
        boundaryRoot.removeAllChildren()

        groundLine = max(76, min(size.height * 0.28, 176))
        let thickness: CGFloat = 60

        // 地面
        let ground = SKNode()
        ground.position = CGPoint(x: size.width / 2, y: groundLine - thickness / 2)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2,
                                                                height: thickness))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = Physics.wall.rawValue
        ground.physicsBody?.restitution = 0.2
        ground.addChild(makeVisualRect(color: .clear,
                                       size: CGSize(width: size.width * 2, height: thickness)))
        boundaryRoot.addChild(ground)

        // 左右墙
        for x in [0, size.width] {
            let wall = SKNode()
            wall.position = CGPoint(x: x, y: size.height / 2)
            wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: thickness,
                                                                  height: size.height * 2))
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.categoryBitMask = Physics.wall.rawValue
            boundaryRoot.addChild(wall)
        }
    }

    private func makeVisualRect(color: SceneColor, size: CGSize) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size)
        node.fillColor = color
        node.strokeColor = .clear
        return node
    }

    // MARK: 状态同步（每次 PetState 变化时由 ViewModel 调用）

    func sync(state: PetState) {
        guard let pet else { return }
        if pet.currentForm != state.form {
            pet.currentForm = state.form
        }
        if pet.mood != state.mood {
            pet.mood = state.mood
        }
    }

    // MARK: 输入：把 SwiftUI 手势坐标传进来

    func handleTap(at scenePoint: CGPoint) {
        guard let pet else { return }
        // 是否点中宠物
        let dx = scenePoint.x - pet.position.x
        let dy = scenePoint.y - pet.position.y
        let r = pet.size / 2
        if abs(dx) < r && abs(dy) < r {
            // 摸头
            pet.reactPetted()
            spawnHearts(at: scenePoint)
            onPet?()
        } else {
            // 朝点击位置走过去（给个推力）
            let dirX: CGFloat = dx > 0 ? 1 : -1
            pet.nudge(dx: dirX * 80, dy: 0)
        }
    }

    func performAffection() {
        guard let pet else { return }
        pet.reactPetted()
        spawnHearts(at: CGPoint(x: pet.position.x, y: pet.position.y + pet.size * 0.44))
    }

    func performFeeding(food: Food) {
        guard let pet else { return }
        pet.reactFed(food: food)
        spawnFood(at: CGPoint(x: pet.position.x - pet.size * 0.16,
                              y: pet.position.y - pet.size * 0.22))
    }

    func performBathing() {
        guard let pet else { return }
        pet.reactBathed()
        spawnSymbols(text: "💧",
                     at: CGPoint(x: pet.position.x, y: pet.position.y + pet.size * 0.36),
                     count: 5,
                     spread: 56)
    }

    func performExpedition() {
        guard let pet else { return }
        pet.reactExpedition()
        spawnStars(at: CGPoint(x: pet.position.x + pet.size * 0.20,
                               y: pet.position.y + pet.size * 0.28))
    }

    func performReward(text: String) {
        guard let pet else { return }
        pet.reactReward(text: text)
        spawnSymbols(text: "◆",
                     at: CGPoint(x: pet.position.x, y: pet.position.y + pet.size * 0.48),
                     count: 4,
                     spread: 40)
    }

    func performCharging() {
        guard let pet else { return }
        pet.reactCharging()
        spawnCharging(at: CGPoint(x: pet.position.x - pet.size * 0.22,
                                  y: pet.position.y + pet.size * 0.42))
    }

    func performDenied() {
        pet?.reactDenied()
    }

    func handleDoubleTap(at scenePoint: CGPoint) {
        guard let pet else { return }
        pet.jump()
        spawnStars(at: scenePoint)
        onJump?()
    }

    func handleLongPress(at scenePoint: CGPoint) {
        // 长按宠物 → 喂食
        spawnFood(at: scenePoint)
        onFeed?()
    }

    // MARK: 拖拽

    private var dragOffset: CGPoint = .zero

    func beginDrag(at scenePoint: CGPoint) {
        guard let pet else { return }
        let dx = scenePoint.x - pet.position.x
        let dy = scenePoint.y - pet.position.y
        let r = pet.size / 2
        guard abs(dx) < r && abs(dy) < r else { return }
        pet.isDragging = true
        dragOffset = CGPoint(x: dx, y: dy)
        onDragBegan?()
    }

    func updateDrag(at scenePoint: CGPoint) {
        guard let pet else { return }
        guard pet.isDragging else { return }
        pet.position = CGPoint(x: scenePoint.x - dragOffset.x,
                               y: scenePoint.y - dragOffset.y)
        pet.physicsBody?.velocity = .zero
    }

    func endDrag(at scenePoint: CGPoint, velocity: CGVector) {
        guard let pet else { return }
        guard pet.isDragging else { return }
        pet.isDragging = false
        // 投掷
        pet.physicsBody?.velocity = velocity
        onDragEnded?()
    }

    // MARK: 每帧

    private var lastTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        guard let pet else { return }
        let dt = lastTime == 0 ? 1.0/60 : currentTime - lastTime
        lastTime = currentTime
        pet.update(currentTime, dt: dt)
    }

    // MARK: 粒子工厂

    private func spawnHearts(at p: CGPoint) {
        spawnSymbols(text: "❤️", at: p, count: 5, spread: 40)
    }

    private func spawnStars(at p: CGPoint) {
        spawnSymbols(text: "✨", at: p, count: 8, spread: 60)
    }

    private func spawnFood(at p: CGPoint) {
        spawnSymbols(text: "🐟", at: p, count: 3, spread: 30)
    }

    /// 音乐音符（戴耳机时由 ViewModel 触发）
    func spawnNotes(at p: CGPoint) {
        spawnSymbols(text: "🎵", at: p, count: 4, spread: 50)
    }

    /// 充电时由 EventEngine 触发
    func spawnCharging(at p: CGPoint) {
        spawnSymbols(text: "⚡️", at: p, count: 5, spread: 40)
    }

    /// Zzz 粒子（睡觉时持续）
    func spawnZzz() {
        guard let pet else { return }
        guard pet.mood == .sleeping else { return }
        spawnSymbols(text: "💤", at: CGPoint(x: pet.position.x + 30,
                                             y: pet.position.y + pet.size/2),
                     count: 1, spread: 5)
    }

    /// 公开粒子工厂：让外部模块也能触发效果
    func spawnSymbols(text: String, at p: CGPoint, count: Int, spread: CGFloat) {
        spawnSymbolsImpl(text: text, at: p, count: count, spread: spread)
    }

    private func spawnSymbolsImpl(text: String, at p: CGPoint, count: Int, spread: CGFloat) {
        for i in 0..<count {
            let node = SKLabelNode(text: text)
            node.fontSize = 24
            node.position = CGPoint(x: p.x + CGFloat.random(in: -spread...spread),
                                    y: p.y + CGFloat.random(in: -spread/2...spread/2))
            node.alpha = 0
            addChild(node)

            let delay = Double(i) * 0.05
            let rise = SKAction.moveBy(x: CGFloat.random(in: -20...20),
                                       y: CGFloat.random(in: 60...100),
                                       duration: 1.2)
            let fadeIn = SKAction.fadeIn(withDuration: 0.2)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            node.run(.sequence([
                .wait(forDuration: delay),
                .group([rise, fadeIn]),
                fadeOut,
                remove
            ]))
        }
    }
}

// MARK: - 物理接触（落地反弹）

extension PetScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        guard let pet else { return }
        // 宠物落地时给一点旋转，让它"落地"更有趣
        let petMask = Physics.pet.rawValue
        let wallMask = Physics.wall.rawValue
        let touched = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        if touched == (petMask, wallMask) || touched == (wallMask, petMask) {
            let torque: CGFloat = CGFloat.random(in: -3...3)
            pet.physicsBody?.applyTorque(torque)
        }
    }
}
