import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let systemImage: String
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var showRankings = false

    private let pages: [TutorialPage] = [
        .init(title: "Obiettivo del gioco",
              body: "Nel Texas Hold'em ogni giocatore riceve 2 carte coperte (carte del giocatore). Sul tavolo vengono scoperte fino a 5 carte comuni. Devi formare la migliore combinazione da 5 carte usando le tue carte e quelle comuni.",
              systemImage: "target"),
        .init(title: "Il giro di puntate",
              body: "Si gioca in 4 fasi: Preflop (solo carte in mano), Flop (3 carte comuni), Turn (4ª carta) e River (5ª carta). Ad ogni fase puoi Fold (abbandonare), Check/Call (passare o pareggiare la puntata) oppure Bet/Raise (puntare o rilanciare).",
              systemImage: "square.stack.3d.up.fill"),
        .init(title: "Bui e posizione",
              body: "Prima di ogni mano, due giocatori pagano i 'bui' obbligatori (piccolo e grande buio) per creare un piatto iniziale. Il bottone del dealer ruota ad ogni mano, cambiando chi agisce per primo.",
              systemImage: "arrow.triangle.2.circlepath"),
        .init(title: "Pot odds ed equity",
              body: "L'equity è la probabilità stimata che la tua mano vinca. Le pot odds indicano quanto ti conviene pagare rispetto al piatto. Se la tua equity è maggiore delle pot odds richieste, pagare è (in media) una scelta redditizia.",
              systemImage: "chart.pie.fill"),
        .init(title: "Modalità Principiante",
              body: "In questa modalità l'app ti mostra in tempo reale un consiglio (fold/check/call/raise) con la spiegazione, e a fine mano trovi un'analisi di ciò che hai fatto bene o si poteva migliorare.",
              systemImage: "graduationcap.fill")
    ]

    var body: some View {
        NavigationStack {
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
                    Label("Vedi classifica delle mani", systemImage: "list.number")
                        .font(.subheadline.bold())
                }
                .padding(.bottom, 8)

                Button {
                    HapticManager.shared.buttonTap()
                    dismiss()
                } label: {
                    Text(pageIndex == pages.count - 1 ? "Inizia a giocare" : "Chiudi")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Capsule().fill(Color.green))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.12).ignoresSafeArea())
            .navigationTitle("Come si gioca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showRankings) { HandRankingGuideView() }
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ page: TutorialPage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.systemImage)
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .padding(.top, 30)
            Text(page.title)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(page.body)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}
