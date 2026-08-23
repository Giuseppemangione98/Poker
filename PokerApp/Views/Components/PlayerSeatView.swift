import SwiftUI

struct PlayerSeatView: View {
    let player: Player
    let isCurrentToAct: Bool
    let isDealer: Bool
    let isWinner: Bool
    let showCards: Bool
    var equityText: String? = nil

    private let avatarColors: [Color] = [.purple, .orange, .teal, .pink, .indigo, .mint, .brown, .cyan, .yellow]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: -14) {
                ForEach(player.holeCards.indices, id: \.self) { i in
                    CardView(card: player.holeCards[i], isFaceUp: showCards, width: 34, highlighted: isWinner)
                }
                if player.holeCards.isEmpty {
                    EmptyCardSlotView(width: 34)
                    EmptyCardSlotView(width: 34)
                }
            }

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(avatarColors[player.avatarSeed % avatarColors.count])
                        .frame(width: 22, height: 22)
                        .overlay(Text(String(player.name.prefix(1))).font(.caption2.bold()).foregroundColor(.white))
                    Text(player.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if isDealer {
                        Text("D")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.black)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.white))
                    }
                }
                Text("\(player.stack)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.green.opacity(0.9))

                if let equityText {
                    Text(equityText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                }

                if let action = player.lastAction, !player.hasFolded {
                    Text(actionLabel(action))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(player.hasFolded ? 0.25 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isCurrentToAct ? Color.yellow : Color.clear, lineWidth: 2)
            )
            .shadow(color: isCurrentToAct ? .yellow.opacity(0.6) : .clear, radius: isCurrentToAct ? 8 : 0)

            if player.currentBet > 0 {
                ChipStackView(amount: player.currentBet, compact: true)
            }
        }
        .opacity(player.hasFolded ? 0.4 : 1.0)
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
