import SwiftUI

struct CardView: View {
    let card: Card?
    var isFaceUp: Bool = true
    var width: CGFloat = 56
    var highlighted: Bool = false

    private var height: CGFloat { width * 1.4 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                        .stroke(highlighted ? Color.yellow : Color.black.opacity(0.15), lineWidth: highlighted ? 3 : 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)

            if let card, isFaceUp {
                VStack(spacing: 2) {
                    Text(card.rank.label)
                        .font(.system(size: width * 0.34, weight: .bold, design: .rounded))
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.34))
                }
                .foregroundColor(card.suit.isRed ? .red : .black)
            } else {
                CardBackView(width: width)
            }
        }
        .frame(width: width, height: height)
        .rotation3DEffect(.degrees(isFaceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFaceUp)
    }
}

struct CardBackView: View {
    var width: CGFloat = 56
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
            .fill(
                LinearGradient(colors: [Color(red: 0.1, green: 0.25, blue: 0.55), Color(red: 0.05, green: 0.12, blue: 0.3)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                    .padding(3)
            )
            .overlay(
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: width * 0.4))
                    .foregroundColor(.white.opacity(0.25))
            )
            .frame(width: width, height: width * 1.4)
    }
}

struct EmptyCardSlotView: View {
    var width: CGFloat = 56
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            .frame(width: width, height: width * 1.4)
    }
}
