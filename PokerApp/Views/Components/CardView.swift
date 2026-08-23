import SwiftUI

struct CardView: View {
    let card: Card?
    var isFaceUp: Bool = true
    var width: CGFloat = 56
    var highlighted: Bool = false

    private var height: CGFloat { width * 1.42 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .fill(
                    LinearGradient(colors: [Frontier.Color.paperHi, Frontier.Color.paper],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                        .strokeBorder(highlighted ? Frontier.Color.brassHi : Frontier.Color.ink.opacity(0.35),
                                      lineWidth: highlighted ? 2.5 : 1)
                )
                .overlay(GrainOverlay(opacity: 0.10, blend: .multiply).clipShape(RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)))
                .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 2)

            if let card, isFaceUp {
                VStack(spacing: 1) {
                    Text(card.rank.label)
                        .font(Frontier.Font.bodyBold(width * 0.34))
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.28))
                }
                .foregroundColor(card.suit.isRed ? Frontier.Color.rustDark : Frontier.Color.ink)
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
        RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
            .fill(
                LinearGradient(colors: [Frontier.Color.wood700, Frontier.Color.wood950],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                    .strokeBorder(Frontier.Color.brass.opacity(0.7), lineWidth: 1.5)
                    .padding(2.5)
            )
            .overlay(
                Text("★")
                    .font(.system(size: width * 0.3))
                    .foregroundColor(Frontier.Color.brass.opacity(0.55))
            )
            .frame(width: width, height: width * 1.42)
    }
}

struct EmptyCardSlotView: View {
    var width: CGFloat = 56
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [3, 3]))
            .foregroundColor(Frontier.Color.paperLo.opacity(0.3))
            .frame(width: width, height: width * 1.42)
    }
}
