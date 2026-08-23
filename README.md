# Texas Hold'em Poker (offline, iPhone)

App nativa iOS in **SwiftUI**, Texas Hold'em completo, offline contro bot IA, con
animazioni, feedback aptici e una modalità Principiante che ti aiuta a imparare.

## Cosa include

- **Motore di gioco completo**: mazzo, valutazione mani a 7 carte, bui, giri di
  puntata (preflop/flop/turn/river), fold/check/call/bet/raise/all-in, side pot,
  showdown, bottone dealer che ruota, blind che crescono nel tempo.
- **Bot IA** con 3 livelli di difficoltà (Facile/Medio/Difficile), basati su una
  stima Monte Carlo dell'equity, pot odds, posizione e (nel livello Difficile)
  qualche bluff.
- **Modalità Principiante**: consiglio in tempo reale (fold/check/call/raise)
  con spiegazione in linguaggio semplice, barra dell'equity vs pot odds,
  tutorial interattivo sulle regole e sulla classifica delle mani, analisi
  dettagliata dopo ogni mano.
- **Modalità Classica**: stessa esperienza di gioco senza aiuti.
- **Animazioni**: distribuzione carte, flip carte, chip che si muovono verso il
  piatto, evidenziazione del vincitore, coriandoli.
- **Feedback aptici** (Core Haptics/UIKit) su ogni azione: carte distribuite,
  puntate, check/call, raise, all-in, vittoria/sconfitta.
- **Statistiche persistenti** (mani giocate/vinte, VPIP, PFR, piatto più grande,
  ecc.) e impostazioni (aptica, suoni, colore del panno) salvate sul telefono.

## Struttura del progetto

```
PokerApp/
  App/            Entry point (@main), navigazione (AppState)
  Models/         Card, Deck, HandEvaluator, Player, Pot
  Engine/         GameEngine (motore), BotAI, EquityEstimator, GameViewModel
  Views/          Tavolo da gioco, componenti (carte, chip, seat), menu
  Views/Beginner/ Hint, tutorial, classifica mani, analisi post-mano
  Views/Animations/ Coriandoli e glow vincita
  Haptics/        HapticManager
  Persistence/    StatsStore (statistiche + impostazioni)
project.yml       Definizione progetto per XcodeGen
```

## Come compilare (serve un Mac con Xcode)

Questo repository contiene solo i sorgenti Swift: il progetto Xcode
(`.xcodeproj`) viene generato con **XcodeGen** per evitare di dover mantenere
a mano il file di progetto binario.

1. Installa XcodeGen (una volta sola), su macOS:
   ```bash
   brew install xcodegen
   ```
2. Dalla cartella del repository, genera il progetto:
   ```bash
   xcodegen generate
   ```
   Questo crea `PokerApp.xcodeproj`.
3. Apri `PokerApp.xcodeproj` con Xcode.
4. Seleziona il tuo **Apple ID personale** come Team nelle impostazioni di
   firma del target `PokerApp` (Signing & Capabilities). Con un Apple ID
   gratuito puoi firmare ed eseguire l'app sul tuo iPhone per 7 giorni (si
   rinnova ricompilando); con un account a pagamento dura 1 anno.
5. Collega l'iPhone al Mac, selezionalo come destinazione ed esegui ▶️ per
   installarlo direttamente, **oppure** genera un `.ipa` da distribuire con un
   loader (vedi sotto): Product → Archive → Distribute App → Ad Hoc/Development
   → esporta l'IPA.

### Non hai un Mac?

Puoi generare l'IPA anche da un servizio di build in cloud che usa Xcode per
te (es. Codemagic, che ha un piano gratuito per progetti personali):
carica questo repository, punta al file `project.yml`/`PokerApp.xcodeproj`
generato e configura un workflow iOS "unsigned" o con la tua firma personale;
scarica l'`.ipa` risultante.

## Come installare sull'iPhone (sideload)

Una volta ottenuto il file `.ipa`, installalo con lo strumento di sideload
che preferisci (es. Sideloadly, AltStore/AltStore PAL, o l'app che chiami
"iloader"): questi strumenti firmano l'IPA con il tuo Apple ID e lo installano
senza passare dall'App Store. Con un Apple ID gratuito dovrai reinstallare
l'app ogni 7 giorni; con un account sviluppatore a pagamento dura più a lungo.

## Note tecniche

- Target: iOS 16+, orientamento landscape (tavolo da poker).
- Nessuna dipendenza di terze parti: solo SwiftUI, Combine, UIKit (per gli
  aptici). Nessuna connessione di rete: il gioco è completamente offline.
- L'equity mostrata nella modalità Principiante è stimata con una simulazione
  Monte Carlo (centinaia di mani casuali simulate) ad ogni tua decisione.
