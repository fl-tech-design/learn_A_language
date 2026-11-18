# Learn A Language

Eine leistungsstarke, **offline** nutzbare Sprachlern-App **ohne Werbung**. 
Dieses Projekt ist eine vollständige Migration einer zuvor in Python/Kivy entwickelten App nach **Flutter (Dart)**, optimiert für Android und Linux Desktop.

**[English](README.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md)**

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
- **Navigation**: go_router (deklaratives Routing)
- **Datenpersistenz**: Lokale JSON-Speicherung via path_provider (mit automatischem Asset-Copy beim ersten Start)
- **UI/Design**: google_fonts (Jura, Boycott, LiberationSerif) und ein massgeschneidertes AppTheme für ein konsistentes Erscheinungsbild.

## Projektstruktur

Das Projekt folgt einer sauberen, modularen Architektur im `lib/`-Verzeichnis, die Wartbarkeit und Skalierbarkeit gewährleistet:

lib/
├── main.dart            # Einstiegspunkt der App
├── managers/            # Geschäftslogik (AppState, User, Vocab, Language)
├── screens/             # UI-Ansichten (Loading, Start, Learning, Settings, etc.)
├── services/            # Dienste (z. B. FileService für JSON-Persistenz)
├── models/              # Datenmodelle
├── widgets/             # Wiederverwendbare UI-Komponenten
├── dialogs/             # Pop-ups und Dialoge (Info, Login, GameOver, etc.)
└── theme/               # Zentrale Farbpalette und ThemeData

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

### Installation über WLAN-Debugging (Android, ohne Datenverlust)

> `flutter run` oder eine normale Installation **löscht niemals** App-Daten.
> Daten gehen nur beim **Deinstallieren** der App verloren. Eine neue Version
> über die bestehende App installieren behält alle lokalen Benutzerdaten
> (Wörter, Levels, Streaks).

1. Auf dem Handy **Entwickleroptionen → Drahtloses Debugging** aktivieren (falls nötig zuerst `adb pair`):
   adb pair 192.168.0.133:PORT
2. Mit Adresse/Port verbinden:
   adb connect 192.168.0.133:40917
3. Eine **Debug**-Version über die aktuelle App installieren und starten (ohne Datenverlust):
   flutter run -d 192.168.0.133:40917
   # oder ein vorbereitetes Debug-APK installieren, ohne zu starten:
   flutter build apk --debug
   adb -s 192.168.0.133:40917 install -r build/app/outputs/flutter-apk/app-debug.apk

> Das Flag `-r` ersetzt die App und behält ihre Daten. Falls eine
> „signature mismatch“-Meldung kommt, hat die installierte App eine andere
> Signatur (z. B. eine Release-Version) — Deinstallieren wäre nötig, daher am
> besten passende Build-Typen verwenden (Debug → Debug).

## Migration von Kivy zu Flutter

Die App wurde erfolgreich von Python/Kivy nach Flutter migriert. Dabei wurde besonderer Wert auf folgende Punkte gelegt:
- **100% Datenkompatibilität**: Die JSON-Datenstruktur bleibt vollständig abwärtskompatibel zu bestehenden Benutzerdaten aus der Kivy-Version.
- **Vollständige Portierung**: Alle 8 Bildschirme, 6 Dialoge und 5 Manager-Klassen wurden 1:1 in Dart übertragen.
- **Stabilität**: Umfassende Bugfixes für Linux Desktop und Android, inklusive plattformsicherer Funktionen (z. B. closeApp).

## Lizenz

Dieses Projekt wird als werbefreie, offline-first Anwendung entwickelt und dient dem Fokus auf effektives, ungestörtes Lernen.