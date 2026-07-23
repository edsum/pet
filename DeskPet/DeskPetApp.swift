import SwiftUI
import SpriteKit
import DeskPetKit

@main
struct DeskPetApp: App {

    @StateObject private var petVM = PetViewModel()
    #if targetEnvironment(macCatalyst)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var macDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(petVM)
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 720, minHeight: 900)
                #endif
                .onAppear {
                    petVM.bootstrap()
                    EventEngine.shared.start()
                    SystemEventOrchestrator.shared.bootstrap(vm: petVM)
                    WatchSync.shared.activate()
                    #if targetEnvironment(macCatalyst)
                    macDelegate.attach(vm: petVM)
                    #endif
                }
        }
        #if targetEnvironment(macCatalyst)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 1100)
        .commands {
            // 自定义菜单栏快捷项
            CommandGroup(replacing: .newItem) {
                Button("摸摸头") { petVM.pet() }.keyboardShortcut("p", modifiers: .command)
                Button("喂食") { petVM.feed(.fish) }.keyboardShortcut("f", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        // Mac 原生：MenuBar 额外 Scene（仅 macOS 原生，非 Catalyst）
        MenuBarExtra("桌宠", systemImage: "pawprint.fill") {
            MacMenuContent(petName: petVM.state.name,
                           mood: petVM.state.mood,
                           coins: petVM.state.coins,
                           level: petVM.state.level,
                           onPet: { petVM.pet() },
                           onFeed: { petVM.feed(.fish) },
                           onSleep: { toggleSleep(petVM) })
        }
        #endif
    }

    #if os(macOS)
    private func toggleSleep(_ vm: PetViewModel) {
        if vm.state.mood == .sleeping {
            vm.state.mood = .idle
        } else {
            vm.state.mood = .sleeping
        }
        vm.persist()
    }
    #endif
}
