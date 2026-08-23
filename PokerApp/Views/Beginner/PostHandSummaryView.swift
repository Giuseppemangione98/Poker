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
        ZStack {
            ParchmentBackground()
            VStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 5) {
                        Text(humanWon ? "Hai vinto la mano" : "Mano persa")
                            .font(Frontier.Font.display(22))
                            .foregroundColor(humanWon ? Frontier.Color.sageDark : Frontier.Color.rustDark)
                        Text("ANALISI DELLE TUE DECISIONI")
                            .font(Frontier.Font.stamp(10))
                            .tracking(1.5)
                            .foregroundColor(Frontier.Color.inkSoft)
                    }
                    if humanWon {
                        Text("APPROVATO")
                            .font(Frontier.Font.display(15))
                            .foregroundColor(Frontier.Color.rustDark.opacity(0.4))
                            .padding(.horizontal, 10).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Frontier.Color.rustDark.opacity(0.4), lineWidth: 2))
                            .rotationEffect(.degrees(-8))
                            .offset(x: 110, y: -6)
                    }
                }
                .padding(.top, 26)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 10) {
                        if humanActions.isEmpty {
                            Text("Non hai preso decisioni in questa mano.")
                                .font(Frontier.Font.body(13, italic: true))
                                .foregroundColor(Frontier.Color.inkSoft)
                                .padding()
                        }
                        ForEach(humanActions) { record in
                            analysisRow(record)
                        }
                    }
                    .padding(.horizontal)
                }

                Button("Prossima mano") {
                    HapticManager.shared.buttonTap()
                    onContinue()
                }
                .buttonStyle(WaxSealButtonStyle(tint: Frontier.Color.sageDark))
                .padding()
            }
        }
    }

    private func analysisRow(_ record: HandActionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.stage.localizedName.uppercased())
                    .font(Frontier.Font.stamp(10))
                    .foregroundColor(Frontier.Color.inkSoft)
                Spacer()
                Text(record.actionLabel)
                    .font(Frontier.Font.bodyBold(14))
                    .foregroundColor(Frontier.Color.ink)
            }
            if let equity = record.equityAtDecision {
                HStack(spacing: 14) {
                    Text("EQUITY \(Int((equity * 100).rounded()))%")
                    if let odds = record.potOddsAtDecision {
                        Text("POT ODDS \(Int((odds * 100).rounded()))%")
                    }
                }
                .font(Frontier.Font.stamp(10))
                .foregroundColor(Frontier.Color.rustDark)

                Text(evaluation(equity: equity, potOdds: record.potOddsAtDecision, action: record.action))
                    .font(Frontier.Font.body(12, italic: true))
                    .foregroundColor(Frontier.Color.inkSoft)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 3).fill(Frontier.Color.ink.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundColor(Frontier.Color.ink.opacity(0.25)))
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
