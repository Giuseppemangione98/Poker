import Foundation

/// One recorded decision point, used to build the post-hand analysis in Beginner mode.
struct HandActionRecord: Identifiable {
    let id = UUID()
    let stage: GameStage
    let playerID: UUID
    let playerName: String
    let action: PlayerAction
    let amount: Int
    let potBefore: Int
    let equityAtDecision: Double?   // 0...1, only computed for the human player
    let potOddsAtDecision: Double?  // 0...1, call amount / (pot + call amount)
    let recommendedAction: String?  // short human-readable suggestion, beginner mode only

    var actionLabel: String {
        switch action {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call \(amount)"
        case .bet: return "Bet \(amount)"
        case .raise: return "Raise \(amount)"
        case .allIn: return "All-in \(amount)"
        }
    }
}

struct HandResult {
    let potsWon: [(pot: Pot, winners: [Player], rankedHand: RankedHand?)]
    let allPlayersAtShowdown: [Player]
    let actionLog: [HandActionRecord]
    let handNumber: Int
}
