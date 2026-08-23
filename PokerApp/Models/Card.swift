import Foundation

enum Suit: Int, CaseIterable, Codable, Hashable {
    case clubs, diamonds, hearts, spades

    var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    var isRed: Bool { self == .diamonds || self == .hearts }
}

enum Rank: Int, CaseIterable, Codable, Hashable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }
}

struct Card: Identifiable, Hashable, Codable {
    let id: UUID
    let rank: Rank
    let suit: Suit

    init(rank: Rank, suit: Suit) {
        self.id = UUID()
        self.rank = rank
        self.suit = suit
    }

    var label: String { "\(rank.label)\(suit.symbol)" }
}

struct Deck {
    private var cards: [Card]

    init() {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in Card(rank: rank, suit: suit) }
        }
        cards.shuffle()
    }

    mutating func shuffle() { cards.shuffle() }

    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeLast()
    }

    mutating func draw(_ n: Int) -> [Card] {
        (0..<n).compactMap { _ in draw() }
    }

    var remaining: Int { cards.count }
}
