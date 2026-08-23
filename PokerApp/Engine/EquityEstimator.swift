import Foundation

/// Monte Carlo equity estimator: probability that a given hole-card hand wins/ties
/// against N random opponents given the known community cards so far.
enum EquityEstimator {

    static func estimateEquity(hole: [Card], community: [Card], opponents: Int, iterations: Int = 300) -> Double {
        guard opponents > 0 else { return 1.0 }
        var usedIDs = Set((hole + community).map { "\($0.rank.rawValue)-\($0.suit.rawValue)" })
        let fullDeck: [Card] = Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in Card(rank: rank, suit: suit) }
        }
        let available = fullDeck.filter { !usedIDs.contains("\($0.rank.rawValue)-\($0.suit.rawValue)") }

        let cardsNeededForBoard = max(0, 5 - community.count)
        var wins = 0.0
        var trials = 0

        for _ in 0..<iterations {
            var pool = available
            pool.shuffle()
            var cursor = 0

            var opponentHoles: [[Card]] = []
            for _ in 0..<opponents {
                guard cursor + 2 <= pool.count else { break }
                opponentHoles.append([pool[cursor], pool[cursor + 1]])
                cursor += 2
            }
            guard opponentHoles.count == opponents else { continue }

            guard cursor + cardsNeededForBoard <= pool.count else { continue }
            let board = community + Array(pool[cursor..<(cursor + cardsNeededForBoard)])

            let myHand = HandEvaluator.bestHand(from: hole + board)
            var bestOpponent = myHand
            var iBeatEveryone = true
            var tie = false

            for oh in opponentHoles {
                let oppHand = HandEvaluator.bestHand(from: oh + board)
                if oppHand > myHand {
                    iBeatEveryone = false
                } else if oppHand == myHand {
                    tie = true
                }
                if oppHand > bestOpponent { bestOpponent = oppHand }
            }

            if iBeatEveryone && !tie {
                wins += 1
            } else if iBeatEveryone && tie {
                wins += 0.5
            }
            trials += 1
        }

        usedIDs.removeAll()
        guard trials > 0 else { return 0.5 }
        return wins / Double(trials)
    }
}
