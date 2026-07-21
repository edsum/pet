import SwiftUI
import SpriteKit
import DeskPetKit

struct RootView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var tab: Tab = .home
    @State private var showSwitcher = false
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false

    enum Tab: Hashable, CaseIterable {
        case home, stats, games, shop, settings
        var title: String {
            switch self {
            case .home: return "家"
            case .stats: return "统计"
            case .games: return "小游戏"
            case .shop: return "养成"
            case .settings: return "设置"
            }
        }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .stats: return "chart.bar.fill"
            case .games: return "gamecontroller.fill"
            case .shop: return "sparkles"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        Group {
            if !hasFinishedOnboarding {
                OnboardingView { hasFinishedOnboarding = true }
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        TabView(selection: $tab) {
            HomeView(showSwitcher: $showSwitcher)
                .tabItem { Label(Tab.home.title, systemImage: Tab.home.icon) }
                .tag(Tab.home)

            StatsView()
                .tabItem { Label(Tab.stats.title, systemImage: Tab.stats.icon) }
                .tag(Tab.stats)

            GamesView()
                .tabItem { Label(Tab.games.title, systemImage: Tab.games.icon) }
                .tag(Tab.games)

            // ★ M9 养成（签到/成就/商店/进化）
            ProgressionTabView()
                .tabItem { Label(Tab.shop.title, systemImage: Tab.shop.icon) }
                .tag(Tab.shop)

            SettingsView()
                .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
        .onAppear {
            PetViewModelAccessor.shared.vm = vm
        }
        .sheet(isPresented: $showSwitcher) {
            PetSwitcherView()
                .environmentObject(vm)
        }
    }
}

/// 养成子页面：签到 / 成就 / 商店 / 进化
struct ProgressionTabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CheckInView()
                } label: {
                    Label("每日签到", systemImage: "calendar.badge.checkmark")
                }
                NavigationLink {
                    AchievementsView()
                } label: {
                    Label("成就", systemImage: "rosette")
                }
                NavigationLink {
                    ShopView()
                } label: {
                    Label("商店", systemImage: "bag.fill")
                }
                NavigationLink {
                    EvolutionView()
                } label: {
                    Label("进化", systemImage: "wand.and.stars")
                }
            }
            .navigationTitle("养成")
        }
    }
}
