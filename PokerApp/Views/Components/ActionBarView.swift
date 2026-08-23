import SwiftUI

struct ActionBarView: View {
    @ObservedObject var vm: GameViewModel
    @State private var raiseAmount: Double = 0
    @State private var showRaiseSlider = false

    private var engine: GameEngine { vm.engine }

    var body: some View {
        guard let human = engine.humanPlayer else { return AnyView(EmptyView()) }
        let info = engine.availableActions(for: human.id)

        return AnyView(
            VStack(spacing: 10) {
                if showRaiseSlider, let bounds = info.raiseBounds {
                    raiseSlider(bounds: bounds, human: human)
                }
                HStack(spacing: 8) {
                    Button("Fold") {
                        vm.humanFold()
                        showRaiseSlider = false
                    }
                    .buttonStyle(LeatherTagButtonStyle(tint: Frontier.Color.rustDark))

                    if info.canCheck {
                        Button("Check") {
                            vm.humanCheck()
                            showRaiseSlider = false
                        }
                        .buttonStyle(LeatherTagButtonStyle(tint: Frontier.Color.sageDark))
                    } else {
                        Button("Call \(info.callAmount)") {
                            vm.humanCall()
                            showRaiseSlider = false
                        }
                        .buttonStyle(LeatherTagButtonStyle(tint: Frontier.Color.sageDark))
                    }

                    if let bounds = info.raiseBounds {
                        Button(showRaiseSlider ? "Conferma" : (info.canCheck ? "Bet" : "Raise")) {
                            if showRaiseSlider {
                                vm.humanBetOrRaise(Int(raiseAmount), isRaise: !info.canCheck)
                                showRaiseSlider = false
                            } else {
                                raiseAmount = Double(bounds.minTotal)
                                withAnimation { showRaiseSlider = true }
                                HapticManager.shared.selectionTick()
                            }
                        }
                        .buttonStyle(LeatherTagButtonStyle(tint: Frontier.Color.brass))

                        Button("All-in") {
                            vm.humanAllIn()
                            showRaiseSlider = false
                        }
                        .buttonStyle(LeatherTagButtonStyle(tint: Frontier.Color.wood700))
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Frontier.Color.iron.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Frontier.Color.brass.opacity(0.35), lineWidth: 1))
            )
        )
    }

    private func raiseSlider(bounds: RaiseBounds, human: Player) -> some View {
        VStack(spacing: 4) {
            Text("Punta: \(Int(raiseAmount))")
                .font(Frontier.Font.stamp(13))
                .foregroundColor(Frontier.Color.paperHi)
            Slider(value: $raiseAmount, in: Double(bounds.minTotal)...Double(max(bounds.minTotal, bounds.maxTotal)), step: 1)
                .tint(Frontier.Color.brass)
                .onChange(of: raiseAmount) { _ in HapticManager.shared.selectionTick() }
            HStack {
                quickChip("Min") { raiseAmount = Double(bounds.minTotal) }
                quickChip("Piatto") { raiseAmount = Double(min(bounds.maxTotal, engine.potTotal)) }
                quickChip("Max") { raiseAmount = Double(bounds.maxTotal) }
            }
        }
        .padding(.horizontal, 4)
    }

    private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selectionTick()
            action()
        }) {
            Text(title)
                .font(Frontier.Font.stamp(10))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Frontier.Color.paperLo.opacity(0.18)))
                .foregroundColor(Frontier.Color.paperHi)
        }
    }
}
