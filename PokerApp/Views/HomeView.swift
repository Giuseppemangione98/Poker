import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var stats = StatsStore.shared
    @State private var titlePulse = false

    var body: some View {
        ZStack {
            LeatherBackground()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Spacer()
                    Text("♠ ♥ ♣ ♦")
                        .font(Frontier.Font.stamp(13))
                        .tracking(6)
                        .foregroundColor(Frontier.Color.brassHi.opacity(0.7))
                    Text("TEXAS\nHOLD'EM")
                        .font(Frontier.Font.display(38))
                        .foregroundColor(Frontier.Color.paperHi)
                        .lineSpacing(-4)
                        .shadow(color: Frontier.Color.rust.opacity(titlePulse ? 0.6 : 0.15), radius: titlePulse ? 18 : 5)
                    Text("POKER OFFLINE · NESSUNA RETE")
                        .font(Frontier.Font.stamp(9.5))
                        .foregroundColor(Frontier.Color.paperLo)
                    Spacer()
                }
                .padding(.trailing, 22)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Frontier.Color.brass.opacity(0.25)).frame(width: 1)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        titlePulse = true
                    }
                }

                VStack(spacing: 10) {
                    Spacer()
                    menuButton(title: "Modalità Principiante", subtitle: "Suggerimenti e analisi", mark: "◆", tint: Frontier.Color.rust, primary: true) {
                        appState.goToModeSelection(beginner: true)
                    }
                    menuButton(title: "Modalità Classica", subtitle: "Gioca senza aiuti", mark: "♠", tint: Frontier.Color.sageDark, primary: false) {
                        appState.goToModeSelection(beginner: false)
                    }
                    menuButton(title: "Statistiche", subtitle: "\(stats.stats.handsPlayed) mani giocate", mark: "§", tint: Frontier.Color.brass, primary: false) {
                        appState.path.append(.stats)
                    }
                    menuButton(title: "Regole & classifica mani", subtitle: "Ripassa le combinazioni", mark: "✦", tint: Frontier.Color.wood700, primary: false) {
                        appState.path.append(.handRankings)
                    }
                    menuButton(title: "Impostazioni", subtitle: "Aptica, suoni, tavolo", mark: "⚙", tint: Frontier.Color.iron, primary: false) {
                        appState.path.append(.settings)
                    }
                    Spacer()
                }
                .padding(.leading, 22)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
        }
        .preferredColorScheme(.dark)
    }

    private func menuButton(title: String, subtitle: String, mark: String, tint: Color, primary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(tint).frame(width: 34, height: 34)
                    Circle().stroke(Frontier.Color.brassHi.opacity(0.6), lineWidth: 1)
                    Text(mark).font(Frontier.Font.display(14)).foregroundColor(Frontier.Color.paperHi)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Frontier.Font.bodyBold(14)).foregroundColor(Frontier.Color.paperHi)
                    Text(subtitle).font(Frontier.Font.stamp(9)).foregroundColor(Frontier.Color.paperLo)
                }
                Spacer()
                Text("›").font(Frontier.Font.display(16)).foregroundColor(Frontier.Color.brass.opacity(0.7))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(primary ? 0.28 : 0.16))
            )
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(primary ? Frontier.Color.brass.opacity(0.55) : Frontier.Color.paperLo.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
