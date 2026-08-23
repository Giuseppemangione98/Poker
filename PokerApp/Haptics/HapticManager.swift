import UIKit

/// Centralized haptic feedback for game events. All calls are cheap and safe to fire frequently;
/// generators are prepared lazily to minimize latency on first use per session.
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    var isEnabled: Bool = true

    private init() {
        [lightImpact, mediumImpact, heavyImpact, rigidImpact].forEach { $0.prepare() }
        notification.prepare()
        selection.prepare()
    }

    func cardDealt() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.5)
    }

    func chipBet() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.7)
    }

    func selectionTick() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    func actionCheckOrCall() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    func actionRaiseOrBet() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func actionAllIn() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: 1.0)
    }

    func fold() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.3)
    }

    func handWon() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func handLost() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    func buttonTap() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }
}
