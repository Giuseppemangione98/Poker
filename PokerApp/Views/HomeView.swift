import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var stats = StatsStore.shared
    @State private var titlePulse = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.12, blue: 0.08), Color(red: 0.01, green: 0.04, blue: 0.03)],
                            startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 20)

                VStack(spacing: 4) {
                    Text("♠ ♥ ♣ ♦")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.5))
                    Text("TEXAS HOLD'EM")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .yellow.opacity(titlePulse ? 0.7 : 0.2), radius: titlePulse ? 14 : 4)
                    Text("Poker offline · Bot IA")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.55))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        titlePulse = true
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    menuButton(title: "Modalità Principiante", subtitle: "Impara con suggerimenti e analisi", systemImage: "graduationcap.fill", color: .blue) {
                        appState.goToModeSelection(beginner: true)
                    }
                    menuButton(title: "Modalità Classica", subtitle: "Gioca senza aiuti", systemImage: "suit.spade.fill", color: .green) {
                        appState.goToModeSelection(beginner: false)
                    }
                    menuButton(title: "Statistiche", subtitle: "\(stats.stats.handsPlayed) mani giocate", systemImage: "chart.bar.fill", color: .orange) {
                        appState.path.append(.stats)
                    }
                    menuButton(title: "Regole & Classifica mani", subtitle: "Ripassa le combinazioni", systemImage: "list.number", color: .purple) {
                        appState.path.append(.handRankings)
                    }
                    menuButton(title: "Impostazioni", subtitle: "Aptica, suoni, tavolo", systemImage: "gearshape.fill", color: .gray) {
                        appState.path.append(.settings)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func menuButton(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.25)).frame(width: 46, height: 46)
                    Image(systemName: systemImage).foregroundColor(color).font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
