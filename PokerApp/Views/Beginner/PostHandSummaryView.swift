import SwiftUI

struct PostHandSummaryView: View {
    let result: HandResult
    let humanID: UUID?
    let onContinue: () -> Void

    private var humanActions: [HandActionRecord] {
        guard let humanID else { return [] }
        return result.actionLog.filter { $0.playerID == humanID }
    }

    private var humanWon: Bool {
        guard let humanID else { return false }
        return result.potsWon.contains { $0.winners.contains { $0.id == humanID } }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(humanWon ? "Hai vinto la mano! 🎉" : "Mano persa")
                    .font(.title2.bold())
                    .foregroundColor(humanWon ? .green : .white)
                Text("Analisi delle tue decisioni")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    if humanActions.isEmpty {
                        Text("Non hai preso decisioni in questa mano.")
                            .foregroundColor(.white.opacity(0.6))
                            .padding()
                    }
                    ForEach(humanActions) { record in
                        analysisRow(record)
                    }
                }
                .padding(.horizontal)
            }

            Button {
                HapticManager.shared.buttonTap()
                onContinue()
            } label: {
                Text("Prossima mano")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Capsule().fill(Color.green))
                    .foregroundColor(.white)
            }
            .padding()
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.13).ignoresSafeArea())
    }

    private func analysisRow(_ record: HandActionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.stage.localizedName)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(record.actionLabel)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            if let equity = record.equityAtDecision {
                HStack(spacing: 12) {
                    Label("Equity \(Int((equity * 100).rounded()))%", systemImage: "chart.pie.fill")
                    if let odds = record.potOddsAtDecision {
                        Label("Pot odds \(Int((odds * 100).rounded()))%", systemImage: "divide.circle.fill")
                    }
                }
                .font(.caption)
                .foregroundColor(.yellow)

                Text(evaluation(equity: equity, potOdds: record.potOddsAtDecision, action: record.action))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    private func evaluation(equity: Double, potOdds: Double?, action: PlayerAction) -> String {
        guard let potOdds else {
            if case .check = action { return "Check corretto: non c'era nulla da pagare." }
            return equity > 0.55 ? "Buona scelta di puntare con una mano forte." : "Attenzione: puntare con equity bassa è rischioso senza un piano di bluff."
        }
        let wasCallOrRaise: Bool
        switch action {
        case .call, .bet, .raise, .allIn: wasCallOrRaise = true
        default: wasCallOrRaise = false
        }
        if wasCallOrRaise {
            return equity >= potOdds ? "Decisione corretta: la tua equity superava le pot odds richieste." : "Decisione rischiosa: la tua equity era inferiore alle pot odds. Valuta il fold in situazioni simili."
        } else {
            return equity < potOdds ? "Fold corretto: l'equity non giustificava il pagamento." : "Fold probabilmente evitabile: la tua equity era sufficiente rispetto alle pot odds."
        }
    }
}
