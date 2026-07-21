import WidgetKit
import SwiftUI
import DeskPetKit

// MARK: - Widget Bundle 入口

@main
struct DeskPetWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomePetWidget()
        LockScreenPetWidget()
        StandByPetWidget()
        PetLiveActivity()
    }
}
