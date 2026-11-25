# Learn A Language

A powerful, **offline** language learning app with **no ads**.
This project is a complete migration of a previously Python/Kivy-based app to **Flutter (Dart)**, optimized for Android and Linux Desktop.

**[Deutsch](README_de.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md) | [Ελληνικά](README_el.md) | [Italiano](README_it.md) | [Português](README_pt.md)**

## Key Features

- **100% Offline & Ad-Free**: All data is stored locally on the device. No trackers, no ads, no external dependencies for core functionality.
- **Spaced Repetition System**: Scientifically grounded learning rhythm with 9 levels (0–8) for optimal memory retention.
- **Day Streak Logic**: Motivational tracking and display of consecutive learning days.
- **Learning & Game Modes**: Includes a "Turbo" game that specifically quizzes already learned vocabulary to reinforce knowledge.
- **Local User Management**: Simple registration, login, and management of multiple user profiles directly on the device.
- **Learning Progress Overview**: A read-only word table per verb category showing the current level of every word with colored level badges (grey = new, green = mastered).
- **Cross-Platform**: Runs natively and stably on Android and Linux Desktop.

## Tech Stack

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **State Management**: Provider (ChangeNotifier)
- **Navigation**: `MaterialApp.routes` route table with `Navigator.pushNamed` (declarative routing)
- **Data Persistence**: Local JSON storage via path_provider (with automatic asset copy on first launch)
- **UI/Design**: Bundled fonts (Jura, Boycott, LiberationSerif) and a custom AppTheme for a consistent look and feel.

## Project Structure

The project follows a clean, modular architecture within the `lib/` directory, ensuring maintainability and scalability:

lib/
├── main.dart            # App entry point
├── managers/            # Business logic (AppState, User, Vocab, Language)
├── screens/             # UI views (Loading, Start, Learning, Settings, etc.)
│   ├── loading_screen.dart            # Splash/loading screen with async init & auto-login
│   ├── start_screen.dart              # Main menu / start page
│   ├── category_screen.dart           # Sub-category with learning modes (New/Due/Learned)
│   ├── collection_screen.dart         # Collection view listing its sub-categories
│   ├── learning_screen.dart           # Learning category selection
│   ├── word_screen.dart               # Word flash-cards (display & answer check)
│   ├── due_word_screen.dart           # Due-word review (spaced repetition)
│   ├── progress_screen.dart           # Progress overview (read-only collections)
│   ├── progress_group_screen.dart     # Read-only word table per category with level badges
│   ├── settings_screen.dart           # Settings (auto-login, words per session, users)
│   ├── game_choose_screen.dart        # "Choose game" hub
│   ├── game_screen.dart               # Turbo quiz game (lives, score, timer)
│   ├── turbo_lv_select_screen.dart    # Turbo difficulty selection
│   ├── grammar_screen.dart            # Grammar topic list (optional CEFR level filter)
│   ├── grammar_detail_screen.dart     # Detail view of a single grammar topic
│   ├── crossword_screen.dart          # Crossword game screen
│   ├── crossword_lv_select_screen.dart# Crossword difficulty selection
│   ├── fill_in_screen.dart            # Fill-in-the-blank game (sentences with gaps)
│   ├── fill_in_lv_select_screen.dart  # Fill-in difficulty selection
│   ├── hangman_screen.dart            # Hangman game screen
│   ├── hangman_lv_select_screen.dart  # Hangman difficulty selection
│   ├── word_search_screen.dart        # Word-search puzzle screen
│   ├── crossword_engine.dart          # Crossword logic (pure Dart, no Flutter)
│   ├── fill_in_engine.dart            # Fill-in logic (pure Dart, no Flutter)
│   ├── hangman_engine.dart            # Hangman logic (pure Dart, no Flutter)
│   └── word_search_engine.dart        # Word-search grid logic (pure Dart, no Flutter)
├── services/            # Services (e.g. FileService for JSON persistence)
├── models/              # Data models
├── widgets/             # Reusable UI components
├── dialogs/             # Pop-ups and dialogs (Info, Login, GameOver, etc.)
└── test/                # Unit & widget tests (flutter test)
├── theme/               # Central color palette and ThemeData

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.1.0) installed
- An editor of your choice (e.g. VS Code or Android Studio)

### Installation & Run

1. Clone the repository:
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Install dependencies:
   flutter pub get

3. Run the app (e.g. on Linux Desktop or a connected Android device/emulator):
   flutter run

### Install over WiFi Debugging (Android 11+, keeps user data)

> Installing over an existing app **never deletes** your data. Data is only lost
> when the app is **uninstalled**. Updating a build with `install -r` keeps all
> local user data (words, levels, streaks).

Works on Android 11+ with **Wireless debugging** enabled. The pairing port is
**dynamic** — always use the IP/port shown on the phone.

1. On the phone enable **Developer options → Wireless debugging** and tap
   **Pair device with code**. The phone now shows an IP, a port, and a
   6-digit pairing code.
2. On the computer pair and connect:
   adb pair IP:PORT <6-digit-code>
   adb connect IP:PORT            # use the port shown on the phone
3. Verify the device is connected (it must be listed):
   adb devices
4. Build the debug APK and install it over the current app (keeps all data):
   flutter build apk --debug
   adb -s IP:PORT install -r build/app/outputs/flutter-apk/app-debug.apk

> `-r` replaces the app while keeping its data. A "signature mismatch" error
> means the installed app has a different signature (e.g. a release build) —
> uninstalling would be required, so always install the matching build type
> (debug → debug).

## Migration from Kivy to Flutter

The app was successfully migrated from Python/Kivy to Flutter. Special attention was paid to the following points:
- **100% Data Compatibility**: The JSON data structure remains fully backward-compatible with existing user data from the Kivy version.
- **Complete Porting**: All 8 screens, 6 dialogs, and 5 manager classes were transferred 1:1 into Dart.
- **Stability**: Comprehensive bugfixes for Linux Desktop and Android, including platform-safe functions (e.g. closeApp).

## License

This project is developed as an ad-free, offline-first application, focused on effective and undisturbed learning.