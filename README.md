# Learn A Language

A powerful, **offline** language learning app with **no ads**.
This project is a complete migration of a previously Python/Kivy-based app to **Flutter (Dart)**, optimized for Android and Linux Desktop.

**[Deutsch](README_de.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md)**

## Key Features

- **100% Offline & Ad-Free**: All data is stored locally on the device. No trackers, no ads, no external dependencies for core functionality.
- **Spaced Repetition System**: Scientifically grounded learning rhythm with 9 levels (0–8) for optimal memory retention.
- **Day Streak Logic**: Motivational tracking and display of consecutive learning days.
- **Learning & Game Modes**: Includes a "Turbo" game that specifically quizzes already learned vocabulary to reinforce knowledge.
- **Local User Management**: Simple registration, login, and management of multiple user profiles directly on the device.
- **Cross-Platform**: Runs natively and stably on Android and Linux Desktop.

## Tech Stack

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **State Management**: Provider (ChangeNotifier)
- **Navigation**: go_router (declarative routing)
- **Data Persistence**: Local JSON storage via path_provider (with automatic asset copy on first launch)
- **UI/Design**: google_fonts (Jura, Boycott, LiberationSerif) and a custom AppTheme for a consistent look and feel.

## Project Structure

The project follows a clean, modular architecture within the `lib/` directory, ensuring maintainability and scalability:

lib/
├── main.dart            # App entry point
├── managers/            # Business logic (AppState, User, Vocab, Language)
├── screens/             # UI views (Loading, Start, Learning, Settings, etc.)
├── services/            # Services (e.g. FileService for JSON persistence)
├── models/              # Data models
├── widgets/             # Reusable UI components
├── dialogs/             # Pop-ups and dialogs (Info, Login, GameOver, etc.)
└── theme/               # Central color palette and ThemeData

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

## Migration from Kivy to Flutter

The app was successfully migrated from Python/Kivy to Flutter. Special attention was paid to the following points:
- **100% Data Compatibility**: The JSON data structure remains fully backward-compatible with existing user data from the Kivy version.
- **Complete Porting**: All 8 screens, 6 dialogs, and 5 manager classes were transferred 1:1 into Dart.
- **Stability**: Comprehensive bugfixes for Linux Desktop and Android, including platform-safe functions (e.g. closeApp).

## License

This project is developed as an ad-free, offline-first application, focused on effective and undisturbed learning.