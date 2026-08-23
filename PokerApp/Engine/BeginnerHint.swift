import Foundation

struct BeginnerHint {
    let equity: Double
    let potOdds: Double?
    let suggestedAction: PlayerAction
    let suggestionLabel: String
    let explanation: String
}

/// Simple, explainable decision rule used only to power Beginner-mode coaching (hints + post-hand analysis).
/// Intentionally simpler/more transparent than BotAI so the reasoning can be explained in plain language.
enum HintEngine {

    static func hint(equity: Double, potOdds: Double?, canCheck: Bool, callAmount: Int, raiseBounds: RaiseBounds?, pot: Int) -> BeginnerHint {
        if canCheck {
            if equity > 0.62, let b = raiseBounds {
                let size = min(b.maxTotal, b.minTotal + Int(Double(pot) * 0.5))
                return BeginnerHint(
                    equity: equity, potOdds: nil, suggestedAction: .bet(size),
                    suggestionLabel: "Punta",
                    explanation: "La tua mano ha circa \(pct(equity))% di probabilità di vincere: conviene puntare per costruire il piatto e mettere pressione agli avversari."
                )
            }
            return BeginnerHint(
                equity: equity, potOdds: nil, suggestedAction: .check,
                suggestionLabel: "Check",
                explanation: "La tua mano non è abbastanza forte da puntare (\(pct(equity))% di equity): controlla e vedi la prossima carta gratis."
            )
        }

        guard let odds = potOdds else {
            return BeginnerHint(equity: equity, potOdds: nil, suggestedAction: .call, suggestionLabel: "Call", explanation: "")
        }

        if equity < odds - 0.03 {
            return BeginnerHint(
                equity: equity, potOdds: odds, suggestedAction: .fold,
                suggestionLabel: "Fold",
                explanation: "Ti serve almeno il \(pct(odds))% di probabilità di vincere per pagare (pot odds), ma la tua mano vale solo \(pct(equity))%: è corretto abbandonare."
            )
        }
        if equity > 0.72, let b = raiseBounds {
            let size = min(b.maxTotal, b.minTotal + Int(Double(pot) * 0.6))
            return BeginnerHint(
                equity: equity, potOdds: odds, suggestedAction: .raise(size),
                suggestionLabel: "Rilancia",
                explanation: "Con il \(pct(equity))% di probabilità di vincere la tua mano è molto forte: rilanciare estrae più valore dagli avversari."
            )
        }
        return BeginnerHint(
            equity: equity, potOdds: odds, suggestedAction: .call,
            suggestionLabel: "Call",
            explanation: "Le pot odds richiedono il \(pct(odds))% di equity e la tua mano ne vale \(pct(equity))%: pagare è la scelta più redditizia nel lungo periodo."
        )
    }

    private static func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
}
