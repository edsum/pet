import SwiftUI
import DeskPetKit

#if targetEnvironment(macCatalyst) || os(macOS)
import AppKit

/// Mac Catalyst 的 App Delegate：负责创建 NSStatusBar 图标
final class MacAppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var menuBarHandler: MenuBarActionHandlerCatalyst?
    weak var vm: PetViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill",
                                    accessibilityDescription: "桌宠")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        menuBarHandler = MenuBarActionHandlerCatalyst()
        menuBarHandler?.vm = vm
    }

    func attach(vm: PetViewModel) {
        self.vm = vm
        menuBarHandler?.vm = vm
        // 给状态栏按钮绑定菜单
        let menu = NSMenu()
        let title = NSMenuItem(title: "🐾 桌宠 · \(vm.state.name)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(withTitle: "摸摸头", action: #selector(MenuBarActionHandlerCatalyst.pet),
                     keyEquivalent: "p", target: menuBarHandler)
        menu.addItem(withTitle: "喂小鱼", action: #selector(MenuBarActionHandlerCatalyst.feed),
                     keyEquivalent: "f", target: menuBarHandler)
        menu.addItem(withTitle: "睡觉/唤醒", action: #selector(MenuBarActionHandlerCatalyst.toggleSleep),
                     keyEquivalent: "s", target: menuBarHandler)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(MenuBarActionHandlerCatalyst.quit),
                     keyEquivalent: "q", target: menuBarHandler)
        statusItem?.menu = menu
    }
}

final class MenuBarActionHandlerCatalyst: NSObject {
    weak var vm: PetViewModel?

    @objc func pet() {
        Task { @MainActor in vm?.pet() }
    }
    @objc func feed() {
        Task { @MainActor in vm?.feed(.fish) }
    }
    @objc func toggleSleep() {
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
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
#endif

#if os(macOS)
/// macOS 原生 MenuBarExtra 的菜单内容
struct MacMenuContent: View {
    let petName: String
    let mood: PetMood
    let coins: Int
    let level: Int
    let onPet: () -> Void
    let onFeed: () -> Void
    let onSleep: () -> Void

    var body: some View {
        VStack {
            Text("🐾 \(petName) · Lv.\(level)")
            Text("心情：\(mood.rawValue) · 💰 \(coins)")
                .font(.caption)
        }
        .padding(.bottom, 4)
        Divider()
        Button("摸摸头", action: onPet).keyboardShortcut("p")
        Button("喂小鱼", action: onFeed).keyboardShortcut("f")
        Button("睡觉/唤醒", action: onSleep).keyboardShortcut("s")
        Divider()
        Button("退出") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
#endif
