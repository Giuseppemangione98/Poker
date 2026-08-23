import Foundation

/// A pot (main or side) with the amount and the set of player ids eligible to win it.
struct Pot: Identifiable {
    let id = UUID()
    var amount: Int
    var eligiblePlayerIDs: Set<UUID>
}

enum GameStage: Int, CaseIterable {
    case preflop, flop, turn, river, showdown

    var localizedName: String {
        switch self {
        case .preflop: return "Preflop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .showdown: return "Showdown"
        }
    }
}

/// Splits total contributions into main + side pots, respecting all-in caps.
enum PotCalculator {
    static func buildPots(players: [Player]) -> [Pot] {
        let contributors = players.filter { $0.totalContribution > 0 }
        guard !contributors.isEmpty else { return [] }

        var levels = Set(contributors.map { $0.totalContribution }).sorted()
        var pots: [Pot] = []
        var previousLevel = 0

        for level in levels {
            let layerAmount = level - previousLevel
            guard layerAmount > 0 else { continue }
            let payers = contributors.filter { $0.totalContribution >= level }
            let potAmount = layerAmount * payers.count
            let eligible = players.filter { !$0.hasFolded && $0.totalContribution >= level }.map { $0.id }
            if potAmount > 0 {
                pots.append(Pot(amount: potAmount, eligiblePlayerIDs: Set(eligible)))
            }
            previousLevel = level
        }
        levels.removeAll()
        return mergeConsecutivePotsWithSameEligibility(pots)
    }

    private static func mergeConsecutivePotsWithSameEligibility(_ pots: [Pot]) -> [Pot] {
        var merged: [Pot] = []
        for pot in pots {
            if let last = merged.last, last.eligiblePlayerIDs == pot.eligiblePlayerIDs {
                merged[merged.count - 1].amount += pot.amount
            } else {
                merged.append(pot)
            }
        }
        return merged
    }
}
