import SwiftUI
import DeskPetKit

#if targetEnvironment(macCatalyst)

/// macOS Menu Bar 桌宠：在顶部菜单栏放一只小宠物
///
/// 通过 AppKit 的 NSStatusItem 实现。Catalyst 用 NSApp 间接访问。
/// 仅在 macOS 下生效。
struct MenuBarPetView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var statusItem: NSStatusItem?

    var body: some View {
        RootView()
            .onAppear { setupMenuBar() }
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill",
                                    accessibilityDescription: "桌宠")
            button.image?.size = NSSize(width: 18, height: 18)
            button.target = MenuBarActionHandler.shared
            button.action = #selector(MenuBarActionHandler.shared.onClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        MenuBarActionHandler.shared.vm = vm
    }
}

/// 状态栏点击处理：左键打开主窗口，右键弹快捷菜单
final class MenuBarActionHandler: NSObject {
    static let shared = MenuBarActionHandler()
    weak var vm: PetViewModel?

    @objc func onClick() {
        // 弹出快捷操作菜单
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "🐾 桌宠 · \(vm?.state.name ?? "")",
                                    action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: "摸摸头", action: #selector(pet), keyEquivalent: "p")
        menu.addItem(withTitle: "喂小鱼", action: #selector(feed), keyEquivalent: "f")
        menu.addItem(withTitle: "睡觉/唤醒", action: #selector(toggleSleep), keyEquivalent: "s")
        menu.addItem(.separator())

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func pet() {
        Task { @MainActor in vm?.pet() }
    }
    @objc private func feed() {
        Task { @MainActor in vm?.feed(.fish) }
    }
    @objc private func toggleSleep() {
        Task { @MainActor in
            guard let vm = vm else { return }
            if vm.state.mood == .sleeping {
                vm.state.mood = .idle
            } else {
                vm.state.mood = .sleeping
            }
            vm.persist()
        }
    }
}

#endif
