import Foundation

enum HandCategory: Int, Comparable, CaseIterable {
    case highCard = 0
    case pair
    case twoPair
    case trips
    case straight
    case flush
    case fullHouse
    case quads
    case straightFlush

    static func < (lhs: HandCategory, rhs: HandCategory) -> Bool { lhs.rawValue < rhs.rawValue }

    var localizedName: String {
        switch self {
        case .highCard: return "Carta Alta"
        case .pair: return "Coppia"
        case .twoPair: return "Doppia Coppia"
        case .trips: return "Tris"
        case .straight: return "Scala"
        case .flush: return "Colore"
        case .fullHouse: return "Full House"
        case .quads: return "Poker"
        case .straightFlush: return "Scala Colore"
        }
    }
}

/// A fully-ranked 5-card hand, comparable via category then kicker tiebreakers.
struct RankedHand: Comparable {
    let category: HandCategory
    /// Tiebreaker values in descending priority order (e.g. quad rank, kicker, ...)
    let tiebreakers: [Int]
    let bestFive: [Card]

    static func < (lhs: RankedHand, rhs: RankedHand) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (a, b) in zip(lhs.tiebreakers, rhs.tiebreakers) where a != b {
            return a < b
        }
        return false
    }

    static func == (lhs: RankedHand, rhs: RankedHand) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }

    var description: String { category.localizedName }
}
