import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    let engine: GameEngine
    let beginnerMode: Bool
    let statsStore = StatsStore.shared

    @Published var currentHint: BeginnerHint?
    @Published var isBotThinking = false
    @Published var showPostHandSummary = false
    @Published var showTutorial = false
    @Published var dealAnimationTick = 0

    private var cancellables = Set<AnyCancellable>()
    private var lastProcessedTurnPlayerID: UUID?

    init(engine: GameEngine, beginnerMode: Bool) {
        self.engine = engine
        self.beginnerMode = beginnerMode

        engine.$currentToActIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleTurnChanged() }
            .store(in: &cancellables)

        engine.$isHandInProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inProgress in
                if !inProgress { self?.handleHandEnded() }
            }
            .store(in: &cancellables)
    }

    func startFirstHand() {
        HapticManager.shared.cardDealt()
        engine.startNewHand()
        dealAnimationTick += 1
    }

    func startNextHand() {
        showPostHandSummary = false
        currentHint = nil
        HapticManager.shared.cardDealt()
        engine.startNewHand()
        dealAnimationTick += 1
    }

    // MARK: - Turn handling

    private func handleTurnChanged() {
        guard let idx = engine.currentToActIndex else {
            currentHint = nil
            return
        }
        let player = engine.players[idx]
        lastProcessedTurnPlayerID = player.id

        if player.isBot {
            currentHint = nil
            scheduleBotMove(for: player)
        } else if beginnerMode {
            computeHint(for: player)
        }
    }

    private func scheduleBotMove(for player: Player) {
        isBotThinking = true
        let delay = Double.random(in: 0.7...1.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.engine.currentToActPlayer?.id == player.id else { self.isBotThinking = false; return }
            let action = BotAI.decide(engine: self.engine, player: player)
            self.perform(action, for: player.id, isBot: true)
            self.isBotThinking = false
        }
    }

    private func computeHint(for player: Player) {
        let opponents = max(1, engine.playersInHand.count - 1)
        let equity = EquityEstimator.estimateEquity(hole: player.holeCards, community: engine.communityCards, opponents: opponents, iterations: 400)
        let info = engine.availableActions(for: player.id)
        let potOdds: Double? = info.callAmount > 0 ? Double(info.callAmount) / Double(engine.potTotal + info.callAmount) : nil
        currentHint = HintEngine.hint(equity: equity, potOdds: potOdds, canCheck: info.canCheck, callAmount: info.callAmount, raiseBounds: info.raiseBounds, pot: engine.potTotal)
    }

    // MARK: - Human actions

    func humanFold() { performHumanAction(.fold) }
    func humanCheck() { performHumanAction(.check) }
    func humanCall() { performHumanAction(.call) }
    func humanBetOrRaise(_ amount: Int, isRaise: Bool) {
        performHumanAction(isRaise ? .raise(amount) : .bet(amount))
    }
    func humanAllIn() { performHumanAction(.allIn) }

    private func performHumanAction(_ action: PlayerAction) {
        guard let human = engine.humanPlayer else { return }
        perform(action, for: human.id, isBot: false, equity: currentHint?.equity)
    }

    private func perform(_ action: PlayerAction, for playerID: UUID, isBot: Bool, equity: Double? = nil) {
        let ok = engine.perform(action, for: playerID, equityAtDecision: equity)
        guard ok else { return }
        fireHaptics(for: action)
        currentHint = nil
    }

    private func fireHaptics(for action: PlayerAction) {
        switch action {
        case .fold: HapticManager.shared.fold()
        case .check: HapticManager.shared.actionCheckOrCall()
        case .call: HapticManager.shared.actionCheckOrCall()
        case .bet, .raise: HapticManager.shared.actionRaiseOrBet()
        case .allIn: HapticManager.shared.actionAllIn()
        }
    }

    // MARK: - Hand end

    private func handleHandEnded() {
        guard let result = engine.lastHandResult, let human = engine.humanPlayer else { return }
        let humanWon = result.potsWon.contains { $0.winners.contains { $0.id == human.id } }
        if humanWon {
            HapticManager.shared.handWon()
        } else {
            HapticManager.shared.handLost()
        }
        statsStore.recordHandResult(result, humanID: human.id, beginnerMode: beginnerMode)
        if beginnerMode {
            showPostHandSummary = true
        }
    }
}
