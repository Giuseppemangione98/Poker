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
            Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 26) {
                Text(beginner ? "Modalità Principiante" : "Modalità Classica")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Numero di avversari: \(Int(opponentCount))")
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                    Slider(value: $opponentCount, in: 1...8, step: 1) { _ in HapticManager.shared.selectionTick() }
                        .tint(.green)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficoltà avversari")
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                    Picker("Difficoltà", selection: $difficulty) {
                        ForEach(BotDifficulty.allCases, id: \.self) { d in
                            Text(d.localizedName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stack iniziale: \(Int(startingStack)) fiches")
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                    Slider(value: $startingStack, in: 500...5000, step: 100) { _ in HapticManager.shared.selectionTick() }
                        .tint(.yellow)
                }
                .padding(.horizontal, 24)

                if beginner {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Suggerimenti in tempo reale", systemImage: "checkmark.circle.fill")
                        Label("Analisi dopo ogni mano", systemImage: "checkmark.circle.fill")
                        Label("Tutorial regole sempre disponibile", systemImage: "checkmark.circle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    HapticManager.shared.buttonTap()
                    stats.settings.preferredOpponentCount = Int(opponentCount)
                    stats.settings.preferredDifficulty = difficulty
                    appState.startGame(beginner: beginner, opponents: Int(opponentCount), difficulty: difficulty, stack: Int(startingStack))
                } label: {
                    Text("Siediti al tavolo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Capsule().fill(Color.green))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
