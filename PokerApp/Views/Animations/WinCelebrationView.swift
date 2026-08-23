import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let delay: Double
    let color: Color
    let rotation: Double
}

struct WinCelebrationView: View {
    let isActive: Bool
    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false

    private let colors: [Color] = [.yellow, .red, .green, .blue, .purple, .orange, .white]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8, height: 14)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: animate ? geo.size.height + 30 : -30)
                        .animation(.easeIn(duration: Double.random(in: 1.4...2.2)).delay(piece.delay), value: animate)
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    generate(width: geo.size.width)
                    animate = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animate = true }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func generate(width: CGFloat) {
        pieces = (0..<40).map { _ in
            ConfettiPiece(x: CGFloat.random(in: 0...width), delay: Double.random(in: 0...0.4), color: colors.randomElement()!, rotation: Double.random(in: 0...360))
        }
    }
}

struct PulseGlow: ViewModifier {
    let active: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? Color.yellow.opacity(pulsing ? 0.9 : 0.3) : .clear, radius: pulsing ? 16 : 6)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

extension View {
    func pulseGlow(active: Bool) -> some View { modifier(PulseGlow(active: active)) }
}
