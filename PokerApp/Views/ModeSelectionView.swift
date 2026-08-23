import SwiftUI

struct ModeSelectionView: View {
    let beginner: Bool
    @EnvironmentObject var appState: AppState
    @StateObject private var stats = StatsStore.shared

    @State private var opponentCount: Double
    @State private var difficulty: BotDifficulty
    @State private var startingStack: Double = 2000

    init(beginner: Bool) {
        self.beginner = beginner
        let settings = StatsStore.shared.settings
        _opponentCount = State(initialValue: Double(settings.preferredOpponentCount))
        _difficulty = State(initialValue: beginner ? .easy : settings.preferredDifficulty)
    }

    var body: some View {
        ZStack {
            LeatherBackground()

            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(beginner ? "Il Contratto" : "La Sfida")
                        .font(Frontier.Font.display(24))
                        .foregroundColor(Frontier.Color.paperHi)
                    Text(beginner ? "Modalità Principiante" : "Modalità Classica")
                        .font(Frontier.Font.stamp(10))
                        .foregroundColor(Frontier.Color.brassHi)

                    if beginner {
                        VStack(alignment: .leading, spacing: 5) {
                            featureRow("Suggerimenti in tempo reale")
                            featureRow("Analisi dopo ogni mano")
                            featureRow("Tutorial sempre disponibile")
                        }
                        .padding(.top, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AVVERSARI AL TAVOLO — \(Int(opponentCount))")
                            .font(Frontier.Font.stamp(10))
                            .foregroundColor(Frontier.Color.paperLo)
                        Slider(value: $opponentCount, in: 1...8, step: 1) { _ in HapticManager.shared.selectionTick() }
                            .tint(Frontier.Color.rust)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIFFICOLTÀ AVVERSARI")
                            .font(Frontier.Font.stamp(10))
                            .foregroundColor(Frontier.Color.paperLo)
                        HStack(spacing: 4) {
                            ForEach(BotDifficulty.allCases, id: \.self) { d in
                                Button(d.localizedName) {
                                    HapticManager.shared.selectionTick()
                                    difficulty = d
                                }
                                .font(Frontier.Font.display(11))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 3).fill(difficulty == d ? Frontier.Color.brass : Color.black.opacity(0.25)))
                                .foregroundColor(difficulty == d ? Frontier.Color.ink : Frontier.Color.paperLo)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("FICHES INIZIALI — \(Int(startingStack))")
                            .font(Frontier.Font.stamp(10))
                            .foregroundColor(Frontier.Color.paperLo)
                        Slider(value: $startingStack, in: 500...5000, step: 100) { _ in HapticManager.shared.selectionTick() }
                            .tint(Frontier.Color.brass)
                    }

                    Button("Siediti al tavolo") {
                        HapticManager.shared.buttonTap()
                        stats.settings.preferredOpponentCount = Int(opponentCount)
                        stats.settings.preferredDifficulty = difficulty
                        appState.startGame(beginner: beginner, opponents: Int(opponentCount), difficulty: difficulty, stack: Int(startingStack))
                    }
                    .buttonStyle(WaxSealButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("✓").font(Frontier.Font.stamp(11)).foregroundColor(Frontier.Color.sage)
            Text(text).font(Frontier.Font.body(12, italic: true)).foregroundColor(Frontier.Color.paperLo)
        }
    }
}
