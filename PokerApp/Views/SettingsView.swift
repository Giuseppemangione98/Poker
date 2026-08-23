import SwiftUI

struct SettingsView: View {
    @StateObject private var stats = StatsStore.shared

    var body: some View {
        ZStack {
            LeatherBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Impostazioni")
                        .font(Frontier.Font.display(24))
                        .foregroundColor(Frontier.Color.paperHi)
                        .padding(.top, 10)

                    section("Feedback") {
                        toggleRow("Feedback aptico", isOn: Binding(
                            get: { stats.settings.hapticsEnabled },
                            set: { stats.settings.hapticsEnabled = $0; HapticManager.shared.isEnabled = $0 }
                        ))
                        toggleRow("Suoni", isOn: Binding(
                            get: { stats.settings.soundEnabled },
                            set: { stats.settings.soundEnabled = $0 }
                        ))
                    }

                    section("Dati") {
                        Button("Reimposta statistiche") {
                            HapticManager.shared.error()
                            stats.resetStats()
                        }
                        .font(Frontier.Font.bodyBold(14))
                        .foregroundColor(Frontier.Color.rust)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Frontier.Font.stamp(10))
                .tracking(1.5)
                .foregroundColor(Frontier.Color.brassHi)
            VStack(spacing: 0) { content() }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.2)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Frontier.Color.paperLo.opacity(0.12), lineWidth: 1))
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(Frontier.Font.body(14)).foregroundColor(Frontier.Color.paperHi)
        }
        .tint(Frontier.Color.rust)
        .padding(10)
    }
}
