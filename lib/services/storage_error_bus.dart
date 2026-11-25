import 'package:flutter/foundation.dart';

/// Typen von Speicher-/Persistenzfehlern, die der UI gemeldet werden.
///
/// Die Nachrichten-Übersetzung passiert ausschließlich in der Widget-Schicht
/// (`StorageWarningListener`), damit Manager/Fakes keine i18n-Abhängigkeit
/// bekommen.
enum StorageErrorKind {
  /// Generischer Schreib-/Speicherfehler (z. B. volle Disk).
  saveFailed,

  /// Fortschritts-Speicherung im Antwort-Pfad fehlgeschlagen (Level-Gewinn
  /// wurde nicht persistiert, das Spiel lief weiter).
  progressNotSaved,

  /// Eine Benutzerdatei war beschädigt und konnte aus `.bak` gerettet werden.
  userDataRecovered,

  /// Eine Benutzerdatei (und das Backup) waren unbrauchbar.
  userDataUnloadable,

  /// `app_data.json` war beschädigt; die Benutzerliste wurde aus den
  /// vorhandenen `data_*.json`-Dateien rekonstruiert.
  appDataRecovered,

  /// Beim Start konnten nicht alle Bundle-Assets (Wörterbücher/Daten) ins
  /// App-Verzeichnis kopiert werden – die App läuft, aber mit unvollständigen
  /// Daten. Details (betroffene Pfade) liefert `FileService.initialize`.
  assetsCopyFailed,
}

/// Appweiter, einmaliger Fehlerkanal für Persistenzprobleme.
///
/// Meldungen werden pro Ablauf nur einmal gehalten und durch
/// [takeLast] konsumiert – dadurch können weder Dialoge noch SnackBars
/// spammen (kein Wiederholen bei jedem `notifyListeners`/Build).
class StorageErrorBus extends ChangeNotifier {
  StorageErrorBus._();

  static final StorageErrorBus instance = StorageErrorBus._();

  StorageErrorKind? _pending;

  /// Meldet einen Speicherfehler; [notifyListeners] weckt den UI-Listener.
  void report(StorageErrorKind kind) {
    _pending = kind;
    notifyListeners();
  }

  /// Liefert und konsumiert die letzte Meldung (einmalig).
  StorageErrorKind? takeLast() {
    final kind = _pending;
    _pending = null;
    return kind;
  }

  bool get hasPending => _pending != null;

  /// Setzt den Zustand zurück (nur für Tests).
  void clear() {
    _pending = null;
    notifyListeners();
  }
}
