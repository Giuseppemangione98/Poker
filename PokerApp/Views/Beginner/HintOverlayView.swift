import SwiftUI

struct HintOverlayView: View {
    let hint: BeginnerHint
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Consiglio: \(hint.suggestionLabel)")
                    .font(Frontier.Font.display(14))
                    .foregroundColor(Frontier.Color.ink)
                Spacer()
                Text("EQUITY \(Int((hint.equity * 100).rounded()))%")
                    .font(Frontier.Font.stamp(10))
                    .foregroundColor(Frontier.Color.rustDark)
            }
            Text(hint.explanation)
                .font(Frontier.Font.body(11.5, italic: true))
                .foregroundColor(Frontier.Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            EquityBarView(equity: hint.equity, potOdds: hint.potOdds)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Frontier.Color.paperHi, Frontier.Color.paperLo], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Frontier.Color.ink.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

struct EquityBarView: View {
    let equity: Double
    let potOdds: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Frontier.Color.ink.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [Frontier.Color.rustDark, Frontier.Color.brass, Frontier.Color.sage], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(equity))
                if let potOdds {
                    Rectangle()
                        .fill(Frontier.Color.ink)
                        .frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(potOdds))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.3), value: equity)
    }
}
