import Foundation

/// Produces a decision for a bot player given the current engine state.
enum BotAI {

    static func decide(engine: GameEngine, player: Player) -> PlayerAction {
        let opponents = max(1, engine.playersInHand.count - 1)
        let equity = EquityEstimator.estimateEquity(
            hole: player.holeCards,
            community: engine.communityCards,
            opponents: opponents,
            iterations: iterations(for: player.difficulty ?? .medium)
        )

        let info = engine.availableActions(for: player.id)
        let pot = engine.potTotal
        let toCall = info.callAmount
        let potOdds = toCall > 0 ? Double(toCall) / Double(pot + toCall) : 0

        switch player.difficulty ?? .medium {
        case .easy:
            return easyDecision(equity: equity, info: info, player: player)
        case .medium:
            return mediumDecision(equity: equity, potOdds: potOdds, info: info, player: player, pot: pot)
        case .hard:
            return hardDecision(equity: equity, potOdds: potOdds, info: info, player: player, pot: pot, engine: engine)
        }
    }

    private static func iterations(for difficulty: BotDifficulty) -> Int {
        switch difficulty {
        case .easy: return 120
        case .medium: return 220
        case .hard: return 350
        }
    }

    // MARK: Easy: mostly calls with any playable hand, rarely raises, folds only very weak hands to big bets.
    private static func easyDecision(equity: Double, info: (canCheck: Bool, canCall: Bool, callAmount: Int, raiseBounds: RaiseBounds?), player: Player) -> PlayerAction {
        if info.canCheck {
            if equity > 0.75, let b = info.raiseBounds, Double.random(in: 0...1) < 0.3 {
                return .bet(min(b.minTotal, b.maxTotal))
            }
            return .check
        }
        if equity < 0.2 && Double.random(in: 0...1) < 0.6 {
            return .fold
        }
        return .call
    }

    // MARK: Medium: uses equity vs pot odds, occasional value raises.
    private static func mediumDecision(equity: Double, potOdds: Double, info: (canCheck: Bool, canCall: Bool, callAmount: Int, raiseBounds: RaiseBounds?), player: Player, pot: Int) -> PlayerAction {
        if info.canCheck {
            if equity > 0.65, let b = info.raiseBounds {
                let size = min(b.maxTotal, b.minTotal + Int(Double(pot) * 0.5))
                return .bet(max(b.minTotal, min(size, b.maxTotal)))
            }
            return .check
        }
        if equity + 0.05 < potOdds {
            return .fold
        }
        if equity > 0.7, let b = info.raiseBounds, Double.random(in: 0...1) < 0.5 {
            let size = min(b.maxTotal, b.minTotal + Int(Double(pot) * 0.6))
            return .raise(max(b.minTotal, min(size, b.maxTotal)))
        }
        return .call
    }

    // MARK: Hard: full equity/pot-odds reasoning plus occasional bluffs and bet sizing.
    private static func hardDecision(equity: Double, potOdds: Double, info: (canCheck: Bool, canCall: Bool, callAmount: Int, raiseBounds: RaiseBounds?), player: Player, pot: Int, engine: GameEngine) -> PlayerAction {
        let bluffRoll = Double.random(in: 0...1)
        let isBluffSpot = bluffRoll < 0.08 && engine.stage != .preflop

        if info.canCheck {
            if equity > 0.6 || isBluffSpot, let b = info.raiseBounds {
                let sizingFactor = equity > 0.85 ? 0.85 : 0.5
                let size = b.minTotal + Int(Double(pot) * sizingFactor)
                return .bet(max(b.minTotal, min(size, b.maxTotal)))
            }
            return .check
        }

        if isBluffSpot, let b = info.raiseBounds, player.stack > info.callAmount * 3 {
            return .raise(min(b.minTotal + Int(Double(pot) * 0.75), b.maxTotal))
        }

        if equity < potOdds - 0.03 {
            return .fold
        }
        if equity > 0.78, let b = info.raiseBounds {
            if equity > 0.92 && Double.random(in: 0...1) < 0.35 {
                return .allIn
            }
            let size = b.minTotal + Int(Double(pot) * 0.75)
            return .raise(max(b.minTotal, min(size, b.maxTotal)))
        }
        return .call
    }
}
