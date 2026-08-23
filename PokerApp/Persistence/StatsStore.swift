import Foundation

struct PlayerStats: Codable, Equatable {
    var handsPlayed: Int = 0
    var handsWon: Int = 0
    var biggestPotWon: Int = 0
    var totalChipsWon: Int = 0
    var totalChipsLost: Int = 0
    var vpipCount: Int = 0      // voluntarily put money in pot (preflop call/bet/raise)
    var pfrCount: Int = 0       // preflop raise count
    var handsCompletedInBeginnerMode: Int = 0
    var lastClassicBankroll: Int?

    var winRate: Double {
        handsPlayed == 0 ? 0 : Double(handsWon) / Double(handsPlayed)
    }

    var vpipPercentage: Double {
        handsPlayed == 0 ? 0 : Double(vpipCount) / Double(handsPlayed)
    }

    var pfrPercentage: Double {
        handsPlayed == 0 ? 0 : Double(pfrCount) / Double(handsPlayed)
    }
}

struct AppSettings: Codable, Equatable {
    var hapticsEnabled: Bool = true
    var soundEnabled: Bool = true
    var tableFeltColorIndex: Int = 0
    var hasSeenTutorial: Bool = false
    var preferredDifficulty: BotDifficulty = .medium
    var preferredOpponentCount: Int = 4
}

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published var stats: PlayerStats {
        didSet { persistStats() }
    }
    @Published var settings: AppSettings {
        didSet { persistSettings() }
    }

    private let statsKey = "poker.stats.v1"
    private let settingsKey = "poker.settings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            stats = decoded
        } else {
            stats = PlayerStats()
        }
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func persistStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func recordHandResult(_ result: HandResult, humanID: UUID, beginnerMode: Bool) {
        stats.handsPlayed += 1
        let humanWon = result.potsWon.contains { $0.winners.contains { $0.id == humanID } }
        if humanWon {
            stats.handsWon += 1
            let wonAmount = result.potsWon.filter { $0.winners.contains { $0.id == humanID } }
                .reduce(0) { $0 + $1.pot.amount / max(1, $1.winners.count) }
            stats.totalChipsWon += wonAmount
            stats.biggestPotWon = max(stats.biggestPotWon, wonAmount)
        }
        if beginnerMode { stats.handsCompletedInBeginnerMode += 1 }

        let preflopActions = result.actionLog.filter { $0.stage == .preflop && $0.playerID == humanID }
        if preflopActions.contains(where: { if case .call = $0.action { return true }; if case .bet = $0.action { return true }; if case .raise = $0.action { return true }; return false }) {
            stats.vpipCount += 1
        }
        if preflopActions.contains(where: { if case .raise = $0.action { return true }; if case .bet = $0.action { return true }; return false }) {
            stats.pfrCount += 1
        }
    }

    func resetStats() {
        stats = PlayerStats()
    }
}
