import SwiftUI

struct StatsView: View {
    @StateObject private var store = StatsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statCard(title: "Mani giocate", value: "\(store.stats.handsPlayed)")
                statCard(title: "Mani vinte", value: "\(store.stats.handsWon)  (\(percent(store.stats.winRate)))")
                statCard(title: "Piatto più grande vinto", value: "\(store.stats.biggestPotWon)")
                statCard(title: "Fiches totali vinte", value: "\(store.stats.totalChipsWon)")
                statCard(title: "VPIP (% mani giocate volontariamente)", value: percent(store.stats.vpipPercentage))
                statCard(title: "PFR (% rilanci preflop)", value: percent(store.stats.pfrPercentage))
                statCard(title: "Mani completate in modalità Principiante", value: "\(store.stats.handsCompletedInBeginnerMode)")
            }
            .padding()
        }
        .background(Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea())
        .navigationTitle("Statistiche")
        .preferredColorScheme(.dark)
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    private func statCard(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value).font(.headline).foregroundColor(.white)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}
