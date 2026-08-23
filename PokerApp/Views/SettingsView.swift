import SwiftUI

struct SettingsView: View {
    @StateObject private var stats = StatsStore.shared
    private let feltColors: [Color] = [Color(red: 0.08, green: 0.35, blue: 0.2), Color(red: 0.1, green: 0.2, blue: 0.4), Color(red: 0.35, green: 0.08, blue: 0.12)]

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Feedback aptico", isOn: Binding(
                    get: { stats.settings.hapticsEnabled },
                    set: { stats.settings.hapticsEnabled = $0; HapticManager.shared.isEnabled = $0 }
                ))
                Toggle("Suoni", isOn: Binding(
                    get: { stats.settings.soundEnabled },
                    set: { stats.settings.soundEnabled = $0 }
                ))
            }

            Section("Tavolo") {
                Picker("Colore panno", selection: Binding(
                    get: { stats.settings.tableFeltColorIndex },
                    set: { stats.settings.tableFeltColorIndex = $0 }
                )) {
                    Text("Verde").tag(0)
                    Text("Blu").tag(1)
                    Text("Rosso").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section("Dati") {
                Button("Reimposta statistiche", role: .destructive) {
                    HapticManager.shared.error()
                    stats.resetStats()
                }
            }
        }
        .navigationTitle("Impostazioni")
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
