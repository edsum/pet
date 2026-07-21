import SwiftUI
import AppIntents
import WidgetKit
import DeskPetKit

// MARK: - 从 Widget 触发的互动 Intent（喂食 / 摸摸）

/// 喂食：从 Widget 点击直接给宠物喂一份默认食物
struct FeedPetIntent: AppIntent {
    static var title: LocalizedStringResource = "喂食"
    static var description = IntentDescription("给桌宠一份小鱼干。")

    func perform() async throws -> some IntentResult {
        var state = SharedStore.loadState()
        state.reconcile()
        state.apply(.userFed(.fish))
        SharedStore.saveState(state)
        // 立刻刷新所有 Widget
        #if canImport(WidgetKit)
        await WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

/// 摸摸：直接 +心情
struct PetPetIntent: AppIntent {
    static var title: LocalizedStringResource = "摸摸"
    static var description = IntentDescription("摸摸桌宠的头。")

    func perform() async throws -> some IntentResult {
        var state = SharedStore.loadState()
        state.reconcile()
        state.apply(.userPetted)
        SharedStore.saveState(state)
        #if canImport(WidgetKit)
        await WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}
