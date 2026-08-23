import SwiftUI

struct PlayerSeatView: View {
    let player: Player
    let isCurrentToAct: Bool
    let isDealer: Bool
    let isWinner: Bool
    let showCards: Bool
    var equityText: String? = nil

    private let avatarTints: [Color] = [Frontier.Color.rust, Frontier.Color.sage, Frontier.Color.brass, Frontier.Color.wood700, Frontier.Color.rustDark, Frontier.Color.sageDark]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: -13) {
                ForEach(player.holeCards.indices, id: \.self) { i in
                    CardView(card: player.holeCards[i], isFaceUp: showCards, width: 32, highlighted: isWinner)
                }
                if player.holeCards.isEmpty {
                    EmptyCardSlotView(width: 32)
                    EmptyCardSlotView(width: 32)
                }
            }

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(avatarTints[player.avatarSeed % avatarTints.count])
                        .frame(width: 20, height: 20)
                        .overlay(Text(String(player.name.prefix(1))).font(Frontier.Font.display(10)).foregroundColor(Frontier.Color.paperHi))
                        .overlay(Circle().stroke(Frontier.Color.brass.opacity(0.5), lineWidth: 1))
                    Text(player.name)
                        .font(Frontier.Font.body(11.5))
                        .fontWeight(.semibold)
                        .foregroundColor(Frontier.Color.paperHi)
                        .lineLimit(1)
                    if isDealer {
                        Text("D")
                            .font(Frontier.Font.display(9))
                            .foregroundColor(Frontier.Color.ink)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(Frontier.Color.brassHi))
                    }
                }
                Text("\(player.stack)")
                    .font(Frontier.Font.stamp(11))
                    .foregroundColor(Frontier.Color.brassHi)

                if let equityText {
                    Text(equityText)
                        .font(Frontier.Font.stamp(9))
                        .foregroundColor(Frontier.Color.rust)
                }

                if let action = player.lastAction, !player.hasFolded {
                    Text(actionLabel(action))
                        .font(Frontier.Font.stamp(9))
                        .foregroundColor(Frontier.Color.paperLo)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(player.hasFolded ? 0.28 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(isCurrentToAct ? Frontier.Color.brassHi : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: isCurrentToAct ? Frontier.Color.brassHi.opacity(0.55) : .clear, radius: isCurrentToAct ? 7 : 0)

            if player.currentBet > 0 {
                ChipStackView(amount: player.currentBet, compact: true)
            }
        }
        .opacity(player.hasFolded ? 0.42 : 1.0)
        .scaleEffect(isWinner ? 1.08 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isCurrentToAct)
        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: isWinner)
    }

    private func actionLabel(_ action: PlayerAction) -> String {
        switch action {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call"
        case .bet: return "Bet"
        case .raise: return "Raise"
        case .allIn: return "All-in"
        }
    }
}
