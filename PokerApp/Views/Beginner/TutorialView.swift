import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let mark: String
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var showRankings = false

    private let pages: [TutorialPage] = [
        .init(title: "Obiettivo del gioco",
              body: "Nel Texas Hold'em ogni giocatore riceve 2 carte coperte. Sul tavolo vengono scoperte fino a 5 carte comuni. Devi formare la migliore combinazione da 5 carte usando le tue carte e quelle comuni.",
              mark: "5 CARTE"),
        .init(title: "Il giro di puntate",
              body: "Si gioca in 4 fasi: Preflop, Flop (3 carte), Turn (4ª carta) e River (5ª carta). Ad ogni fase puoi abbandonare, pareggiare la puntata oppure rilanciare.",
              mark: "4 FASI"),
        .init(title: "Bui e posizione",
              body: "Prima di ogni mano, due giocatori pagano i bui obbligatori per creare un piatto iniziale. Il bottone del mazziere ruota ad ogni mano, cambiando chi agisce per primo.",
              mark: "IL BOTTONE"),
        .init(title: "Pot odds ed equity",
              body: "L'equity è la probabilità stimata che la tua mano vinca. Le pot odds indicano quanto ti conviene pagare rispetto al piatto. Se l'equity supera le pot odds, pagare conviene nel lungo periodo.",
              mark: "EQUITY"),
        .init(title: "Modalità Principiante",
              body: "In questa modalità l'app ti mostra in tempo reale un consiglio con la spiegazione, e a fine mano trovi un'analisi di ciò che hai fatto bene o si poteva migliorare.",
              mark: "GUIDA")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LeatherBackground()
                VStack {
                    TabView(selection: $pageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { i, page in
                            pageView(page).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .animation(.easeInOut, value: pageIndex)

                    Button {
                        HapticManager.shared.buttonTap()
                        showRankings = true
                    } label: {
                        Text("Vedi classifica delle mani")
                            .font(Frontier.Font.body(13))
                            .underline()
                            .foregroundColor(Frontier.Color.brassHi)
                    }
                    .padding(.bottom, 8)

                    Button(pageIndex == pages.count - 1 ? "Inizia a giocare" : "Chiudi") {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    }
                    .buttonStyle(WaxSealButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRankings) { HandRankingGuideView() }
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ page: TutorialPage) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Frontier.Color.brass.opacity(0.3), Frontier.Color.brass.opacity(0.04)], center: .topLeading, startRadius: 2, endRadius: 60))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(Frontier.Color.brass, lineWidth: 2))
                Text(page.mark)
                    .font(Frontier.Font.display(13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Frontier.Color.brassHi)
            }
            .padding(.top, 26)

            Text(page.title)
                .font(Frontier.Font.display(22))
                .foregroundColor(Frontier.Color.paperHi)
            Text(page.body)
                .font(Frontier.Font.body(14.5, italic: true))
                .foregroundColor(Frontier.Color.paperLo)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
        }
    }
}
