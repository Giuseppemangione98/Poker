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
                HStack(spacing: 10) {
                    actionButton(title: "Fold", color: .red.opacity(0.85)) {
                        vm.humanFold()
                        showRaiseSlider = false
                    }

                    if info.canCheck {
                        actionButton(title: "Check", color: .blue.opacity(0.85)) {
                            vm.humanCheck()
                            showRaiseSlider = false
                        }
                    } else {
                        actionButton(title: "Call \(info.callAmount)", color: .blue.opacity(0.85)) {
                            vm.humanCall()
                            showRaiseSlider = false
                        }
                    }

                    if let bounds = info.raiseBounds {
                        actionButton(title: showRaiseSlider ? "Conferma" : (info.canCheck ? "Bet" : "Raise"), color: .green.opacity(0.9)) {
                            if showRaiseSlider {
                                vm.humanBetOrRaise(Int(raiseAmount), isRaise: !info.canCheck)
                                showRaiseSlider = false
                            } else {
                                raiseAmount = Double(bounds.minTotal)
                                withAnimation { showRaiseSlider = true }
                                HapticManager.shared.selectionTick()
                            }
                        }
                        actionButton(title: "All-in", color: .purple.opacity(0.9)) {
                            vm.humanAllIn()
                            showRaiseSlider = false
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.55)))
        )
    }

    private func raiseSlider(bounds: RaiseBounds, human: Player) -> some View {
        VStack(spacing: 4) {
            Text("Punta: \(Int(raiseAmount))")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Slider(value: $raiseAmount, in: Double(bounds.minTotal)...Double(max(bounds.minTotal, bounds.maxTotal)), step: 1)
                .tint(.green)
                .onChange(of: raiseAmount) { _ in HapticManager.shared.selectionTick() }
            HStack {
                quickChip("Min") { raiseAmount = Double(bounds.minTotal) }
                quickChip("Pot") { raiseAmount = Double(min(bounds.maxTotal, engine.potTotal)) }
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
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.15)))
                .foregroundColor(.white)
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
                .foregroundColor(.white)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
