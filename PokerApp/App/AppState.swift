import Foundation

enum AppRoute: Hashable {
    case modeSelection(beginner: Bool)
    case table(beginner: Bool, opponents: Int, difficulty: BotDifficulty, stack: Int)
    case stats
    case settings
    case handRankings
}

final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var showTutorialOnLaunch = false

    func goToModeSelection(beginner: Bool) {
        path.append(.modeSelection(beginner: beginner))
    }

    func startGame(beginner: Bool, opponents: Int, difficulty: BotDifficulty, stack: Int) {
        path.append(.table(beginner: beginner, opponents: opponents, difficulty: difficulty, stack: stack))
    }

    func popToRoot() { path.removeAll() }
}
