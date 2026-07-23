import SpriteKit
import DeskPetKit

#if canImport(UIKit)
import UIKit
internal typealias PetNodeColor = UIColor
#elseif canImport(AppKit)
import AppKit
internal typealias PetNodeColor = NSColor
#endif

/// 宠物角色节点：负责绘制形象、播放动画、响应手势。
///
/// 优先使用 AssetStore 里用户生成的形象帧图；没有素材时使用程序化绘制的
/// “萌芽熊”兜底形象，避免主舞台只出现一个简单圆脸。
final class PetNode: SKNode {

    // MARK: 配置

    let petID: UUID
    var mood: PetMood {
        didSet {
            guard oldValue != mood else { return }
            applyMood()
        }
    }

    /// ★ M9 进化形态
    var currentForm: PetForm = .baby {
        didSet {
            guard oldValue != currentForm else { return }
            applyForm()
        }
    }

    /// 节点显示尺寸（scene 坐标系）
    let baseSize: CGFloat = 168
    var size: CGFloat { baseSize * currentForm.sizeScale }

    // MARK: 内部节点

    private let bodyContainer = SKNode()
    private var imageNode: SKSpriteNode?

    private let leftEar: SKShapeNode
    private let rightEar: SKShapeNode
    private let leftFoot: SKShapeNode
    private let rightFoot: SKShapeNode
    private let shapeNode: SKShapeNode
    private let bellyNode: SKShapeNode
    private let leftArm: SKShapeNode
    private let rightArm: SKShapeNode
    private let leftEye: SKShapeNode
    private let rightEye: SKShapeNode
    private let mouth: SKShapeNode
    private let leftCheek: SKShapeNode
    private let rightCheek: SKShapeNode
    private let sproutStem: SKShapeNode
    private let sproutLeafLeft: SKShapeNode
    private let sproutLeafRight: SKShapeNode

    private let propLayer = SKNode()
    private let emotionLayer = SKNode()
    private var glowNode: SKShapeNode?

    // 眨眼状态
    private var blinkTimer: TimeInterval = 0
    private var nextBlinkIn: TimeInterval = 2.5
    private let ambientActionKey = "ambientIdleAction"
    private var ambientTimer: TimeInterval = 0
    private var nextAmbientIn: TimeInterval = Double.random(in: 5.5...9.0)

    // 是否正在被拖拽
    var isDragging: Bool = false {
        didSet {
            physicsBody?.isDynamic = !isDragging
            if isDragging {
                cancelAmbientAction(resetRotation: true)
            }
        }
    }

    // MARK: 初始化

    init(state: PetState) {
        self.petID = state.petID
        self.mood = state.mood
        self.currentForm = state.form

        let initialSize = baseSize
        var imgNode: SKSpriteNode?
        if let uiImage = AssetStore.loadFrame(mood: state.mood, petID: state.petID) {
            let texture = SKTexture(image: uiImage)
            imgNode = SKSpriteNode(texture: texture,
                                   size: CGSize(width: initialSize, height: initialSize))
            imgNode?.zPosition = 8
        }

        let bodyFill = PetNode.bodyColor(form: state.form, mood: state.mood)
        let accent = PetNodeColor(red: 1.00, green: 0.55, blue: 0.16, alpha: 1)
        let warmWhite = PetNodeColor.white.withAlphaComponent(0.78)

        leftEar = Self.makeOval(width: initialSize * 0.32,
                                height: initialSize * 0.46,
                                fill: bodyFill,
                                stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.45),
                                lineWidth: 3)
        rightEar = Self.makeOval(width: initialSize * 0.28,
                                 height: initialSize * 0.48,
                                 fill: bodyFill,
                                 stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.45),
                                 lineWidth: 3)
        leftFoot = Self.makeOval(width: initialSize * 0.24,
                                 height: initialSize * 0.17,
                                 fill: bodyFill,
                                 stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.36),
                                 lineWidth: 2)
        rightFoot = Self.makeOval(width: initialSize * 0.24,
                                  height: initialSize * 0.17,
                                  fill: bodyFill,
                                  stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.36),
                                  lineWidth: 2)
        shapeNode = Self.makeOval(width: initialSize * 1.02,
                                  height: initialSize * 1.22,
                                  fill: bodyFill,
                                  stroke: PetNodeColor.white.withAlphaComponent(0.90),
                                  lineWidth: 5)
        bellyNode = Self.makeOval(width: initialSize * 0.58,
                                  height: initialSize * 0.50,
                                  fill: warmWhite,
                                  stroke: PetNodeColor.clear,
                                  lineWidth: 0)
        leftArm = Self.makeOval(width: initialSize * 0.23,
                                height: initialSize * 0.54,
                                fill: bodyFill,
                                stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.34),
                                lineWidth: 2)
        rightArm = Self.makeOval(width: initialSize * 0.23,
                                 height: initialSize * 0.54,
                                 fill: bodyFill,
                                 stroke: PetNodeColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 0.34),
                                 lineWidth: 2)

        leftEye = SKShapeNode(circleOfRadius: 9)
        rightEye = SKShapeNode(circleOfRadius: 9)
        for eye in [leftEye, rightEye] {
            eye.fillColor = .black
            eye.strokeColor = .clear
            eye.zPosition = 6
        }

        mouth = SKShapeNode()
        mouth.strokeColor = .black
        mouth.lineWidth = 3
        mouth.lineCap = .round
        mouth.zPosition = 6

        leftCheek = SKShapeNode(circleOfRadius: 4.5)
        rightCheek = SKShapeNode(circleOfRadius: 4.5)
        for cheek in [leftCheek, rightCheek] {
            cheek.fillColor = accent.withAlphaComponent(0.72)
            cheek.strokeColor = .clear
            cheek.zPosition = 6
        }

        sproutStem = SKShapeNode()
        sproutStem.strokeColor = PetNodeColor(red: 0.36, green: 0.55, blue: 0.22, alpha: 1)
        sproutStem.lineWidth = 4
        sproutStem.lineCap = .round
        sproutStem.zPosition = 7

        sproutLeafLeft = Self.makeOval(width: initialSize * 0.18,
                                       height: initialSize * 0.10,
                                       fill: PetNodeColor(red: 0.80, green: 0.92, blue: 0.42, alpha: 1),
                                       stroke: PetNodeColor(red: 0.36, green: 0.55, blue: 0.22, alpha: 0.55),
                                       lineWidth: 2)
        sproutLeafRight = Self.makeOval(width: initialSize * 0.18,
                                        height: initialSize * 0.10,
                                        fill: PetNodeColor(red: 0.80, green: 0.92, blue: 0.42, alpha: 1),
                                        stroke: PetNodeColor(red: 0.36, green: 0.55, blue: 0.22, alpha: 0.55),
                                        lineWidth: 2)

        self.imageNode = imgNode

        super.init()

        addChild(bodyContainer)
        bodyContainer.addChild(leftEar)
        bodyContainer.addChild(rightEar)
        bodyContainer.addChild(leftFoot)
        bodyContainer.addChild(rightFoot)
        bodyContainer.addChild(shapeNode)
        bodyContainer.addChild(bellyNode)
        bodyContainer.addChild(leftArm)
        bodyContainer.addChild(rightArm)
        if let imgNode { bodyContainer.addChild(imgNode) }
        bodyContainer.addChild(leftEye)
        bodyContainer.addChild(rightEye)
        bodyContainer.addChild(mouth)
        bodyContainer.addChild(leftCheek)
        bodyContainer.addChild(rightCheek)
        bodyContainer.addChild(sproutStem)
        bodyContainer.addChild(sproutLeafLeft)
        bodyContainer.addChild(sproutLeafRight)
        bodyContainer.addChild(propLayer)
        bodyContainer.addChild(emotionLayer)

        layoutBodyParts()
        applyMood()
        configurePhysicsBody()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: 节点工厂

    private static func makeOval(width: CGFloat,
                                 height: CGFloat,
                                 fill: PetNodeColor,
                                 stroke: PetNodeColor,
                                 lineWidth: CGFloat) -> SKShapeNode {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let node = SKShapeNode(ellipseIn: rect)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        return node
    }

    private static func makeRoundedRect(width: CGFloat,
                                        height: CGFloat,
                                        radius: CGFloat,
                                        fill: PetNodeColor,
                                        stroke: PetNodeColor = .clear,
                                        lineWidth: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        return node
    }

    // MARK: 布局

    private func layoutBodyParts() {
        let bodyWidth = size * 1.02
        let bodyHeight = size * 1.22

        setOval(shapeNode, width: bodyWidth, height: bodyHeight)
        shapeNode.position = CGPoint(x: 0, y: -size * 0.04)
        shapeNode.zPosition = 2

        setOval(bellyNode, width: size * 0.58, height: size * 0.50)
        bellyNode.position = CGPoint(x: 0, y: -size * 0.26)
        bellyNode.zPosition = 3

        setOval(leftEar, width: size * 0.31, height: size * 0.45)
        leftEar.position = CGPoint(x: -size * 0.30, y: size * 0.42)
        leftEar.zRotation = 0.42
        leftEar.zPosition = 1

        setOval(rightEar, width: size * 0.27, height: size * 0.45)
        rightEar.position = CGPoint(x: size * 0.28, y: size * 0.45)
        rightEar.zRotation = -0.36
        rightEar.zPosition = 1

        setOval(leftFoot, width: size * 0.25, height: size * 0.16)
        leftFoot.position = CGPoint(x: -size * 0.23, y: -size * 0.67)
        leftFoot.zRotation = -0.06
        leftFoot.zPosition = 1

        setOval(rightFoot, width: size * 0.25, height: size * 0.16)
        rightFoot.position = CGPoint(x: size * 0.23, y: -size * 0.67)
        rightFoot.zRotation = 0.06
        rightFoot.zPosition = 1

        resetArms()

        let eyeY: CGFloat = size * 0.08
        let eyeX: CGFloat = size * 0.17
        leftEye.position = CGPoint(x: -eyeX, y: eyeY)
        rightEye.position = CGPoint(x: eyeX, y: eyeY)
        leftEye.setScale(max(0.8, size / baseSize))
        rightEye.setScale(max(0.8, size / baseSize))

        mouth.position = CGPoint(x: 0, y: -size * 0.11)

        leftCheek.position = CGPoint(x: -size * 0.30, y: size * 0.02)
        rightCheek.position = CGPoint(x: size * 0.30, y: size * 0.02)
        leftCheek.setScale(size / baseSize)
        rightCheek.setScale(size / baseSize)

        let stem = CGMutablePath()
        stem.move(to: CGPoint(x: 0, y: 0))
        stem.addQuadCurve(to: CGPoint(x: size * 0.03, y: size * 0.17),
                          control: CGPoint(x: -size * 0.04, y: size * 0.08))
        sproutStem.path = stem
        sproutStem.position = CGPoint(x: size * 0.22, y: size * 0.56)

        setOval(sproutLeafLeft, width: size * 0.18, height: size * 0.10)
        sproutLeafLeft.position = CGPoint(x: size * 0.20, y: size * 0.70)
        sproutLeafLeft.zRotation = 0.58
        sproutLeafLeft.zPosition = 7

        setOval(sproutLeafRight, width: size * 0.18, height: size * 0.10)
        sproutLeafRight.position = CGPoint(x: size * 0.31, y: size * 0.68)
        sproutLeafRight.zRotation = -0.55
        sproutLeafRight.zPosition = 7
    }

    private func setOval(_ node: SKShapeNode, width: CGFloat, height: CGFloat) {
        node.path = CGPath(ellipseIn: CGRect(x: -width / 2, y: -height / 2,
                                             width: width, height: height),
                           transform: nil)
    }

    private func resetArms() {
        setOval(leftArm, width: size * 0.23, height: size * 0.52)
        leftArm.position = CGPoint(x: -size * 0.48, y: -size * 0.15)
        leftArm.zRotation = -0.28
        leftArm.zPosition = 4

        setOval(rightArm, width: size * 0.23, height: size * 0.52)
        rightArm.position = CGPoint(x: size * 0.48, y: -size * 0.15)
        rightArm.zRotation = 0.28
        rightArm.zPosition = 4
    }

    private func configurePhysicsBody() {
        physicsBody = SKPhysicsBody(circleOfRadius: size * 0.48)
        physicsBody?.mass = 0.5
        physicsBody?.allowsRotation = false
        physicsBody?.angularVelocity = 0
        physicsBody?.angularDamping = 1.0
        physicsBody?.restitution = 0.28
        physicsBody?.friction = 0.7
        physicsBody?.linearDamping = 1.1
        physicsBody?.categoryBitMask = PetScene.Physics.pet.rawValue
        physicsBody?.collisionBitMask = PetScene.Physics.wall.rawValue
        physicsBody?.contactTestBitMask = PetScene.Physics.wall.rawValue
        zRotation = 0
    }

    // MARK: 形态切换（M9 进化）

    private func applyForm() {
        layoutBodyParts()
        configurePhysicsBody()

        if currentForm.hasGlow {
            if glowNode == nil {
                let glow = SKShapeNode(circleOfRadius: size * 0.72)
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
            let pulse = SKAction.sequence([
                .fadeAlpha(to: 0.4, duration: 0.8),
                .fadeAlpha(to: 0.9, duration: 0.8)
            ])
            glowNode?.run(.repeatForever(pulse), withKey: "glowPulse")
        } else {
            glowNode?.removeFromParent()
            glowNode = nil
        }

        applyMood()
        bodyContainer.run(.sequence([
            .scaleX(to: 1.10, y: 0.92, duration: 0.12),
            .scaleX(to: 0.96, y: 1.08, duration: 0.14),
            .scaleX(to: 1.0, y: 1.0, duration: 0.16)
        ]))
    }

    // MARK: 心情 -> 外观

    private func applyMood() {
        layoutBodyParts()
        propLayer.removeAllChildren()
        emotionLayer.removeAllChildren()
        leftArm.removeAllActions()
        rightArm.removeAllActions()
        sproutLeafLeft.removeAllActions()
        sproutLeafRight.removeAllActions()
        cancelAmbientAction(resetRotation: true)

        let fill = Self.bodyColor(form: currentForm, mood: mood)
        for node in [shapeNode, leftEar, rightEar, leftArm, rightArm, leftFoot, rightFoot] {
            node.fillColor = fill
        }

        let closed = mood == .sleeping || mood == .tired || mood == .sick
        leftEye.isHidden = closed
        rightEye.isHidden = closed
        mouth.isHidden = false
        mouth.path = mouthPath(for: mood)

        if let uiImage = AssetStore.loadFrame(mood: mood, petID: petID) {
            let imgNode = ensureImageNode(with: uiImage)
            imgNode.texture = SKTexture(image: uiImage)
            imgNode.isHidden = false
            setProceduralHidden(true)
        } else {
            imageNode?.isHidden = true
            setProceduralHidden(false)
        }

        switch mood {
        case .hungry:
            poseHandsToMouth()
            addBowl()
        case .eating:
            poseHandsToBelly()
            addBowl()
            addFloatingLabel("+饱腹", at: CGPoint(x: size * 0.08, y: size * 0.58),
                             color: PetNodeColor.systemOrange)
        case .dirty:
            addWaterDrops()
        case .happy, .excited:
            poseArmsUp()
            addFlowers()
        case .playing:
            poseAdventure()
            addMapAndGem()
        case .dancing:
            poseArmsUp()
            addMusicNotes()
            addHeadphones()
        case .sleeping, .sleepy, .tired:
            drawClosedEyes()
            addFloatingLabel("Zzz", at: CGPoint(x: size * 0.30, y: size * 0.48),
                             color: PetNodeColor.systemTeal)
        case .sick:
            drawClosedEyes()
            addFloatingLabel("+", at: CGPoint(x: size * 0.28, y: size * 0.42),
                             color: PetNodeColor.systemRed)
        case .quiet:
            drawClosedEyes()
            addFloatingLabel("...", at: CGPoint(x: size * 0.24, y: size * 0.42),
                             color: PetNodeColor.systemGray)
        case .sad:
            addFloatingLabel("低落", at: CGPoint(x: 0, y: size * 0.52),
                             color: PetNodeColor.systemBlue)
        case .curious:
            addFloatingLabel("?", at: CGPoint(x: size * 0.26, y: size * 0.46),
                             color: PetNodeColor.systemBlue)
        case .idle:
            break
        }
    }

    private func setProceduralHidden(_ hidden: Bool) {
        let nodes: [SKNode] = [
            leftEar, rightEar, leftFoot, rightFoot, shapeNode, bellyNode,
            leftArm, rightArm, leftEye, rightEye, mouth, leftCheek, rightCheek,
            sproutStem, sproutLeafLeft, sproutLeafRight
        ]
        nodes.forEach { $0.isHidden = hidden }
    }

    private func ensureImageNode(with image: PlatformImage) -> SKSpriteNode {
        if let imageNode { return imageNode }
        let node = SKSpriteNode(texture: SKTexture(image: image),
                                size: CGSize(width: size, height: size))
        node.zPosition = 8
        bodyContainer.addChild(node)
        imageNode = node
        return node
    }

    private func mouthPath(for mood: PetMood) -> CGPath {
        let path = CGMutablePath()
        let w: CGFloat = size * 0.18
        switch mood {
        case .happy, .excited, .playing:
            path.move(to: CGPoint(x: -w, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0),
                              control: CGPoint(x: 0, y: -w * 0.92))
        case .sad, .sick, .hungry, .dirty:
            path.move(to: CGPoint(x: -w, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0),
                              control: CGPoint(x: 0, y: w * 0.9))
        case .sleeping, .sleepy, .tired:
            path.addEllipse(in: CGRect(x: -w * 0.34, y: -w * 0.32,
                                       width: w * 0.68, height: w * 0.48))
        case .eating, .dancing:
            path.addEllipse(in: CGRect(x: -w * 0.48, y: -w * 0.42,
                                       width: w * 0.96, height: w * 0.78))
        case .quiet:
            path.move(to: CGPoint(x: -w * 0.45, y: 0))
            path.addLine(to: CGPoint(x: w * 0.45, y: 0))
        default:
            path.move(to: CGPoint(x: -w * 0.75, y: 0))
            path.addQuadCurve(to: CGPoint(x: w * 0.75, y: 0),
                              control: CGPoint(x: 0, y: -w * 0.55))
        }
        return path
    }

    private static func bodyColor(form: PetForm, mood: PetMood) -> PetNodeColor {
        let baseColor: PetNodeColor
        switch form {
        case .baby:
            baseColor = PetNodeColor(red: 0.99, green: 0.96, blue: 0.42, alpha: 1)
        case .teen:
            baseColor = PetNodeColor(red: 1.00, green: 0.88, blue: 0.42, alpha: 1)
        case .adult:
            baseColor = PetNodeColor(red: 1.00, green: 0.76, blue: 0.32, alpha: 1)
        case .ultimate:
            baseColor = PetNodeColor(red: 1.00, green: 0.86, blue: 0.00, alpha: 1)
        }

        switch mood {
        case .sick:
            return PetNodeColor.systemGray
        case .sleeping, .tired:
            return PetNodeColor(red: 0.74, green: 0.88, blue: 0.78, alpha: 1)
        case .dirty:
            return PetNodeColor(red: 0.84, green: 0.76, blue: 0.54, alpha: 1)
        default:
            return baseColor
        }
    }

    // MARK: 姿态

    private func poseHandsToMouth() {
        leftArm.position = CGPoint(x: -size * 0.24, y: size * 0.08)
        leftArm.zRotation = -0.98
        rightArm.position = CGPoint(x: size * 0.24, y: size * 0.08)
        rightArm.zRotation = 0.98
    }

    private func poseHandsToBelly() {
        leftArm.position = CGPoint(x: -size * 0.30, y: -size * 0.24)
        leftArm.zRotation = -0.56
        rightArm.position = CGPoint(x: size * 0.30, y: -size * 0.24)
        rightArm.zRotation = 0.56
    }

    private func poseArmsUp() {
        leftArm.position = CGPoint(x: -size * 0.46, y: size * 0.08)
        leftArm.zRotation = -0.88
        rightArm.position = CGPoint(x: size * 0.46, y: size * 0.08)
        rightArm.zRotation = 0.88
    }

    private func poseAdventure() {
        leftArm.position = CGPoint(x: -size * 0.44, y: -size * 0.03)
        leftArm.zRotation = -0.45
        rightArm.position = CGPoint(x: size * 0.44, y: size * 0.02)
        rightArm.zRotation = 0.72
    }

    // MARK: 每帧更新（呼吸 + 眨眼）

    func update(_ currentTime: TimeInterval, dt: TimeInterval) {
        guard !isDragging else { return }

        let speed = 1.0 / mood.breatheDuration
        let wave = sin(currentTime * .pi * speed)
        let amplitude = breathingAmplitude(for: mood)
        bodyContainer.yScale = 1.0 + amplitude * wave
        bodyContainer.xScale = 1.0 - amplitude * 0.45 * wave

        if mood != .sleeping && mood != .tired && mood != .sick {
            blinkTimer += dt
            if blinkTimer >= nextBlinkIn {
                blink()
                blinkTimer = 0
                nextBlinkIn = Double.random(in: 2.0...5.0)
            }
        }

        updateAmbientActions(dt: dt)
        let hasManualBodyAction = bodyContainer.hasActions()

        switch mood {
        case .excited, .playing, .dancing:
            let wiggle = sin(currentTime * .pi * 4) * 0.15
            bodyContainer.zRotation = wiggle
        default:
            if !hasManualBodyAction {
                bodyContainer.zRotation = 0
            }
        }

        if mood == .dancing {
            let wave = sin(currentTime * .pi * 5) * 0.16
            leftArm.zRotation = -0.88 + wave
            rightArm.zRotation = 0.88 - wave
        }
    }

    private func breathingAmplitude(for mood: PetMood) -> CGFloat {
        switch mood {
        case .idle, .quiet:
            return 0
        case .happy, .curious:
            return 0.003
        case .sleeping, .sleepy, .tired, .sick:
            return 0.007
        case .excited, .playing, .dancing:
            return 0.016
        default:
            return 0.006
        }
    }

    private func updateAmbientActions(dt: TimeInterval) {
        guard allowsAmbientActions else {
            ambientTimer = 0
            return
        }
        guard bodyContainer.action(forKey: ambientActionKey) == nil else { return }
        guard !bodyContainer.hasActions() else {
            ambientTimer = 0
            return
        }

        ambientTimer += dt
        guard ambientTimer >= nextAmbientIn else { return }

        ambientTimer = 0
        nextAmbientIn = Double.random(in: 6.0...12.0)
        playAmbientAction()
    }

    private func cancelAmbientAction(resetRotation: Bool) {
        bodyContainer.removeAction(forKey: ambientActionKey)
        ambientTimer = 0
        nextAmbientIn = Double.random(in: 5.5...9.0)
        if resetRotation {
            bodyContainer.zRotation = 0
        }
    }

    private var allowsAmbientActions: Bool {
        switch mood {
        case .idle, .happy, .curious, .quiet, .sleepy:
            return true
        default:
            return false
        }
    }

    private func playAmbientAction() {
        switch Int.random(in: 0..<5) {
        case 0:
            playAmbientLookAround()
        case 1:
            playAmbientTinyHop()
        case 2:
            playAmbientLeafStretch()
        case 3:
            playAmbientWave()
        default:
            playAmbientCuriousBubble()
        }
    }

    private func playAmbientLookAround() {
        let eyeShift = size * 0.026
        let eyeSequence = SKAction.sequence([
            .moveBy(x: eyeShift, y: 0, duration: 0.16),
            .wait(forDuration: 0.36),
            .moveBy(x: -eyeShift * 2, y: 0, duration: 0.22),
            .wait(forDuration: 0.30),
            .moveBy(x: eyeShift, y: 0, duration: 0.18)
        ])
        leftEye.run(eyeSequence)
        rightEye.run(eyeSequence)

        bodyContainer.run(.sequence([
            .rotate(toAngle: -0.045, duration: 0.18),
            .wait(forDuration: 0.38),
            .rotate(toAngle: 0.045, duration: 0.22),
            .wait(forDuration: 0.26),
            .rotate(toAngle: 0, duration: 0.18)
        ]), withKey: ambientActionKey)
    }

    private func playAmbientTinyHop() {
        bodyContainer.run(.sequence([
            .moveBy(x: 0, y: 8, duration: 0.14),
            .moveBy(x: 0, y: -8, duration: 0.18),
            .wait(forDuration: 0.12),
            .moveBy(x: 0, y: 4, duration: 0.10),
            .moveBy(x: 0, y: -4, duration: 0.12)
        ]), withKey: ambientActionKey)
    }

    private func playAmbientLeafStretch() {
        bodyContainer.run(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.18),
            .wait(forDuration: 0.38),
            .moveBy(x: 0, y: -5, duration: 0.20)
        ]), withKey: ambientActionKey)

        let leftLeaf = SKAction.sequence([
            .rotate(byAngle: 0.28, duration: 0.18),
            .wait(forDuration: 0.34),
            .rotate(byAngle: -0.28, duration: 0.20)
        ])
        let rightLeaf = SKAction.sequence([
            .rotate(byAngle: -0.28, duration: 0.18),
            .wait(forDuration: 0.34),
            .rotate(byAngle: 0.28, duration: 0.20)
        ])
        sproutLeafLeft.run(leftLeaf)
        sproutLeafRight.run(rightLeaf)
    }

    private func playAmbientWave() {
        bodyContainer.run(.wait(forDuration: 0.95), withKey: ambientActionKey)

        rightArm.run(.sequence([
            .rotate(byAngle: -0.35, duration: 0.12),
            .rotate(byAngle: 0.55, duration: 0.16),
            .rotate(byAngle: -0.55, duration: 0.16),
            .rotate(byAngle: 0.35, duration: 0.14)
        ]))

        if imageNode?.isHidden == false {
            addFloatingLabel("♪", at: CGPoint(x: size * 0.30, y: size * 0.48),
                             color: PetNodeColor.systemPurple)
        }
    }

    private func playAmbientCuriousBubble() {
        addFloatingLabel("?", at: CGPoint(x: size * 0.26, y: size * 0.48),
                         color: PetNodeColor.systemBlue)
        bodyContainer.run(.sequence([
            .rotate(toAngle: 0.055, duration: 0.16),
            .wait(forDuration: 0.46),
            .rotate(toAngle: 0, duration: 0.18)
        ]), withKey: ambientActionKey)
    }

    private func blink() {
        let close = SKAction.scaleY(to: 0.1, duration: 0.08)
        let open = SKAction.scaleY(to: 1.0, duration: 0.08)
        let seq = SKAction.sequence([close, open])
        leftEye.run(seq)
        rightEye.run(seq)
    }

    private func drawClosedEyes() {
        addEyeArc(x: -size * 0.16, y: size * 0.08)
        addEyeArc(x: size * 0.16, y: size * 0.08)
    }

    private func addEyeArc(x: CGFloat, y: CGFloat) {
        let path = CGMutablePath()
        let w = size * 0.09
        path.move(to: CGPoint(x: -w, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: 0),
                          control: CGPoint(x: 0, y: -w * 0.50))
        let arc = SKShapeNode(path: path)
        arc.strokeColor = .black
        arc.lineWidth = 3
        arc.lineCap = .round
        arc.position = CGPoint(x: x, y: y)
        arc.zPosition = 8
        emotionLayer.addChild(arc)
    }

    // MARK: 动作触发（由 Scene/ViewModel 调用）

    func jump() {
        cancelAmbientAction(resetRotation: true)
        guard let body = physicsBody else { return }
        body.applyImpulse(CGVector(dx: 0, dy: 280))
    }

    func nudge(dx: CGFloat, dy: CGFloat) {
        cancelAmbientAction(resetRotation: true)
        physicsBody?.applyImpulse(CGVector(dx: dx, dy: dy))
    }

    func reactPetted() {
        cancelAmbientAction(resetRotation: true)
        poseArmsUp()
        addFlowers()
        sproutLeafLeft.run(.sequence([
            .rotate(byAngle: 0.25, duration: 0.10),
            .rotate(byAngle: -0.25, duration: 0.18)
        ]))
        sproutLeafRight.run(.sequence([
            .rotate(byAngle: -0.25, duration: 0.10),
            .rotate(byAngle: 0.25, duration: 0.18)
        ]))
        bodyContainer.run(.sequence([
            .moveBy(x: 0, y: 14, duration: 0.10),
            .moveBy(x: 0, y: -14, duration: 0.16)
        ]))
    }

    func reactFed(food: Food) {
        cancelAmbientAction(resetRotation: true)
        mood = .eating
        addBowl()
        addFloatingLabel("+\(food.hungerBoost)", at: CGPoint(x: size * 0.12, y: size * 0.56),
                         color: PetNodeColor.systemOrange)
        bodyContainer.run(.sequence([
            .moveBy(x: 0, y: -5, duration: 0.10),
            .moveBy(x: 0, y: 9, duration: 0.14),
            .moveBy(x: 0, y: -4, duration: 0.12)
        ]))
    }

    func reactBathed() {
        cancelAmbientAction(resetRotation: true)
        mood = .happy
        addWaterDrops()
        addFloatingLabel("清洁", at: CGPoint(x: size * 0.20, y: size * 0.55),
                         color: PetNodeColor.systemCyan)
        bodyContainer.run(.sequence([
            .rotate(byAngle: 0.10, duration: 0.08),
            .rotate(byAngle: -0.20, duration: 0.12),
            .rotate(toAngle: 0, duration: 0.12)
        ]))
    }

    func reactExpedition() {
        cancelAmbientAction(resetRotation: true)
        mood = .playing
        addMapAndGem()
        bodyContainer.run(.sequence([
            .moveBy(x: 12, y: 8, duration: 0.14),
            .moveBy(x: -24, y: 0, duration: 0.18),
            .moveBy(x: 12, y: -8, duration: 0.14)
        ]))
    }

    func reactReward(text: String) {
        cancelAmbientAction(resetRotation: true)
        addGemBurst(text: text)
        bodyContainer.run(.sequence([
            .moveBy(x: 0, y: 10, duration: 0.10),
            .moveBy(x: 0, y: -10, duration: 0.16)
        ]))
    }

    func reactCharging() {
        cancelAmbientAction(resetRotation: true)
        mood = .eating
        addFloatingLabel("充能", at: CGPoint(x: size * 0.16, y: size * 0.58),
                         color: PetNodeColor.systemYellow)
        addChargeBolt()
    }

    func reactDenied() {
        cancelAmbientAction(resetRotation: true)
        addFloatingLabel("休息", at: CGPoint(x: size * 0.16, y: size * 0.55),
                         color: PetNodeColor.systemRed)
        bodyContainer.run(.sequence([
            .moveBy(x: -8, y: 0, duration: 0.06),
            .moveBy(x: 16, y: 0, duration: 0.10),
            .moveBy(x: -8, y: 0, duration: 0.08)
        ]))
    }

    // MARK: 道具层

    private func addBowl() {
        let bowl = Self.makeRoundedRect(width: size * 0.38,
                                        height: size * 0.18,
                                        radius: size * 0.07,
                                        fill: PetNodeColor(red: 0.62, green: 0.34, blue: 0.12, alpha: 1),
                                        stroke: PetNodeColor.white.withAlphaComponent(0.45),
                                        lineWidth: 2)
        bowl.position = CGPoint(x: -size * 0.05, y: -size * 0.60)
        bowl.zPosition = 9

        let rice = Self.makeOval(width: size * 0.28,
                                 height: size * 0.12,
                                 fill: PetNodeColor.white.withAlphaComponent(0.92),
                                 stroke: .clear,
                                 lineWidth: 0)
        rice.position = CGPoint(x: 0, y: size * 0.06)
        rice.zPosition = 10
        bowl.addChild(rice)
        propLayer.addChild(bowl)
    }

    private func addMapAndGem() {
        let map = Self.makeRoundedRect(width: size * 0.36,
                                       height: size * 0.24,
                                       radius: size * 0.04,
                                       fill: PetNodeColor(red: 0.83, green: 0.72, blue: 0.42, alpha: 1),
                                       stroke: PetNodeColor.white.withAlphaComponent(0.6),
                                       lineWidth: 2)
        map.position = CGPoint(x: size * 0.42, y: -size * 0.08)
        map.zRotation = -0.12
        map.zPosition = 9

        for offset in [-0.08, 0.05, 0.16] {
            let route = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -size * 0.12, y: size * CGFloat(offset)))
            path.addQuadCurve(to: CGPoint(x: size * 0.13, y: size * CGFloat(offset + 0.02)),
                              control: CGPoint(x: 0, y: size * CGFloat(offset + 0.06)))
            route.path = path
            route.strokeColor = PetNodeColor(red: 0.41, green: 0.50, blue: 0.31, alpha: 0.72)
            route.lineWidth = 1.8
            route.lineCap = .round
            route.zPosition = 10
            map.addChild(route)
        }

        let gem = makeDiamond(size: size * 0.14, color: PetNodeColor.systemCyan)
        gem.position = CGPoint(x: -size * 0.26, y: size * 0.45)
        gem.zPosition = 10

        propLayer.addChild(map)
        propLayer.addChild(gem)
    }

    private func addFlowers() {
        addFlower(at: CGPoint(x: -size * 0.46, y: size * 0.34), scale: 1.0)
        addFlower(at: CGPoint(x: size * 0.44, y: size * 0.25), scale: 0.78)
    }

    private func addFlower(at point: CGPoint, scale: CGFloat) {
        let flower = SKNode()
        flower.position = point
        flower.zPosition = 10
        let petalColor = PetNodeColor.white
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 3) {
            let petal = Self.makeOval(width: size * 0.07 * scale,
                                      height: size * 0.12 * scale,
                                      fill: petalColor,
                                      stroke: PetNodeColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 0.7),
                                      lineWidth: 1)
            petal.position = CGPoint(x: cos(angle) * size * 0.05 * scale,
                                     y: sin(angle) * size * 0.05 * scale)
            petal.zRotation = CGFloat(angle)
            flower.addChild(petal)
        }
        let center = SKShapeNode(circleOfRadius: size * 0.025 * scale)
        center.fillColor = PetNodeColor.systemYellow
        center.strokeColor = .clear
        center.zPosition = 11
        flower.addChild(center)
        flower.run(.sequence([.fadeIn(withDuration: 0.08), .wait(forDuration: 1.0),
                              .fadeOut(withDuration: 0.35), .removeFromParent()]))
        propLayer.addChild(flower)
    }

    private func addWaterDrops() {
        for i in 0..<5 {
            let drop = Self.makeOval(width: size * 0.06,
                                     height: size * 0.11,
                                     fill: PetNodeColor.systemCyan.withAlphaComponent(0.85),
                                     stroke: PetNodeColor.white.withAlphaComponent(0.5),
                                     lineWidth: 1)
            drop.position = CGPoint(x: CGFloat.random(in: -size * 0.38...size * 0.38),
                                    y: size * 0.40 + CGFloat(i) * 5)
            drop.zPosition = 10
            propLayer.addChild(drop)
            drop.run(.sequence([
                .wait(forDuration: Double(i) * 0.06),
                .group([
                    .moveBy(x: CGFloat.random(in: -10...10), y: -size * 0.40, duration: 0.8),
                    .fadeOut(withDuration: 0.8)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func addMusicNotes() {
        for (idx, text) in ["♪", "♫", "♪"].enumerated() {
            let note = makeLabel(text, size: size * 0.18, color: PetNodeColor.systemPurple)
            note.position = CGPoint(x: CGFloat(idx - 1) * size * 0.22,
                                    y: size * (0.50 + CGFloat(idx) * 0.05))
            note.zPosition = 10
            propLayer.addChild(note)
            note.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 10, duration: 0.45),
                .moveBy(x: 0, y: -10, duration: 0.45)
            ])))
        }
    }

    private func addHeadphones() {
        let arc = SKShapeNode()
        let path = CGMutablePath()
        let r = size * 0.32
        path.addArc(center: .zero, radius: r, startAngle: .pi * 0.15,
                    endAngle: .pi * 0.85, clockwise: false)
        arc.path = path
        arc.strokeColor = PetNodeColor.systemPurple
        arc.lineWidth = 5
        arc.lineCap = .round
        arc.position = CGPoint(x: 0, y: size * 0.16)
        arc.zPosition = 9
        propLayer.addChild(arc)
    }

    private func addChargeBolt() {
        let bolt = makeLabel("⚡︎", size: size * 0.25, color: PetNodeColor.systemYellow)
        bolt.position = CGPoint(x: -size * 0.32, y: size * 0.48)
        bolt.zPosition = 10
        propLayer.addChild(bolt)
        bolt.run(.sequence([
            .scale(to: 1.25, duration: 0.16),
            .scale(to: 1.0, duration: 0.16)
        ]))
    }

    private func addFloatingLabel(_ text: String, at point: CGPoint, color: PetNodeColor) {
        let label = makeLabel(text, size: max(15, size * 0.12), color: color)
        label.position = point
        label.zPosition = 12
        propLayer.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 22, duration: 0.9),
                    .fadeOut(withDuration: 0.9)]),
            .removeFromParent()
        ]))
    }

    private func addGemBurst(text: String) {
        let gem = makeDiamond(size: size * 0.18, color: PetNodeColor.systemCyan)
        gem.position = CGPoint(x: 0, y: size * 0.52)
        gem.zPosition = 11
        propLayer.addChild(gem)
        addFloatingLabel(text, at: CGPoint(x: size * 0.20, y: size * 0.54),
                         color: PetNodeColor.systemCyan)
        gem.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.18),
                    .rotate(byAngle: 0.55, duration: 0.18)]),
            .group([.scale(to: 1.0, duration: 0.16),
                    .fadeOut(withDuration: 0.55)]),
            .removeFromParent()
        ]))
    }

    private func makeDiamond(size: CGFloat, color: PetNodeColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: -size / 2, y: 0))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = PetNodeColor.white.withAlphaComponent(0.65)
        node.lineWidth = 2
        return node
    }

    private func makeLabel(_ text: String, size: CGFloat, color: PetNodeColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }
}
