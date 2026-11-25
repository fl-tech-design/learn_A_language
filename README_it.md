# Learn A Language

Una potente app per l'apprendimento delle lingue, **offline** e **senza pubblicità**.
Questo progetto è la migrazione completa di un'app precedentemente sviluppata in Python/Kivy a **Flutter (Dart)**, ottimizzata per Android e Linux Desktop.

**[English](README.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md) | [Ελληνικά](README_el.md) | [Português](README_pt.md)**

## Stato attuale

| Componente | Valore |
|---|---|
| Hash di commit | `30280c611340e752d1cbfa22adcc350d441f33d9` (`30280c6`) |
| Branch | `main` |
| Data | 25.11.2026 |

> Questa sezione viene aggiornata a ogni modifica rilevante (ad es., prima dei report di analisi) affinché lo stato documentato del codice resti riproducibile (Ticket #57).

## Caratteristiche principali

- **100% Offline e senza pubblicità**: Tutti i dati sono salvati localmente sul dispositivo. Nessun tracker, nessuna pubblicità, nessuna dipendenza esterna per le funzionalità principali.
- **Sistema di ripetizione spaziata**: Ritmo di apprendimento scientificamente fondato con 9 livelli (0–8) per una memorizzazione ottimale.
- **Logica delle serie giornaliere**: Monitoraggio motivazionale e visualizzazione dei giorni di apprendimento consecutivi.
- **Modalità di apprendimento e giochi**: Include un gioco "Turbo" che ripassa specificamente il vocabolario già appreso per consolidare la memoria.
- **Gestione utenti locale**: Registrazione, accesso e gestione di più profili utente direttamente sul dispositivo.
- **Panoramica dei progressi**: Una tabella di parole di sola lettura per categoria di verbi che mostra il livello attuale di ogni parola con badge colorati (grigio = nuova, verde = appresa).
- **Multi-piattaforma**: Funziona nativamente e stabilmente su Android e Linux Desktop.

## Stack tecnologico

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **Gestione stato**: Provider (ChangeNotifier)
- **Navigazione**: Tabella di route `MaterialApp.routes` con `Navigator.pushNamed` (routing dichiarativo)
- **Persistenza dati**: Salvataggio JSON locale tramite path_provider (con copia automatica degli asset al primo avvio)
- **UI/Design**: Font inclusi (Jura, Boycott, LiberationSerif) e un AppTheme personalizzato per un aspetto coerente.

## Struttura del progetto

Il progetto segue un'architettura pulita e modulare all'interno della directory `lib/`, che ne garantisce manutenibilità e scalabilità:

lib/
├── main.dart            # Punto di ingresso dell'app
├── managers/            # Logica di business (AppState, User, Vocab, Language)
├── screens/             # Viste della UI (Loading, Start, Learning, Settings, ecc.)
│   ├── loading_screen.dart            # Schermata di caricamento con inizializzazione asincrona e auto-login
│   ├── start_screen.dart              # Menu principale / pagina iniziale
│   ├── category_screen.dart           # Sottocategoria con modalità di apprendimento (Nuove/In scadenza/Apprese)
│   ├── collection_screen.dart         # Raccolta che elenca le sue sottocategorie
│   ├── learning_screen.dart           # Selezione delle categorie di apprendimento
│   ├── word_screen.dart               # Carte-parola (visualizzazione e verifica della risposta)
│   ├── due_word_screen.dart           # Ripasso delle parole in scadenza (ripetizione spaziata)
│   ├── progress_screen.dart           # Panoramica dei progressi (raccolte in sola lettura)
│   ├── progress_group_screen.dart     # Tabella di sola lettura per categoria con badge di livello
│   ├── settings_screen.dart           # Impostazioni (auto-login, parole per sessione, utenti)
│   ├── game_choose_screen.dart        # Hub «Scegli il gioco»
│   ├── game_screen.dart               # Gioco-quiz Turbo (vite, punteggio, timer)
│   ├── turbo_lv_select_screen.dart    # Selezione difficoltà Turbo
│   ├── grammar_screen.dart            # Elenco degli argomenti di grammatica (filtro opzionale per livello)
│   ├── grammar_detail_screen.dart     # Dettaglio di un singolo argomento di grammatica
│   ├── crossword_screen.dart          # Schermata del gioco del cruciverba
│   ├── crossword_lv_select_screen.dart# Selezione difficoltà cruciverba
│   ├── fill_in_screen.dart            # Gioco di completamento (frasi con lacune)
│   ├── fill_in_lv_select_screen.dart  # Selezione difficoltà completamento
│   ├── hangman_screen.dart            # Gioco dell'impiccato
│   ├── hangman_lv_select_screen.dart  # Selezione difficoltà impiccato
│   ├── word_search_screen.dart        # Gioco della ricerca di parole
│   ├── crossword_engine.dart          # Logica del cruciverba (Dart puro, senza Flutter)
│   ├── fill_in_engine.dart            # Logica di completamento (Dart puro, senza Flutter)
│   ├── hangman_engine.dart            # Logica dell'impiccato (Dart puro, senza Flutter)
│   └── word_search_engine.dart        # Logica della griglia di ricerca parole (Dart puro, senza Flutter)
├── services/            # Servizi (p. es. FileService per la persistenza JSON)
├── models/              # Modelli di dati
├── widgets/             # Componenti della UI riutilizzabili
├── dialogs/             # Finestre pop-up e dialoghi (Info, Login, GameOver, ecc.)
└── test/                # Test unitari e dei widget (flutter test)
├── theme/               # Tavolozza colori centrale e ThemeData

## Per iniziare

### Prerequisiti
- Flutter SDK (>= 3.1.0) installato
- Un editor a scelta (p. es. VS Code o Android Studio)

### Installazione ed esecuzione

1. Clona il repository:
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Installa le dipendenze:
   flutter pub get

3. Esegui l'app (p. es. su Linux Desktop o su un dispositivo Android collegato/emulatore):
   flutter run

### Installazione tramite debug wireless (Android 11+, mantiene i dati utente)

> L'installazione sopra un'app esistente **non cancella mai** i tuoi dati. I dati
> vengono persi solo se l'app viene **disinstallata**. Aggiornare una build con
> `install -r` mantiene tutti i dati locali (parole, livelli, serie).

Funziona su Android 11+ con **debug wireless** attivato. La porta di associazione è
**dinamica** — usa sempre l'indirizzo IP/porta mostrati sul telefono.

1. Sul telefono attiva **Opzioni sviluppatore → Debug wireless** e tocca
   **Associa dispositivo con codice**. Il telefono mostra ora un IP, una porta e un
   codice di associazione a 6 cifre.
2. Sul computer esegui l'associazione e la connessione:
   adb pair IP:PORTA <codice-a-6-cifre>
   adb connect IP:PORTA            # usa la porta mostrata sul telefono
3. Verifica che il dispositivo sia collegato (deve essere elencato):
   adb devices
4. Compila l'APK di debug e installalo sopra l'app attuale (mantiene tutti i dati):
   flutter build apk --debug
   adb -s IP:PORTA install -r build/app/outputs/flutter-apk/app-debug.apk

> `-r` sostituisce l'app mantenendo i dati. Un errore "firma non corrispondente"
> significa che l'app installata ha una firma diversa (p. es. una build di
> release) — la disinstallazione sarebbe necessaria, installa quindi sempre il
> tipo di build corrispondente (debug → debug).

## Migrazione da Kivy a Flutter

L'app è stata migrata con successo da Python/Kivy a Flutter. Particolare attenzione è stata dedicata ai seguenti punti:
- **Compatibilità dei dati 100%**: La struttura JSON dei dati rimane pienamente retrocompatibile con i dati utente esistenti della versione Kivy.
- **Porting completo**: Tutti gli 8 schermi, 6 dialoghi e 5 classi manager sono stati trasferiti 1:1 in Dart.
- **Stabilità**: Correzioni complete di bug per Linux Desktop e Android, incluse funzioni sicure per piattaforma (p. es. closeApp).

## Licenza

Questo progetto è sviluppato come applicazione senza pubblicità, offline-first, focalizzata su un apprendimento efficace e senza distrazioni.
