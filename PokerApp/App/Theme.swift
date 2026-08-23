import SwiftUI

/// Frontier / Old-West design language: worn red felt, brass, saddle leather, aged parchment.
enum Frontier {

    // MARK: Palette
    enum Color {
        static let wood950 = SwiftUI.Color(hex: 0x1C130C)
        static let wood900 = SwiftUI.Color(hex: 0x241A10)
        static let wood800 = SwiftUI.Color(hex: 0x2F2214)
        static let wood700 = SwiftUI.Color(hex: 0x3C2C19)

        static let paper = SwiftUI.Color(hex: 0xE7D3A1)
        static let paperHi = SwiftUI.Color(hex: 0xF1E2BA)
        static let paperLo = SwiftUI.Color(hex: 0xD3B981)

        static let ink = SwiftUI.Color(hex: 0x2A1C12)
        static let inkSoft = SwiftUI.Color(hex: 0x4A3320)

        static let rust = SwiftUI.Color(hex: 0x8C3223)
        static let rustDark = SwiftUI.Color(hex: 0x6E2018)

        static let brass = SwiftUI.Color(hex: 0xB8863B)
        static let brassHi = SwiftUI.Color(hex: 0xDAB567)

        static let sage = SwiftUI.Color(hex: 0x5C6B4A)
        static let sageDark = SwiftUI.Color(hex: 0x414D34)

        static let iron = SwiftUI.Color(hex: 0x302722)
        static let feltDark = SwiftUI.Color(hex: 0x2A0D0A)
    }

    // MARK: Typography
    enum Font {
        /// Display headlines — wood-type western lettering. Use sparingly, in small doses, uppercase.
        static func display(_ size: CGFloat) -> SwiftUI.Font { .custom("Rye-Regular", size: size) }
        /// Body copy — literary serif for readable paragraphs and journal-style text.
        static func body(_ size: CGFloat, italic: Bool = false) -> SwiftUI.Font {
            .custom(italic ? "Vollkorn-Italic" : "Vollkorn-Regular", size: size)
        }
        static func bodyBold(_ size: CGFloat) -> SwiftUI.Font { .custom("Vollkorn-Bold", size: size) }
        /// Stamped / typewriter labels — stats, tags, captions, ledger numbers.
        static func stamp(_ size: CGFloat) -> SwiftUI.Font { .custom("SpecialElite-Regular", size: size) }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Procedural film-grain overlay: cheap, offline, no bundled texture assets required.
/// Draws a fixed pseudo-random speckle field once per size and reuses it.
struct GrainOverlay: View {
    var opacity: Double = 0.05
    var blend: BlendMode = .overlay

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 42)
            let count = Int(size.width * size.height / 900)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let s = CGFloat.random(in: 0.4...1.1, using: &generator)
                let a = Double.random(in: 0.05...0.35, using: &generator)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                              with: .color(.white.opacity(a)))
            }
        }
        .opacity(opacity)
        .blendMode(blend)
        .allowsHitTesting(false)
    }
}

/// Deterministic RNG so the grain pattern doesn't reshuffle on every redraw.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Warm aged-paper background used behind menus, journal pages and case-file summaries.
struct ParchmentBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Frontier.Color.paperHi, Frontier.Color.paper, Frontier.Color.paperLo],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.black.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 420)
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .topLeading, startRadius: 10, endRadius: 320)
            GrainOverlay(opacity: 0.06, blend: .multiply)
        }
        .ignoresSafeArea()
    }
}

/// Dark saddle-leather / plank background used behind the home menu and tutorial.
struct LeatherBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Frontier.Color.wood900, Frontier.Color.wood950],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Frontier.Color.rust.opacity(0.10), .clear], center: .leading, startRadius: 10, endRadius: 380)
            GrainOverlay(opacity: 0.05, blend: .overlay)
        }
        .ignoresSafeArea()
    }
}

/// Primary call-to-action styled as a wax seal — used for the game's main confirmations.
struct WaxSealButtonStyle: ButtonStyle {
    var tint: Color = Frontier.Color.rust
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Frontier.Font.display(15))
            .foregroundColor(Frontier.Color.paperHi)
            .padding(.horizontal, 26)
            .padding(.vertical, 13)
            .background(
                Capsule().fill(RadialGradient(colors: [tint.opacity(0.95), tint.opacity(0.75)], center: .topLeading, startRadius: 2, endRadius: 90))
            )
            .overlay(Capsule().stroke(Color.black.opacity(0.25), lineWidth: 2))
            .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Subtle press-scale feedback for plain list rows and menu buttons.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Branded leather-tag button used for in-hand actions (fold/call/raise/all-in).
struct LeatherTagButtonStyle: ButtonStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Frontier.Font.display(13))
            .foregroundColor(Frontier.Color.paperHi)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 9, bottomTrailingRadius: 9, topTrailingRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                Circle().fill(Color.black.opacity(0.35)).frame(width: 4, height: 4)
                    .offset(y: -13), alignment: .top
            )
            .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
