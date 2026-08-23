import SwiftUI

struct StatsView: View {
    @StateObject private var store = StatsStore.shared

    private var rows: [(String, String)] {
        [
            ("Mani giocate", "\(store.stats.handsPlayed)"),
            ("Mani vinte", "\(store.stats.handsWon)  ·  \(percent(store.stats.winRate))"),
            ("Piatto più grande vinto", "\(store.stats.biggestPotWon)"),
            ("Fiches totali vinte", "\(store.stats.totalChipsWon)"),
            ("VPIP — mani giocate volontariamente", percent(store.stats.vpipPercentage)),
            ("PFR — rilanci preflop", percent(store.stats.pfrPercentage)),
            ("Mani in modalità Principiante", "\(store.stats.handsCompletedInBeginnerMode)")
        ]
    }

    var body: some View {
        ZStack {
            ParchmentBackground()
            VStack(alignment: .leading, spacing: 4) {
                Text("Il Libro Mastro")
                    .font(Frontier.Font.display(26))
                    .foregroundColor(Frontier.Color.ink)
                    .padding(.top, 14)
                Text("STATISTICHE DEL GIOCATORE")
                    .font(Frontier.Font.stamp(10))
                    .tracking(1.5)
                    .foregroundColor(Frontier.Color.rustDark)
                    .padding(.bottom, 6)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .lastTextBaseline) {
                        Text(row.0)
                            .font(Frontier.Font.body(13, italic: true))
                            .foregroundColor(Frontier.Color.inkSoft)
                        Spacer(minLength: 8)
                        Text(row.1)
                            .font(Frontier.Font.stamp(15))
                            .foregroundColor(Frontier.Color.rustDark)
                    }
                    .padding(.vertical, 6)
                    Rectangle().fill(Frontier.Color.ink.opacity(0.12)).frame(height: 1)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}
