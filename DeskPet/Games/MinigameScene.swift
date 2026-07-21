import SpriteKit
import DeskPetKit

#if canImport(UIKit)
import UIKit
internal typealias GameColor = UIColor
#elseif canImport(AppKit)
import AppKit
internal typealias GameColor = NSColor
#endif

/// 小游戏基类：统一的"开始/结束/计分/倒计时"骨架
///
/// 子类只需重写：
///   - `onGameStart()`：生成初始元素
///   - `updateEachFrame(dt:)`：每帧的逻辑（生成下落物等）
///   - `handleTouch(at:)`：处理一次触摸
///   - `handleDrag(from:to:)`：可选，处理拖拽
class MinigameScene: SKScene {

    // MARK: 配置

    let gameDuration: TimeInterval = 30      // 30 秒
    var remaining: TimeInterval = 30
    var score: Int = 0

    // MARK: 闭包（由 View 层注入）

    var onScoreChange: ((Int) -> Void)?
    var onTimeChange: ((TimeInterval) -> Void)?
    var onGameEnd: ((Int) -> Void)?           // 最终分数

    // MARK: 状态机

    enum Phase { case ready, playing, ended }
    private(set) var phase: Phase = .ready

    private var lastTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0

    // MARK: 启动 / 结束

    func startGame() {
        guard phase == .ready else { return }
        phase = .playing
        remaining = gameDuration
        score = 0
        onScoreChange?(score)
        onTimeChange?(remaining)
        onGameStart()
    }

    final func endGame() {
        guard phase != .ended else { return }
        phase = .ended
        removeAllChildren()
        onGameEnd?(score)
    }

    // MARK: 子类钩子

    func onGameStart() {}
    func updateEachFrame(dt: TimeInterval) {}
    func handleTouch(at point: CGPoint) {}
    func handleDrag(from start: CGPoint, to current: CGPoint) {}

    // MARK: 每帧（统一调度）

    override func update(_ currentTime: TimeInterval) {
        guard phase == .playing else { return }
        let dt = lastTime == 0 ? 1.0/60 : currentTime - lastTime
        lastTime = currentTime

        // 倒计时
        remaining -= dt
        if remaining <= 0 {
            remaining = 0
            onTimeChange?(0)
            endGame()
            return
        }
        onTimeChange?(remaining)

        updateEachFrame(dt: dt)
    }

    /// 重置到准备态，准备再来一局
    func resetToReady() {
        phase = .ready
        lastTime = 0
        score = 0
        remaining = gameDuration
        removeAllChildren()
        onScoreChange?(0)
        onTimeChange?(gameDuration)
    }
}
