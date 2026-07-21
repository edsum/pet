import SwiftUI
import SpriteKit
import DeskPetKit

/// Debug 性能覆盖层：FPS + Widget reload 剩余预算
///
/// 仅在 DEBUG 构建显示。用法：
///   HomeView().overlay(DebugOverlay())
struct DebugOverlay: View {

    #if DEBUG
    @State private var fps: Double = 0
    @State private var frameCount: Int = 0
    @State private var lastTime: TimeInterval = 0
    @State private var budget: (hour: Int, day: Int) = (0, 0)

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    #endif

    var body: some View {
        #if DEBUG
        VStack {
            HStack(spacing: 12) {
                badge(label: "FPS", value: String(format: "%.0f", fps),
                      color: fpsColor)
                badge(label: "Reload", value: "\(budget.hour)/4  \(budget.day)/25",
                      color: budgetColor)
            }
            .padding(8)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 8)
            Spacer()
        }
        .onReceive(timer) { _ in
            update()
        }
        #else
        EmptyView()
        #endif
    }

    #if DEBUG
    private var fpsColor: Color {
        switch fps {
        case 55...:    return .green
        case 30..<55:  return .orange
        default:       return .red
        }
    }

    private var budgetColor: Color {
        if budget.hour >= 3 || budget.day >= 22 { return .red }
        if budget.hour >= 2 || budget.day >= 15 { return .orange }
        return .green
    }

    private func badge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2.bold()).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.caption.bold().monospacedDigit()).foregroundStyle(color)
        }
    }

    private func update() {
        budget = WidgetReloadThrottle.shared.remainingBudget()

        // FPS 用 CADisplayLink 算（这里简化用 Timer 频率反推）
        let now = Date().timeIntervalSince1970
        if lastTime > 0 {
            let elapsed = now - lastTime
            // 如果 1 秒内渲染了 frameCount 帧，fps ≈ frameCount/elapsed
            // 这里 frameCount 在生产里应该由 SKView.didRender 累加，此处占位
            fps = min(60, Double(60))     // 占位：实际由 SKView 接管
            _ = elapsed
        }
        lastTime = now
        frameCount = 0
    }
    #endif
}

#if canImport(UIKit) && DEBUG
import UIKit

/// SKView 的 FPS 监听：把帧率回传给 DebugOverlay
final class FPSMonitor: NSObject {
    static let shared = FPSMonitor()
    private var displayLink: CADisplayLink?
    private var frames: Int = 0
    private var lastTick: CFTimeInterval = 0

    var onFPS: ((Double) -> Void)?

    func start() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames += 1
        let now = link.timestamp
        if lastTick == 0 { lastTick = now; return }
        let elapsed = now - lastTick
        if elapsed >= 1.0 {
            onFPS?(Double(frames) / elapsed)
            frames = 0
            lastTick = now
        }
    }
}
#endif
