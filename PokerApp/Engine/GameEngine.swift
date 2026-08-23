import Foundation
import Combine

struct RaiseBounds {
    let minTotal: Int   // minimum total bet size a raise must reach
    let maxTotal: Int   // player's stack + currentBet (all-in)
}

@MainActor
final class GameEngine: ObservableObject {

    // MARK: Config
    let startingStack: Int
    var smallBlind: Int
    var bigBlind: Int
    let blindIncreaseEveryNHands: Int?

    // MARK: Table state
    @Published private(set) var players: [Player]
    @Published private(set) var communityCards: [Card] = []
    @Published private(set) var stage: GameStage = .preflop
    @Published private(set) var dealerIndex: Int = 0
    @Published private(set) var currentToActIndex: Int?
    @Published private(set) var handNumber: Int = 0
    @Published private(set) var isHandInProgress: Bool = false
    @Published private(set) var lastHandResult: HandResult?
    @Published private(set) var actionLog: [HandActionRecord] = []
    @Published private(set) var minRaiseIncrement: Int = 0
    @Published private(set) var lastAggressorIndex: Int?
    @Published var winnerHighlightIDs: Set<UUID> = []

    private var deck = Deck()
    private var smallBlindIndex: Int = 0
    private var bigBlindIndex: Int = 0

    init(playerNames: [String] = [], botCount: Int, difficulty: BotDifficulty, startingStack: Int = 2000, smallBlind: Int = 10, bigBlind: Int = 20, blindIncreaseEveryNHands: Int? = 12, humanName: String = "Tu") {
        self.startingStack = startingStack
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.blindIncreaseEveryNHands = blindIncreaseEveryNHands

        var seats: [Player] = [Player(name: humanName, isBot: false, stack: startingStack, avatarSeed: 0)]
        let botNames = ["Marco", "Luca", "Sara", "Elena", "Paolo", "Giulia", "Franco", "Nina"]
        for i in 0..<botCount {
            seats.append(Player(name: botNames[i % botNames.count], isBot: true, difficulty: difficulty, stack: startingStack, avatarSeed: i + 1))
        }
        self.players = seats
    }

    var humanPlayer: Player? { players.first { !$0.isBot } }
    var humanIndex: Int? { players.firstIndex { !$0.isBot } }

    var potTotal: Int { players.reduce(0) { $0 + $1.totalContribution } }
    var highestCurrentBet: Int { players.map { $0.currentBet }.max() ?? 0 }

    var currentToActPlayer: Player? {
        guard let i = currentToActIndex else { return nil }
        return players[i]
    }

    var playersInHand: [Player] { players.filter { !$0.hasFolded && !$0.isSittingOut } }

    // MARK: - Hand lifecycle

    func startNewHand() {
        guard players.filter({ !$0.isSittingOut && $0.stack > 0 }).count >= 2 else { return }
        handNumber += 1
        if let step = blindIncreaseEveryNHands, step > 0, handNumber > 1, (handNumber - 1) % step == 0 {
            smallBlind *= 2
            bigBlind *= 2
        }

        for i in players.indices {
            players[i].resetForNewHand()
            if players[i].stack <= 0 { players[i].isSittingOut = true }
        }
        communityCards = []
        actionLog = []
        lastHandResult = nil
        winnerHighlightIDs = []
        stage = .preflop
        deck = Deck()

        moveDealerButton()
        postBlinds()
        dealHoleCards()
        setFirstToActPreflop()
        isHandInProgress = true
    }

    private func activeSeatIndices() -> [Int] {
        players.indices.filter { !players[$0].isSittingOut && players[$0].stack > 0 }
    }

    private func moveDealerButton() {
        let active = activeSeatIndices()
        guard !active.isEmpty else { return }
        if handNumber == 1 {
            dealerIndex = active.first!
        } else {
            var idx = (dealerIndex + 1) % players.count
            while players[idx].isSittingOut || players[idx].stack <= 0 {
                idx = (idx + 1) % players.count
            }
            dealerIndex = idx
        }
    }

    private func nextActiveSeat(from index: Int) -> Int {
        var idx = (index + 1) % players.count
        var guardCount = 0
        while (players[idx].isSittingOut || players[idx].stack <= 0) && guardCount < players.count {
            idx = (idx + 1) % players.count
            guardCount += 1
        }
        return idx
    }

    private func postBlinds() {
        let active = activeSeatIndices()
        if active.count == 2 {
            // heads-up: dealer posts small blind
            smallBlindIndex = dealerIndex
            bigBlindIndex = nextActiveSeat(from: dealerIndex)
        } else {
            smallBlindIndex = nextActiveSeat(from: dealerIndex)
            bigBlindIndex = nextActiveSeat(from: smallBlindIndex)
        }
        postForcedBet(at: smallBlindIndex, amount: smallBlind)
        postForcedBet(at: bigBlindIndex, amount: bigBlind)
        minRaiseIncrement = bigBlind
        lastAggressorIndex = bigBlindIndex
    }

    private func postForcedBet(at index: Int, amount: Int) {
        let actual = min(amount, players[index].stack)
        players[index].stack -= actual
        players[index].currentBet += actual
        players[index].totalContribution += actual
        if players[index].stack == 0 { players[index].isAllIn = true }
    }

    private func dealHoleCards() {
        let active = activeSeatIndices()
        for _ in 0..<2 {
            for i in active {
                if let card = deck.draw() { players[i].holeCards.append(card) }
            }
        }
    }

    private func setFirstToActPreflop() {
        let active = activeSeatIndices()
        if active.count == 2 {
            currentToActIndex = smallBlindIndex // dealer/SB acts first heads-up preflop
        } else {
            currentToActIndex = nextActiveSeat(from: bigBlindIndex)
        }
        skipToNextActionableOrEnd()
    }

    // MARK: - Actions

    func availableActions(for playerID: UUID) -> (canCheck: Bool, canCall: Bool, callAmount: Int, raiseBounds: RaiseBounds?) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else {
            return (false, false, 0, nil)
        }
        let player = players[idx]
        let toCall = highestCurrentBet - player.currentBet
        let canCheck = toCall <= 0
        let canCall = toCall > 0 && player.stack > 0
        let minRaiseTotal = highestCurrentBet + minRaiseIncrement
        let maxTotal = player.currentBet + player.stack
        let raiseBounds: RaiseBounds? = player.stack > toCall ? RaiseBounds(minTotal: min(minRaiseTotal, maxTotal), maxTotal: maxTotal) : nil
        return (canCheck, canCall, max(toCall, 0), raiseBounds)
    }

    @discardableResult
    func perform(_ action: PlayerAction, for playerID: UUID, equityAtDecision: Double? = nil) -> Bool {
        guard let idx = players.firstIndex(where: { $0.id == playerID }), idx == currentToActIndex else { return false }
        var player = players[idx]
        let potBefore = potTotal
        let toCall = highestCurrentBet - player.currentBet
        let potOdds: Double? = toCall > 0 ? Double(toCall) / Double(potBefore + toCall) : nil
        var amountLogged = 0

        switch action {
        case .fold:
            player.hasFolded = true

        case .check:
            guard toCall <= 0 else { return false }

        case .call:
            let amount = min(toCall, player.stack)
            player.stack -= amount
            player.currentBet += amount
            player.totalContribution += amount
            if player.stack == 0 { player.isAllIn = true }
            amountLogged = amount

        case .bet(let amount), .raise(let amount):
            let targetTotal = amount
            let addition = max(0, min(targetTotal - player.currentBet, player.stack))
            let raiseSize = targetTotal - highestCurrentBet
            player.stack -= addition
            player.currentBet += addition
            player.totalContribution += addition
            if player.stack == 0 { player.isAllIn = true }
            if raiseSize > 0 { minRaiseIncrement = max(minRaiseIncrement, raiseSize) }
            lastAggressorIndex = idx
            resetOthersActedFlag(except: idx)
            amountLogged = addition

        case .allIn:
            let addition = player.stack
            let newTotal = player.currentBet + addition
            player.stack = 0
            player.currentBet = newTotal
            player.totalContribution += addition
            player.isAllIn = true
            if newTotal > highestCurrentBet {
                let raiseSize = newTotal - highestCurrentBet
                minRaiseIncrement = max(minRaiseIncrement, raiseSize)
                lastAggressorIndex = idx
                resetOthersActedFlag(except: idx)
            }
            amountLogged = addition
        }

        player.hasActedThisRound = true
        player.lastAction = action
        players[idx] = player

        actionLog.append(HandActionRecord(
            stage: stage, playerID: player.id, playerName: player.name, action: action,
            amount: amountLogged, potBefore: potBefore, equityAtDecision: equityAtDecision,
            potOddsAtDecision: potOdds, recommendedAction: nil
        ))

        advanceTurn()
        return true
    }

    private func resetOthersActedFlag(except idx: Int) {
        for i in players.indices where i != idx && players[i].canAct {
            players[i].hasActedThisRound = false
        }
    }

    private func advanceTurn() {
        if playersInHand.count <= 1 {
            currentToActIndex = nil
            finishHandByFold()
            return
        }
        guard let cur = currentToActIndex else { return }
        var idx = nextActiveSeat(from: cur)
        var guardCount = 0
        while guardCount < players.count {
            if isBettingRoundOver() {
                currentToActIndex = nil
                proceedToNextStage()
                return
            }
            if players[idx].canAct && !players[idx].hasActedThisRound {
                currentToActIndex = idx
                return
            }
            idx = nextActiveSeat(from: idx)
            guardCount += 1
        }
        currentToActIndex = nil
        proceedToNextStage()
    }

    private func skipToNextActionableOrEnd() {
        guard let cur = currentToActIndex else { return }
        if players[cur].canAct { return }
        var idx = cur
        var guardCount = 0
        while guardCount < players.count {
            if players[idx].canAct { currentToActIndex = idx; return }
            idx = nextActiveSeat(from: idx)
            guardCount += 1
        }
        currentToActIndex = nil
        proceedToNextStage()
    }

    private func isBettingRoundOver() -> Bool {
        let contenders = players.filter { !$0.hasFolded && !$0.isSittingOut }
        let stillCanAct = contenders.filter { !$0.isAllIn }
        if stillCanAct.isEmpty { return true }
        let target = highestCurrentBet
        return stillCanAct.allSatisfy { $0.currentBet == target && $0.hasActedThisRound }
    }

    // MARK: - Street progression

    private func proceedToNextStage() {
        for i in players.indices { players[i].resetForNewBettingRound() }

        switch stage {
        case .preflop:
            communityCards += deck.draw(3)
            stage = .flop
        case .flop:
            communityCards += deck.draw(1)
            stage = .turn
        case .turn:
            communityCards += deck.draw(1)
            stage = .river
        case .river:
            stage = .showdown
            resolveShowdown()
            return
        case .showdown:
            return
        }

        let remainingCanAct = players.filter { $0.canAct }.count
        if remainingCanAct < 2 {
            // everyone all-in (or only one can act): auto-run remaining streets
            proceedToNextStage()
            return
        }

        currentToActIndex = nextActiveSeat(from: dealerIndex)
        skipToNextActionableOrEnd()
    }

    private func finishHandByFold() {
        let winnerIdx = players.firstIndex { !$0.hasFolded && !$0.isSittingOut }
        let pots = PotCalculator.buildPots(players: players)
        var results: [(Pot, [Player], RankedHand?)] = []
        for pot in pots {
            if let wi = winnerIdx {
                players[wi].stack += pot.amount
                results.append((pot, [players[wi]], nil))
            }
        }
        if let wi = winnerIdx { winnerHighlightIDs = [players[wi].id] }
        lastHandResult = HandResult(potsWon: results, allPlayersAtShowdown: players, actionLog: actionLog, handNumber: handNumber)
        isHandInProgress = false
    }

    @discardableResult
    func resolveShowdown() -> HandResult {
        let pots = PotCalculator.buildPots(players: players)
        var results: [(Pot, [Player], RankedHand?)] = []
        var winnerIDs: Set<UUID> = []

        for pot in pots {
            let eligible = players.filter { pot.eligiblePlayerIDs.contains($0.id) && !$0.hasFolded }
            guard !eligible.isEmpty else { continue }
            let ranked: [(Player, RankedHand)] = eligible.map { p in
                (p, HandEvaluator.bestHand(from: p.holeCards + communityCards))
            }
            let best = ranked.map { $0.1 }.max()!
            let winners = ranked.filter { $0.1 == best }.map { $0.0 }
            let share = pot.amount / winners.count
            var remainder = pot.amount % winners.count
            for w in winners {
                if let idx = players.firstIndex(where: { $0.id == w.id }) {
                    var amount = share
                    if remainder > 0 { amount += 1; remainder -= 1 }
                    players[idx].stack += amount
                    winnerIDs.insert(w.id)
                }
            }
            results.append((pot, winners, best))
        }

        winnerHighlightIDs = winnerIDs
        let result = HandResult(potsWon: results, allPlayersAtShowdown: players, actionLog: actionLog, handNumber: handNumber)
        lastHandResult = result
        isHandInProgress = false
        return result
    }

    // MARK: - Elimination check

    var isGameOver: Bool {
        players.filter { $0.stack > 0 && !$0.isSittingOut }.count < 2
    }
}
