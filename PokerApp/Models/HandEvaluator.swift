import Foundation

/// Evaluates the best possible 5-card poker hand out of any number of cards (5, 6 or 7).
enum HandEvaluator {

    static func bestHand(from cards: [Card]) -> RankedHand {
        precondition(cards.count >= 5, "Need at least 5 cards to evaluate a hand")
        if cards.count == 5 { return rank(fiveCards: cards) }

        var best: RankedHand?
        forEachCombination(of: cards, choose: 5) { combo in
            let ranked = rank(fiveCards: combo)
            if best == nil || ranked > best! { best = ranked }
        }
        return best!
    }

    private static func forEachCombination(of cards: [Card], choose k: Int, _ body: ([Card]) -> Void) {
        let n = cards.count
        var indices = Array(0..<k)
        func emit() { body(indices.map { cards[$0] }) }
        if k > n { return }
        emit()
        while true {
            var i = k - 1
            while i >= 0 && indices[i] == i + n - k { i -= 1 }
            if i < 0 { break }
            indices[i] += 1
            for j in (i + 1)..<k { indices[j] = indices[j - 1] + 1 }
            emit()
        }
    }

    private static func rank(fiveCards cards: [Card]) -> RankedHand {
        let sorted = cards.sorted { $0.rank > $1.rank }
        let ranks = sorted.map { $0.rank.rawValue }
        let suits = sorted.map { $0.suit }

        let isFlush = Set(suits).count == 1

        // Group ranks by count, e.g. [14: 2, 5: 2, 9: 1] for two pair
        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        // groups sorted by (count desc, rank desc)
        let groups = counts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key > b.key
        }

        let straightHigh = straightHighCard(ranks: Set(ranks))

        if isFlush, let high = straightHighCard(ranks: Set(ranks)) {
            return RankedHand(category: .straightFlush, tiebreakers: [high], bestFive: sorted)
        }
        if groups[0].value == 4 {
            let kicker = groups[1].key
            return RankedHand(category: .quads, tiebreakers: [groups[0].key, kicker], bestFive: sorted)
        }
        if groups[0].value == 3 && groups.count > 1 && groups[1].value >= 2 {
            return RankedHand(category: .fullHouse, tiebreakers: [groups[0].key, groups[1].key], bestFive: sorted)
        }
        if isFlush {
            return RankedHand(category: .flush, tiebreakers: ranks, bestFive: sorted)
        }
        if let high = straightHigh {
            return RankedHand(category: .straight, tiebreakers: [high], bestFive: sorted)
        }
        if groups[0].value == 3 {
            let kickers = groups.dropFirst().map { $0.key }.sorted(by: >)
            return RankedHand(category: .trips, tiebreakers: [groups[0].key] + kickers, bestFive: sorted)
        }
        if groups[0].value == 2 && groups.count > 1 && groups[1].value == 2 {
            let pairRanks = [groups[0].key, groups[1].key].sorted(by: >)
            let kicker = groups[2].key
            return RankedHand(category: .twoPair, tiebreakers: pairRanks + [kicker], bestFive: sorted)
        }
        if groups[0].value == 2 {
            let kickers = groups.dropFirst().map { $0.key }.sorted(by: >)
            return RankedHand(category: .pair, tiebreakers: [groups[0].key] + kickers, bestFive: sorted)
        }
        return RankedHand(category: .highCard, tiebreakers: ranks, bestFive: sorted)
    }

    /// Returns the high card of the best straight within the given rank set, handling the wheel (A-2-3-4-5).
    private static func straightHighCard(ranks: Set<Int>) -> Int? {
        var set = ranks
        if set.contains(14) { set.insert(1) } // ace also plays low
        var best: Int?
        for high in stride(from: 14, through: 5, by: -1) {
            let needed = Set((high - 4)...high)
            if needed.isSubset(of: set) {
                best = high
                break
            }
        }
        return best
    }
}
