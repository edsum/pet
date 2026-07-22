import SwiftUI
import PhotosUI
import Vision
import CoreImage
import ImagePlayground
import AppIntents
import UIKit
import DeskPetKit

/// 抠图 + Image Playground 生成形象
struct GenerateAvatarView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var cutoutImage: UIImage?
    @State private var showError = false
    @State private var errorMsg: String?
    @State private var didSaveGeneratedAvatar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    stage(title: "① 选照片") {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("从相册选", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let sourceImage {
                        stage(title: "原图") {
                            Image(uiImage: sourceImage)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            Task { await runCutout() }
                        } label: {
                            Label("② 抠图（去背景）", systemImage: "wand.and.rays")
                                .frame(maxWidth: .infinity).padding()
                                .background(.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let cutoutImage {
                        stage(title: "抠图结果") {
                            Image(uiImage: cutoutImage)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 200)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            presentImagePlayground()
                        } label: {
                            Label("③ 生成卡通形象", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity).padding()
                                .background(.pink.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let err = errorMsg, showError {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }

                    if didSaveGeneratedAvatar {
                        Text("形象已保存")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            }
            .navigationTitle("生成形象")
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                sourceImage = img
                cutoutImage = nil
                didSaveGeneratedAvatar = false
            }
        }
    }

    // MARK: 子组件

    @ViewBuilder
    private func stage<Content: View>(title: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 抠图

    private func runCutout() async {
        guard let img = sourceImage,
              let cg = img.cgImage else { return }
        do {
            let cutout = try await Self.removeBackground(cgImage: cg)
            await MainActor.run { self.cutoutImage = cutout }
        } catch {
            await MainActor.run {
                self.errorMsg = "抠图失败：\(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    /// 用 Vision 的"长按抬出主体"同款 API 抠图
    static func removeBackground(cgImage: CGImage) async throws -> UIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw NSError(domain: "cutout", code: 1)
        }
        let pixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances, from: handler
        )

        let ciInput = CIImage(cgImage: cgImage)
        let mask = CIImage(cvPixelBuffer: pixelBuffer)
        let blended = ciInput.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: mask,
            "inputBackgroundImage": CIImage.empty()
        ])
        let context = CIContext()
        guard let cgOut = context.createCGImage(blended, from: ciInput.extent) else {
            throw NSError(domain: "cutout", code: 2)
        }
        return UIImage(cgImage: cgOut)
    }

    // MARK: Image Playground

    private func presentImagePlayground() {
        guard let img = cutoutImage else { return }

        guard ImagePlaygroundViewController.isAvailable else {
            errorMsg = "当前设备不支持 Image Playground（需要 Apple Intelligence 机型）"
            showError = true
            return
        }

        let concepts: [ImagePlaygroundConcept] = [
            .text("full body cute desktop pet based on the source animal, \(vm.state.appearance.style.rawValue) style, centered, sticker-like, expressive eyes")
        ]
        let vc = ImagePlaygroundViewController()
        vc.sourceImage = img
        vc.concepts = concepts
        let delegate = ImagePlaygroundDelegate(
            onCreated: { [self] url in self.imagePlaygroundCreated(imageURL: url) },
            onCancel: {}
        )
        objc_setAssociatedObject(vc, &ImagePlaygroundDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
        vc.delegate = delegate

        // 通过 UIWindow.root 调起系统 UI
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(vc, animated: true)
    }
}

// MARK: - ImagePlaygroundViewController Delegate
//
// ImagePlaygroundViewController.Delegate 是 class 协议，SwiftUI struct 不能直接实现。
// 用一个 NSObject 中介来处理回调。

final class ImagePlaygroundDelegate: NSObject, ImagePlaygroundViewController.Delegate {

    static var key: UInt8 = 0

    let onCreated: (URL) -> Void
    let onCancel: () -> Void

    init(onCreated: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onCreated = onCreated
        self.onCancel = onCancel
    }

    func imagePlaygroundViewController(_ imagePlaygroundViewController: ImagePlaygroundViewController,
                                        didCreateImageAt imageURL: URL) {
        onCreated(imageURL)
        imagePlaygroundViewController.dismiss(animated: true)
    }

    func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
        onCancel()
        imagePlaygroundViewController.dismiss(animated: true)
    }
}

extension GenerateAvatarView {
    func imagePlaygroundCreated(imageURL: URL) {
        Task { @MainActor in
            if let data = try? Data(contentsOf: imageURL),
               let img = UIImage(data: data) {
                try? AssetStore.save(frame: img, mood: .happy, petID: vm.state.petID)
                try? AssetStore.save(frame: img, mood: .idle, petID: vm.state.petID)
                vm.state.mood = .happy
                vm.scene.sync(state: vm.state)
                vm.persist()
                didSaveGeneratedAvatar = true
                showError = false
            }
        }
    }
}
