import SwiftUI

struct TableView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExitConfirm = false
    @State private var showTutorialSheet = false

    private var engine: GameEngine { vm.engine }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TableFeltBackground()

                // Community cards + pot
                VStack(spacing: 10) {
                    PotBadgeView(amount: engine.potTotal)
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { i in
                            if i < engine.communityCards.count {
                                CardView(card: engine.communityCards[i], isFaceUp: true, width: geo.size.width * 0.095)
                                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            } else {
                                EmptyCardSlotView(width: geo.size.width * 0.095)
                            }
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: engine.communityCards.count)
                    Text(engine.stage.localizedName)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.36)

                // Seats
                ForEach(Array(seatLayout(in: geo.size).enumerated()), id: \.offset) { _, entry in
                    let (player, point, isHuman) = entry
                    PlayerSeatView(
                        player: player,
                        isCurrentToAct: engine.currentToActPlayer?.id == player.id,
                        isDealer: engine.players[safe: engine.dealerIndex]?.id == player.id,
                        isWinner: engine.winnerHighlightIDs.contains(player.id),
                        showCards: isHuman || engine.stage == .showdown && !player.hasFolded,
                        equityText: nil
                    )
                    .pulseGlow(active: engine.winnerHighlightIDs.contains(player.id))
                    .position(point)
                }

                WinCelebrationView(isActive: !engine.winnerHighlightIDs.isEmpty)

                VStack {
                    topBar
                    Spacer()
                    if let hint = vm.currentHint, vm.beginnerMode {
                        HintOverlayView(hint: hint)
                            .padding(.bottom, 6)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    bottomControls
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if !engine.isHandInProgress && engine.lastHandResult != nil && !vm.showPostHandSummary {
                    nextHandOverlay
                }

                if vm.showPostHandSummary, let result = engine.lastHandResult {
                    PostHandSummaryView(result: result, humanID: engine.humanPlayer?.id, onContinue: {
                        vm.startNextHand()
                    })
                    .transition(.opacity)
                }
            }
        }
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            if engine.handNumber == 0 { vm.startFirstHand() }
        }
        .alert("Uscire dal tavolo?", isPresented: $showExitConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Esci", role: .destructive) { dismiss() }
        }
        .sheet(isPresented: $showTutorialSheet) {
            TutorialView()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                HapticManager.shared.buttonTap()
                showExitConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text("Mano #\(engine.handNumber)  ·  Blind \(engine.smallBlind)/\(engine.bigBlind)")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            if vm.beginnerMode {
                Button {
                    HapticManager.shared.buttonTap()
                    showTutorialSheet = true
                } label: {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                }
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
    }

    private var bottomControls: some View {
        Group {
            if let human = engine.humanPlayer, engine.currentToActPlayer?.id == human.id, engine.isHandInProgress {
                ActionBarView(vm: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if vm.isBotThinking {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("L'avversario sta pensando…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: engine.currentToActIndex)
    }

    private var nextHandOverlay: some View {
        VStack(spacing: 14) {
            if let result = engine.lastHandResult, let firstWinner = result.potsWon.first?.winners.first {
                Text("\(firstWinner.name) vince la mano!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                if let hand = result.potsWon.first?.rankedHand {
                    Text(hand.description)
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
            }
            if engine.isGameOver {
                Text("Partita terminata")
                    .font(.headline)
                    .foregroundColor(.white)
                Button("Torna al menu") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button {
                    HapticManager.shared.buttonTap()
                    vm.startNextHand()
                } label: {
                    Text("Prossima mano")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.green))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.75)))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Seat layout

    private func seatLayout(in size: CGSize) -> [(Player, CGPoint, Bool)] {
        let players = engine.players
        guard let humanIdx = engine.humanIndex else { return [] }
        let count = players.count
        let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
        let radiusX = size.width * 0.44
        let radiusY = size.height * 0.30

        var results: [(Player, CGPoint, Bool)] = []
        for offset in 0..<count {
            let idx = (humanIdx + offset) % count
            let isHuman = offset == 0
            let fraction = Double(offset) / Double(count)
            // Start at bottom (90deg) and go clockwise around the ellipse
            let angle = (Double.pi / 2) + fraction * (2 * Double.pi)
            let x = center.x + radiusX * cos(angle)
            let y = center.y + radiusY * sin(angle)
            results.append((players[idx], CGPoint(x: x, y: y), isHuman))
        }
        return results
    }
}

struct TableFeltBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.08, green: 0.35, blue: 0.2), Color(red: 0.02, green: 0.15, blue: 0.09)],
                            center: .center, startRadius: 10, endRadius: 500)
            Ellipse()
                .stroke(Color.black.opacity(0.4), lineWidth: 18)
                .padding(30)
            Ellipse()
                .stroke(Color.white.opacity(0.08), lineWidth: 2)
                .padding(34)
        }
        .ignoresSafeArea()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
