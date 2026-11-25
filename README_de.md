# Learn A Language

Eine leistungsstarke, **offline** nutzbare Sprachlern-App **ohne Werbung**. 
Dieses Projekt ist eine vollständige Migration einer zuvor in Python/Kivy entwickelten App nach **Flutter (Dart)**, optimiert für Android und Linux Desktop.

**[English](README.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md) | [Ελληνικά](README_el.md) | [Italiano](README_it.md) | [Português](README_pt.md)**

## Hauptfunktionen

- **100% Offline & Werbefrei**: Alle Daten werden lokal auf dem Gerät gespeichert. Keine Tracker, keine Werbung, keine externen Abhängigkeiten für den Kernbetrieb.
- **Spaced-Repetition-System**: Wissenschaftlich fundierter Lernrhythmus mit 9 Levels (0–8) zur optimalen Gedächtnisverankerung.
- **Day-Streak-Logik**: Motivationsfördernde Anzeige und Berechnung von aufeinanderfolgenden Lerntagen.
- **Lern- & Spielmodi**: Inklusive eines "Turbo"-Spiels, das gezielt bereits gelernte Vokabeln abfragt, um das Wissen zu festigen.
- **Lokale Benutzerverwaltung**: Einfache Registrierung, Login und Verwaltung mehrerer Benutzerprofile direkt auf dem Gerät.
- **Lernfortschritt-Übersicht**: Eine schreibgeschützte Worttabelle pro Verb-Kategorie mit dem aktuellen Level jedes Wortes und farbigen Level-Badges (grau = neu, grün = gelernt).
- **Cross-Platform**: Läuft nativ und stabil auf Android und Linux Desktop.

## Technologie-Stack

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **State Management**: Provider (ChangeNotifier)
- **Navigation**: `MaterialApp.routes`-Routen-Tabelle mit `Navigator.pushNamed` (deklaratives Routing)
- **Datenpersistenz**: Lokale JSON-Speicherung via path_provider (mit automatischem Asset-Copy beim ersten Start)
- **UI/Design**: Gebündelte Fonts (Jura, Boycott, LiberationSerif) und ein massgeschneidertes AppTheme für ein konsistentes Erscheinungsbild.

## Projektstruktur

Das Projekt folgt einer sauberen, modularen Architektur im `lib/`-Verzeichnis, die Wartbarkeit und Skalierbarkeit gewährleistet:

lib/
├── main.dart            # Einstiegspunkt der App
├── managers/            # Geschäftslogik (AppState, User, Vocab, Language)
├── screens/             # UI-Ansichten (Loading, Start, Learning, Settings, etc.)
│   ├── loading_screen.dart            # Splash-/Lade-Screen mit asynchroner Init & Auto-Login
│   ├── start_screen.dart              # Hauptmenü / Startseite
│   ├── category_screen.dart           # Unterkategorie mit Lern-Modi (Neu/Fällig/Gelernt)
│   ├── collection_screen.dart         # Sammlung mit ihren Unterkategorien
│   ├── learning_screen.dart           # Auswahl der Lern-Kategorien
│   ├── word_screen.dart               # Wort-Lernkarten (Anzeige & Antwortprüfung)
│   ├── due_word_screen.dart           # Wiederholung fälliger Wörter (Spaced Repetition)
│   ├── progress_screen.dart           # Fortschritts-Übersicht (read-only Sammlungen)
│   ├── progress_group_screen.dart     # Read-only Worttabelle je Kategorie mit Level-Badges
│   ├── settings_screen.dart           # Einstellungen (Auto-Login, Wörter pro Sitzung, Benutzer)
│   ├── game_choose_screen.dart        # Hub „Spiel wählen“
│   ├── game_screen.dart               # Turbo-Quiz-Spiel (Leben, Punkte, Timer)
│   ├── turbo_lv_select_screen.dart    # Turbo-Schwierigkeitsauswahl
│   ├── grammar_screen.dart            # Grammatik-Themenliste (optional nach Niveau filterbar)
│   ├── grammar_detail_screen.dart     # Detailansicht eines Grammatik-Themas
│   ├── crossword_screen.dart          # Kreuzworträtsel-Spielscreen
│   ├── crossword_lv_select_screen.dart# Kreuzworträtsel-Schwierigkeitsauswahl
│   ├── fill_in_screen.dart            # Lückentext-Spiel (Beispielsätze mit Lücken)
│   ├── fill_in_lv_select_screen.dart  # Lückentext-Schwierigkeitsauswahl
│   ├── hangman_screen.dart            # Hangman-Spielscreen
│   ├── hangman_lv_select_screen.dart  # Hangman-Schwierigkeitsauswahl
│   ├── word_search_screen.dart        # Wortsuch-Spielscreen
│   ├── crossword_engine.dart          # Kreuzworträtsel-Logik (pure Dart, ohne Flutter)
│   ├── fill_in_engine.dart            # Lückentext-Logik (pure Dart, ohne Flutter)
│   ├── hangman_engine.dart            # Hangman-Logik (pure Dart, ohne Flutter)
│   └── word_search_engine.dart        # Wortsuch-Gitter-Logik (pure Dart, ohne Flutter)
├── services/            # Dienste (z. B. FileService für JSON-Persistenz)
├── models/              # Datenmodelle
├── widgets/             # Wiederverwendbare UI-Komponenten
├── dialogs/             # Pop-ups und Dialoge (Info, Login, GameOver, etc.)
└── test/                # Unit- & Widget-Tests (flutter test)
├── theme/               # Zentrale Farbpalette und ThemeData

## Erste Schritte

### Voraussetzungen
- Flutter SDK (>= 3.1.0) installiert
- Ein Editor Deiner Wahl (z. B. VS Code oder Android Studio)

### Installation & Start

1. Repository klonen:
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Abhängigkeiten installieren:
   flutter pub get

3. App starten (z. B. auf Linux Desktop oder einem angeschlossenen Android-Gerät/Emulator):
   flutter run

### Installation über WLAN-Debugging (Android 11+, behält Benutzerdaten)

> Eine Installation über eine bestehende App **löscht niemals** die Daten.
> Daten gehen nur beim **Deinstallieren** der App verloren. Ein Update mit
> `install -r` behält alle lokalen Benutzerdaten (Wörter, Levels, Streaks).

Funktioniert auf Android 11+ mit aktiviertem **Drahtloses Debugging**. Der
Pairing-Port ist **dynamisch** — immer die auf dem Handy angezeigte IP/Port
verwenden.

1. Am Handy **Entwickleroptionen → Drahtloses Debugging** aktivieren und
   **„Gerät mit Code koppeln“** antippen. Das Handy zeigt nun eine IP, einen
   Port und einen 6-stelligen Pairing-Code.
2. Am Rechner koppeln und verbinden:
   adb pair IP:PORT <6-stelliger-Code>
   adb connect IP:PORT            # Port vom Handy verwenden
3. Verbindung prüfen (das Gerät muss in der Liste stehen):
   adb devices
4. Debug-APK bauen und über die aktuelle App installieren (behält alle Daten):
   flutter build apk --debug
   adb -s IP:PORT install -r build/app/outputs/flutter-apk/app-debug.apk

> `-r` ersetzt die App und behält ihre Daten. Bei „signature mismatch“ hat die
> installierte App eine andere Signatur (z. B. eine Release-Version) —
> Deinstallieren wäre nötig, daher immer den passenden Build-Typ verwenden
> (Debug → Debug).

## Migration von Kivy zu Flutter

Die App wurde erfolgreich von Python/Kivy nach Flutter migriert. Dabei wurde besonderer Wert auf folgende Punkte gelegt:
- **100% Datenkompatibilität**: Die JSON-Datenstruktur bleibt vollständig abwärtskompatibel zu bestehenden Benutzerdaten aus der Kivy-Version.
- **Vollständige Portierung**: Alle 8 Bildschirme, 6 Dialoge und 5 Manager-Klassen wurden 1:1 in Dart übertragen.
- **Stabilität**: Umfassende Bugfixes für Linux Desktop und Android, inklusive plattformsicherer Funktionen (z. B. closeApp).

## Lizenz

Dieses Projekt wird als werbefreie, offline-first Anwendung entwickelt und dient dem Fokus auf effektives, ungestörtes Lernen.