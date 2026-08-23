import SwiftUI

struct HintOverlayView: View {
    let hint: BeginnerHint
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Consiglio: \(hint.suggestionLabel)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("Equity \(Int((hint.equity * 100).rounded()))%")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            Text(hint.explanation)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            EquityBarView(equity: hint.equity, potOdds: hint.potOdds)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.5), lineWidth: 1))
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
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(equity))
                if let potOdds {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(potOdds))
                }
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.3), value: equity)
    }
}
