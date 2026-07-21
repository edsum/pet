import SpriteKit
import DeskPetKit

#if canImport(UIKit)
import UIKit
internal typealias PetNodeColor = UIColor
#elseif canImport(AppKit)
import AppKit
internal typealias PetNodeColor = NSColor
#endif

/// 宠物角色节点：负责绘制形象、播放动画、响应手势
///
/// 优先使用 AssetStore 里用户生成的形象帧图；
/// 没有则用程序化绘制（一只圆滚滚的小生物 + 眨眼 + 嘴型随心情变），
/// 让 MVP 在没有素材时也能立刻看到效果。
final class PetNode: SKNode {

    // MARK: 配置

    let petID: UUID
    var mood: PetMood {
        didSet { applyMood() }
    }

    /// ★ M9 进化形态
    var currentForm: PetForm = .baby {
        didSet { applyForm() }
    }

    /// 节点显示尺寸（scene 坐标系）
    let baseSize: CGFloat = 160
    var size: CGFloat { baseSize * currentForm.sizeScale }

    // MARK: 内部节点

    private let bodyContainer = SKNode()        // 整体呼吸/旋转的容器
    private let imageNode: SKSpriteNode?        // 用户生成的形象（可选）
    private let shapeNode: SKShapeNode          // 程序化绘制的身体（兜底）
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let mouth: SKShapeNode
    private var glowNode: SKShapeNode?           // ★ 终极形态光晕

    // 眨眼状态
    private var blinkTimer: TimeInterval = 0
    private var nextBlinkIn: TimeInterval = 2.5

    // 是否正在被拖拽
    var isDragging: Bool = false {
        didSet {
            physicsBody?.isDynamic = !isDragging
        }
    }

    // MARK: 初始化

    init(state: PetState) {
        self.petID = state.petID
        self.mood = state.mood

        // ★ 先用 baseSize 作为初始尺寸（super.init 之前不能用计算属性 size）
        let initialSize = baseSize

        // 尝试加载用户生成的形象帧
        var imgNode: SKSpriteNode? = nil
        if let uiImage = AssetStore.loadFrame(mood: state.mood, petID: state.petID) {
            let texture = SKTexture(image: uiImage)
            imgNode = SKSpriteNode(texture: texture,
                                   size: CGSize(width: initialSize, height: initialSize))
            imgNode?.zPosition = 1
        }

        // 兜底：程序化绘制（圆滚滚身体）
        let radius = initialSize / 2
        let bodyShape = SKShapeNode(circleOfRadius: radius)
        bodyShape.fillColor = PetNodeColor.systemOrange
        bodyShape.strokeColor = PetNodeColor.white
        bodyShape.lineWidth = 4
        bodyShape.glowWidth = 0.5
        bodyShape.zPosition = 1

        // 眼睛
        let eyeRadius: CGFloat = 9
        leftEye = SKShapeNode(circleOfRadius: eyeRadius)
        rightEye = SKShapeNode(circleOfRadius: eyeRadius)
        for eye in [leftEye, rightEye] {
            eye.fillColor = .black
            eye.strokeColor = .clear
            eye.zPosition = 2
        }

        // 嘴
        mouth = SKShapeNode()
        mouth.strokeColor = .black
        mouth.lineWidth = 3
        mouth.lineCap = .round
        mouth.zPosition = 2

        self.imageNode = imgNode
        self.shapeNode = bodyShape

        super.init()

        addChild(bodyContainer)
        bodyContainer.addChild(bodyShape)
        if let img = imgNode { bodyContainer.addChild(img) }
        bodyContainer.addChild(leftEye)
        bodyContainer.addChild(rightEye)
        bodyContainer.addChild(mouth)

        layoutEyesAndMouth()
        applyMood()

        // 物理体：圆形碰撞，受重力
        physicsBody = SKPhysicsBody(circleOfRadius: radius * 0.85)
        physicsBody?.mass = 0.5
        physicsBody?.allowsRotation = true
        physicsBody?.restitution = 0.45         // 弹性
        physicsBody?.friction = 0.7
        physicsBody?.linearDamping = 0.6
        physicsBody?.categoryBitMask = PetScene.Physics.pet.rawValue
        physicsBody?.collisionBitMask = PetScene.Physics.wall.rawValue
        physicsBody?.contactTestBitMask = PetScene.Physics.wall.rawValue

        // ★ 应用初始形态
        applyForm()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: 布局

    private func layoutEyesAndMouth() {
        let eyeY: CGFloat = size * 0.08
        let eyeX: CGFloat = size * 0.18
        leftEye.position  = CGPoint(x: -eyeX, y: eyeY)
        rightEye.position = CGPoint(x:  eyeX, y: eyeY)
        mouth.position    = CGPoint(x: 0,     y: -size * 0.18)
    }

    // MARK: 形态切换（M9 进化）

    private func applyForm() {
        // 形态改变时：身体颜色、装饰、光晕
        let radius = size / 2
        bodyContainer.xScale = 1
        bodyContainer.yScale = 1

        // 终极形态：加光晕
        if currentForm.hasGlow {
            if glowNode == nil {
                let glow = SKShapeNode(circleOfRadius: radius * 1.3)
                glow.fillColor = .clear
                glow.strokeColor = PetNodeColor.systemYellow.withAlphaComponent(0.6)
                glow.lineWidth = 6
                glow.glowWidth = 8
                glow.zPosition = -1
                glow.name = "glow"
                addChild(glow)
                glowNode = glow
            }
            glowNode?.isHidden = false
            // 光晕脉动
            let pulse = SKAction.sequence([
                .fadeAlpha(to: 0.4, duration: 0.8),
                .fadeAlpha(to: 0.9, duration: 0.8)
            ])
            glowNode?.run(.repeatForever(pulse), withKey: "glowPulse")
        } else {
            glowNode?.removeFromParent()
            glowNode = nil
        }

        // 成年形态：身体更亮（applyMood 会重画）
        shapeNode.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                                    width: size, height: size),
                                  transform: nil)

        // 重新布局五官
        layoutEyesAndMouth()
        applyMood()

        // 进化动画
        let scaleUp = SKAction.sequence([
            .scaleX(to: 1.3, y: 1.3, duration: 0.2),
            .scaleX(to: 1.0, y: 1.0, duration: 0.3)
        ])
        bodyContainer.run(scaleUp)
    }

    // MARK: 心情 → 外观

    private func applyMood() {
        // 睡觉/疲倦 → 闭眼
        let closed = (mood == .sleeping || mood == .tired || mood == .sick)
        leftEye.isHidden  = closed
        rightEye.isHidden = closed

        // 嘴型随心情
        mouth.path = mouthPath(for: mood)

        // 身体颜色随心情微调
        shapeNode.fillColor = bodyColor(for: mood)

        // 切换形象帧（如果存在）
        if let imgNode = imageNode,
           let uiImage = AssetStore.loadFrame(mood: mood, petID: petID) {
            imgNode.texture = SKTexture(image: uiImage)
            imgNode.isHidden = false
            shapeNode.isHidden = true
            leftEye.isHidden = true
            rightEye.isHidden = true
            mouth.isHidden = true
        } else {
            imageNode?.isHidden = true
            shapeNode.isHidden = false
        }
    }

    private func mouthPath(for mood: PetMood) -> CGPath {
        let path = CGMutablePath()
        let w: CGFloat = size * 0.18
        switch mood {
        case .happy, .excited, .playing:
            // 笑（弧向上）
            path.move(to: CGPoint(x: -w, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0),
                              control: CGPoint(x: 0, y: -w * 0.9))
        case .sad, .sick, .hungry:
            // 哭/不开心（弧向下）
            path.move(to: CGPoint(x: -w, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0),
                              control: CGPoint(x: 0, y: w * 0.9))
        case .sleeping, .tired:
            // 小 o（呼吸感）
            path.addEllipse(in: CGRect(x: -w*0.4, y: -w*0.4, width: w*0.8, height: w*0.5))
        case .eating:
            // 大张嘴
            path.addEllipse(in: CGRect(x: -w*0.6, y: -w*0.5, width: w*1.2, height: w))
        case .dancing:
            // 唱歌 o
            path.addEllipse(in: CGRect(x: -w*0.5, y: -w*0.5, width: w, height: w*0.9))
        default:
            // 平嘴
            path.move(to: CGPoint(x: -w, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))
        }
        return path
    }

    private func bodyColor(for mood: PetMood) -> PetNodeColor {
        let form = currentForm
        // 基础色按形态
        let baseColor: PetNodeColor
        switch form {
        case .baby:     baseColor = PetNodeColor(red: 1.00, green: 0.89, blue: 0.77, alpha: 1)   // 米白
        case .teen:     baseColor = PetNodeColor(red: 1.00, green: 0.85, blue: 0.61, alpha: 1)   // 浅金
        case .adult:    baseColor = PetNodeColor(red: 1.00, green: 0.70, blue: 0.28, alpha: 1)   // 橙
        case .ultimate: baseColor = PetNodeColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1)   // 金色
        }
        // mood 影响：sick/.sleeping 覆盖为特殊色
        switch mood {
        case .sick:                  return .systemGray
        case .sleeping, .tired:      return .systemTeal
        default:                     return baseColor
        }
    }

    // MARK: 每帧更新（呼吸 + 眨眼）

    func update(_ currentTime: TimeInterval, dt: TimeInterval) {
        guard !isDragging else { return }

        // 呼吸：身体缩放正弦
        let speed = 1.0 / mood.breatheDuration
        let scale = 1.0 + 0.03 * sin(currentTime * .pi * speed)
        bodyContainer.yScale = scale
        bodyContainer.xScale = 2.0 - scale         // 反向，像呼吸

        // 眨眼：随机周期
        if mood != .sleeping && mood != .tired && mood != .sick {
            blinkTimer += dt
            if blinkTimer >= nextBlinkIn {
                blink()
                blinkTimer = 0
                nextBlinkIn = 2.0 + CGFloat.random(in: 0...3.0)
            }
        }

        // 摇摆：兴奋/玩耍/跳舞时
        switch mood {
        case .excited, .playing, .dancing:
            let wiggle = sin(currentTime * .pi * 4) * 0.15
            bodyContainer.zRotation = wiggle
        default:
            bodyContainer.zRotation = 0
        }
    }

    private func blink() {
        let close = SKAction.scaleY(to: 0.1, duration: 0.08)
        let open  = SKAction.scaleY(to: 1.0, duration: 0.08)
        let seq = SKAction.sequence([close, open])
        leftEye.run(seq)
        rightEye.run(seq)
    }

    // MARK: 动作触发（由 Scene 调用）

    func jump() {
        guard let body = physicsBody else { return }
        body.applyImpulse(CGVector(dx: 0, dy: 280))
    }

    func nudge(dx: CGFloat, dy: CGFloat) {
        physicsBody?.applyImpulse(CGVector(dx: dx, dy: dy))
    }

    /// 被摸头时的弹一下
    func reactPetted() {
        let up = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let down = SKAction.moveBy(x: 0, y: -10, duration: 0.1)
        bodyContainer.run(.sequence([up, down]))
    }
}
