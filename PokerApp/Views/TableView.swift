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
                VStack(spacing: 9) {
                    PotBadgeView(amount: engine.potTotal)
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { i in
                            if i < engine.communityCards.count {
                                CardView(card: engine.communityCards[i], isFaceUp: true, width: geo.size.width * 0.09)
                                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            } else {
                                EmptyCardSlotView(width: geo.size.width * 0.09)
                            }
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: engine.communityCards.count)
                    Text(engine.stage.localizedName.uppercased())
                        .font(Frontier.Font.stamp(10))
                        .tracking(2)
                        .foregroundColor(Frontier.Color.paperLo.opacity(0.8))
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
                    .foregroundColor(Frontier.Color.paperLo.opacity(0.85))
            }
            Spacer()
            Text("Mano N.\(engine.handNumber) · Puntate \(engine.smallBlind)/\(engine.bigBlind)")
                .font(Frontier.Font.stamp(10.5))
                .foregroundColor(Frontier.Color.paperLo.opacity(0.8))
            Spacer()
            if vm.beginnerMode {
                Button {
                    HapticManager.shared.buttonTap()
                    showTutorialSheet = true
                } label: {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundColor(Frontier.Color.brassHi)
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
                    ProgressView().tint(Frontier.Color.paperHi)
                    Text("L'avversario riflette…")
                        .font(Frontier.Font.body(12, italic: true))
                        .foregroundColor(Frontier.Color.paperLo)
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
                    .font(Frontier.Font.display(22))
                    .foregroundColor(Frontier.Color.paperHi)
                if let hand = result.potsWon.first?.rankedHand {
                    Text(hand.description)
                        .font(Frontier.Font.stamp(13))
                        .foregroundColor(Frontier.Color.brassHi)
                }
            }
            if engine.isGameOver {
                Text("Partita terminata")
                    .font(Frontier.Font.bodyBold(16))
                    .foregroundColor(Frontier.Color.paperHi)
                Button("Torna al menu") { dismiss() }
                    .buttonStyle(WaxSealButtonStyle(tint: Frontier.Color.wood700))
            } else {
                Button("Prossima mano") {
                    HapticManager.shared.buttonTap()
                    vm.startNextHand()
                }
                .buttonStyle(WaxSealButtonStyle())
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Frontier.Color.iron.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Frontier.Color.brass.opacity(0.5), lineWidth: 1))
        )
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
            let angle = (Double.pi / 2) + fraction * (2 * Double.pi)
            let x = center.x + radiusX * cos(angle)
            let y = center.y + radiusY * sin(angle)
            results.append((players[idx], CGPoint(x: x, y: y), isHuman))
        }
        return results
    }
}

/// Worn red baize table with a rough-hewn wooden rail and brass tack studs.
struct TableFeltBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Frontier.Color.wood950.ignoresSafeArea()

                RadialGradient(
                    colors: [Frontier.Color.rust.opacity(0.9), Frontier.Color.rustDark, Frontier.Color.feltDark],
                    center: .center, startRadius: 10, endRadius: max(geo.size.width, geo.size.height) * 0.6
                )
                .clipShape(Ellipse().inset(by: min(geo.size.width, geo.size.height) * 0.05))

                Ellipse()
                    .inset(by: min(geo.size.width, geo.size.height) * 0.05)
                    .stroke(
                        LinearGradient(colors: [Frontier.Color.wood700, Frontier.Color.wood950], startPoint: .top, endPoint: .bottom),
                        lineWidth: 14
                    )
                Ellipse()
                    .inset(by: min(geo.size.width, geo.size.height) * 0.05 + 8)
                    .stroke(Frontier.Color.brass.opacity(0.3), lineWidth: 1)

                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) / 10 * 2 * Double.pi
                    let rx = geo.size.width * 0.44
                    let ry = geo.size.height * 0.30
                    Circle()
                        .fill(Frontier.Color.brassHi.opacity(0.55))
                        .frame(width: 3, height: 3)
                        .position(x: geo.size.width / 2 + rx * cos(angle), y: geo.size.height * 0.46 + ry * sin(angle))
                }

                GrainOverlay(opacity: 0.08, blend: .overlay)
            }
        }
        .ignoresSafeArea()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
