import SwiftUI
import SpriteKit

/// SwiftUI 包装层：把 PetScene 嵌进 SwiftUI，处理手势并桥接到 ViewModel
struct PetSceneView: View {

    let scene: PetScene

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene,
                       options: [.allowsTransparency, .ignoresSiblingOrder])   // SwiftUI 接管手势，不用 .disableInteraction
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = toScene(value.location, in: proxy.size)
                            guard let pet = scene.pet else { return }
                            if pet.isDragging == false,
                               value.translation.width != 0 || value.translation.height != 0 {
                                // 进入拖拽
                                scene.beginDrag(at: p)
                            }
                            if pet.isDragging {
                                scene.updateDrag(at: p)
                            }
                        }
                        .onEnded { value in
                            let p = toScene(value.location, in: proxy.size)
                            let velocity = CGVector(dx: value.predictedEndLocation.x - value.location.x,
                                                    dy: value.predictedEndLocation.y - value.location.y)
                            if scene.pet?.isDragging == true {
                                scene.endDrag(at: p, velocity: scaledVelocity(velocity))
                            } else {
                                // 没拖起来 → 视为单击
                                scene.handleTap(at: p)
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // 双击位置取中心（SwiftUI 在 simultaneous 下拿不到精确点）
                            guard let pet = scene.pet else { return }
                            scene.handleDoubleTap(at: pet.position)
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in
                            guard let pet = scene.pet else { return }
                            scene.handleLongPress(at: pet.position)
                        }
                )
                .onAppear {
                    scene.resize(to: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    scene.resize(to: newSize)
                }
        }
    }

    /// SwiftUI 坐标（原点左上）→ Scene 坐标（原点左下）
    private func toScene(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }

    /// SwiftUI velocity 单位小，放大约 5 倍更像投掷
    private func scaledVelocity(_ v: CGVector) -> CGVector {
        CGVector(dx: v.dx * 5, dy: v.dy * 5)
    }
}
