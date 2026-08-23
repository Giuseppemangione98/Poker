import SwiftUI

@main
struct PokerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var stats = StatsStore.shared

    var body: some View {
        NavigationStack(path: $appState.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .onAppear {
            HapticManager.shared.isEnabled = stats.settings.hapticsEnabled
        }
        .fullScreenCover(isPresented: Binding(
            get: { !stats.settings.hasSeenTutorial },
            set: { _ in }
        )) {
            TutorialView()
                .onDisappear { stats.settings.hasSeenTutorial = true }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .modeSelection(let beginner):
            ModeSelectionView(beginner: beginner)
        case .table(let beginner, let opponents, let difficulty, let stack):
            GameContainerView(beginner: beginner, opponents: opponents, difficulty: difficulty, startingStack: stack)
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        case .handRankings:
            HandRankingGuideView()
        }
    }
}

/// Creates a fresh GameEngine + GameViewModel for one sitting at the table.
struct GameContainerView: View {
    let beginner: Bool
    let opponents: Int
    let difficulty: BotDifficulty
    let startingStack: Int

    @StateObject private var vm: GameViewModel

    init(beginner: Bool, opponents: Int, difficulty: BotDifficulty, startingStack: Int) {
        self.beginner = beginner
        self.opponents = opponents
        self.difficulty = difficulty
        self.startingStack = startingStack
        let engine = GameEngine(botCount: opponents, difficulty: difficulty, startingStack: startingStack)
        _vm = StateObject(wrappedValue: GameViewModel(engine: engine, beginnerMode: beginner))
    }

    var body: some View {
        TableView(vm: vm)
    }
}
