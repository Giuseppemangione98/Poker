import SwiftUI

struct ChipStackView: View {
    let amount: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: -10) {
            ForEach(0..<min(chipCount, 4), id: \.self) { i in
                ChipView(color: chipColor(for: amount))
                    .zIndex(Double(i))
                    .offset(y: -CGFloat(i) * 3)
            }
        }
        .overlay(alignment: .trailing) {
            Text(formatted(amount))
                .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .offset(x: 34)
        }
        .frame(height: compact ? 16 : 20)
    }

    private var chipCount: Int { max(1, min(4, amount / 50 + 1)) }

    private func chipColor(for amount: Int) -> Color {
        switch amount {
        case ..<50: return .gray
        case 50..<200: return .red
        case 200..<500: return .blue
        case 500..<1000: return .green
        default: return .black
        }
    }

    private func formatted(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}

struct ChipView: View {
    var color: Color = .red
    var diameter: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .overlay(Circle().stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [3, 3])))
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .padding(3)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 1)
    }
}

struct PotBadgeView: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            ChipView(color: .yellow, diameter: 16)
            Text("Piatto: \(amount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().stroke(Color.yellow.opacity(0.6), lineWidth: 1))
    }
}
