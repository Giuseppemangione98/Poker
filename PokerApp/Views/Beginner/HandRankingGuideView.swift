import SwiftUI

struct HandRankingExample: Identifiable {
    let id = UUID()
    let category: HandCategory
    let cards: [Card]
    let description: String
}

enum HandRankingCatalog {
    static let examples: [HandRankingExample] = [
        .init(category: .straightFlush, cards: [c(.nine, .hearts), c(.ten, .hearts), c(.jack, .hearts), c(.queen, .hearts), c(.king, .hearts)], description: "Cinque carte dello stesso seme in sequenza. La mano più forte in assoluto."),
        .init(category: .quads, cards: [c(.ace, .clubs), c(.ace, .diamonds), c(.ace, .hearts), c(.ace, .spades), c(.king, .clubs)], description: "Quattro carte dello stesso valore."),
        .init(category: .fullHouse, cards: [c(.king, .clubs), c(.king, .diamonds), c(.king, .hearts), c(.four, .clubs), c(.four, .spades)], description: "Un tris più una coppia."),
        .init(category: .flush, cards: [c(.two, .spades), c(.six, .spades), c(.nine, .spades), c(.jack, .spades), c(.king, .spades)], description: "Cinque carte dello stesso seme, non in sequenza."),
        .init(category: .straight, cards: [c(.five, .clubs), c(.six, .diamonds), c(.seven, .hearts), c(.eight, .spades), c(.nine, .clubs)], description: "Cinque carte in sequenza, semi diversi."),
        .init(category: .trips, cards: [c(.eight, .clubs), c(.eight, .diamonds), c(.eight, .hearts), c(.two, .spades), c(.five, .clubs)], description: "Tre carte dello stesso valore."),
        .init(category: .twoPair, cards: [c(.jack, .clubs), c(.jack, .diamonds), c(.four, .hearts), c(.four, .spades), c(.nine, .clubs)], description: "Due coppie diverse."),
        .init(category: .pair, cards: [c(.ten, .clubs), c(.ten, .diamonds), c(.two, .hearts), c(.six, .spades), c(.nine, .clubs)], description: "Due carte dello stesso valore."),
        .init(category: .highCard, cards: [c(.two, .clubs), c(.seven, .diamonds), c(.nine, .hearts), c(.jack, .spades), c(.king, .clubs)], description: "Nessuna combinazione: vince la carta più alta.")
    ]

    private static func c(_ rank: Rank, _ suit: Suit) -> Card { Card(rank: rank, suit: suit) }
}

struct HandRankingGuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(HandRankingCatalog.examples.enumerated()), id: \.element.id) { index, example in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.category.localizedName)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(example.description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        HStack(spacing: -10) {
                            ForEach(example.cards) { card in
                                CardView(card: card, width: 30)
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                }
            }
            .padding()
        }
        .background(Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea())
    }
}
