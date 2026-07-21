import SwiftUI
import WatchKit
import DeskPetKit

@main
struct DeskPetWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}
