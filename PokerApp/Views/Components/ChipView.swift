import SwiftUI

struct ChipStackView: View {
    let amount: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: -9) {
            ForEach(0..<min(chipCount, 4), id: \.self) { i in
                ChipView(tier: chipTier(for: amount))
                    .zIndex(Double(i))
                    .offset(y: -CGFloat(i) * 2.5)
            }
        }
        .overlay(alignment: .trailing) {
            Text(formatted(amount))
                .font(Frontier.Font.stamp(compact ? 10 : 12))
                .foregroundColor(Frontier.Color.paperHi)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.black.opacity(0.55))
                )
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Frontier.Color.brass.opacity(0.4), lineWidth: 0.8))
                .offset(x: 36)
        }
        .frame(height: compact ? 15 : 19)
    }

    private var chipCount: Int { max(1, min(4, amount / 50 + 1)) }

    private func chipTier(for amount: Int) -> Int {
        switch amount {
        case ..<50: return 0
        case 50..<200: return 1
        case 200..<500: return 2
        case 500..<1000: return 3
        default: return 4
        }
    }

    private func formatted(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}

/// A carved wooden/clay poker chip with an etched ring — no flat pill look.
struct ChipView: View {
    var tier: Int = 1
    var diameter: CGFloat = 17

    private var rimColor: Color {
        switch tier {
        case 0: return Frontier.Color.iron
        case 1: return Frontier.Color.rust
        case 2: return Frontier.Color.sage
        case 3: return Frontier.Color.wood700
        default: return Frontier.Color.brass
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [rimColor.opacity(0.95), rimColor.opacity(0.65)], center: .topLeading, startRadius: 1, endRadius: diameter))
            Circle()
                .strokeBorder(Frontier.Color.brassHi.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, dash: [2.2, 2.2]))
                .padding(1.5)
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .padding(4.5)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1.5)
    }
}

struct PotBadgeView: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 7) {
            ChipView(tier: 4, diameter: 15)
            Text("Piatto: \(amount)")
                .font(Frontier.Font.display(14))
                .foregroundColor(Frontier.Color.ink)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(LinearGradient(colors: [Frontier.Color.paperHi, Frontier.Color.paperLo], startPoint: .top, endPoint: .bottom))
        )
        .overlay(Capsule().stroke(Frontier.Color.ink.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
    }
}
