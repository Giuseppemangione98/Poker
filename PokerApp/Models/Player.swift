import Foundation

enum BotDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard

    var localizedName: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Medio"
        case .hard: return "Difficile"
        }
    }
}

enum PlayerAction: Equatable {
    case fold
    case check
    case call
    case bet(Int)
    case raise(Int)
    case allIn
}

struct Player: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isBot: Bool
    var difficulty: BotDifficulty?
    var avatarSeed: Int

    var stack: Int
    var holeCards: [Card] = []
    var currentBet: Int = 0          // amount put in during the current betting round
    var totalContribution: Int = 0   // total put into the pot this hand (all rounds)
    var hasFolded: Bool = false
    var isAllIn: Bool = false
    var hasActedThisRound: Bool = false
    var isSittingOut: Bool = false
    var lastAction: PlayerAction?

    var isEliminated: Bool { stack <= 0 && !isSittingOut }

    init(id: UUID = UUID(), name: String, isBot: Bool, difficulty: BotDifficulty? = nil, stack: Int, avatarSeed: Int = 0) {
        self.id = id
        self.name = name
        self.isBot = isBot
        self.difficulty = difficulty
        self.stack = stack
        self.avatarSeed = avatarSeed
    }

    mutating func resetForNewHand() {
        holeCards = []
        currentBet = 0
        totalContribution = 0
        hasFolded = stack <= 0
        isAllIn = false
        hasActedThisRound = false
        lastAction = nil
    }

    mutating func resetForNewBettingRound() {
        currentBet = 0
        hasActedThisRound = false
    }

    var isActiveInHand: Bool { !hasFolded && !isSittingOut && stack >= 0 }
    var canAct: Bool { isActiveInHand && !isAllIn }

    static func == (lhs: Player, rhs: Player) -> Bool { lhs.id == rhs.id }
}
