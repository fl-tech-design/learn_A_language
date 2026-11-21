# ACT_SECURITY_PATHS – Umsetzungsbericht (Phase 2)

- **Datum:** 21.11.2026
- **Basis-Commit:** `02df0e9`
- **Umgesetzt nach Freigabe** des ACT_Berichts (`ACT_SECURITY_PATHS.md`) inkl. der Ergänzungen zu Symlink/TOCTOU, `updateJsonKey`, Legacy-Benutzern und Fehlerbehandlung.

## 1. Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `lib/services/file_service.dart` | `PathRejectedException extends PersistenceException`; zentrale lexikalische Containment-Prüfung (`_resolveAppPath`/`_assertSafeRelativePath`), kanonische Symlink-Containment-Prüfung (`_ensureCanonicalWithinAppDir`); Einbau in `loadJson`, `saveJson`, `_writeFileAtomic`, `loadLanguageDictFromDir`; neue Interface-Methode `deleteFile`. |
| `lib/managers/user_manager.dart` | Zentrale Whitelist-Validierung `_safeUsername` in allen sechs Benutzernamen-Operationen (`createUserFile`, `loadUserdata`, `saveUserdata`, `addNewUserToList`, `deleteUser`, `setLoggedUname`); `deleteUser` löscht Dateien jetzt über `FileService.deleteFile` (Containment-Prüfung für Normal- und Legacy-Profile). |
| `lib/managers/user_state.dart` | Expliziter `on PathRejectedException`-Zweig in `_saveSafe`; defensiver `PathRejectedException`-Catch in `registerUser` (kein stiller Durchlauf von ungültigen Namen). |
| `lib/managers/vocab_manager.dart` | Expliziter `on PathRejectedException`-Zweig in `_saveSafe`. |
| `test/helpers/fakes.dart` | `FakeFileService.deleteFile` (simuliert appDir-Fehler via `appDirThrows`, sonst Store-Entfernung). |
| `test/file_service_test.dart` | +9 Pfad-Containment-Tests (Traversal, absolute Pfade, Windows-Drive, Backslash, NUL, leer, `.`-Segmente, `updateJsonKey`, legitime Unterverzeichnisse, Symlink-Ausbruch). |
| `test/user_manager_test.dart` | 2 bestehende Lösch-Tests auf echten `FileServiceImpl` migriert (Deletion läuft jetzt über `deleteFile`); +8 neue Sicherheits-Tests (unsichere Namen über alle Operationen, Traversal-Lösch-Schutz, Legacy-Löschung, Trim-Normalisierung). |
| `ACT_SECURITY_PATHS.md` | Phase-1-Audit-Bericht (neu). |
| `ACT_SECURITY_PATHS_UMSETZUNG.md` | Dieser Abschlussbericht (neu). |

## 2. Sicherheitsmaßnahmen

1. **Usernamen-Whitelist zentral:** `String? _safeUsername(String)` = `trim` + vorhandenes Muster `^[A-Za-z0-9_-]+$`; angewendet in **allen** Benutzernamen-Pfaden. Damit kann ein Name nie `..`, `/`, `\`, Laufwerksbuchstaben oder Leerzeichen enthalten.
2. **Lexikalische Pfad-Containment (FileService):** Ablehnung leeres/leeres NUL, absolute Pfade (Unix `/` und Windows-Drive `C:`), `.`/`..`-Segmente – Split auf **Slash und Backslash** (Windows-Varianten abgedeckt).
3. **Kanonische Symlink-Containment:** `File.resolveSymbolicLinks()` (bzw. Parent) gegen kanonisiertes App-Verzeichnis; Ausbrüche per Symlink-Kette werden abgelehnt. Basis-Vergleich ist Realpfad-basiert (keine String-Prefix-Fallstricke).
4. **`loadLanguageDictFromDir`:** unsicherer Sprachcode ⇒ `{}` + Log (read-only Best-Effort, kein externer Zugriff).
5. **`deleteFile`:** Löschen nur über die zentrale Prüfung – manipulationssichere Löschung auch für Legacy-Profile.
6. **`updateJsonKey`:** komplett durch `loadJson`/`saveJson`-Containment abgedeckt (test-seitig belegt).
7. **Fehlerbehandlung:** `PathRejectedException` erbt von `PersistenceException` (bestehende Catch-Blöcke greifen), erhält aber eigene, explizite `on`-Zweige in den Safe-Wrappern; `_writeFileAtomic` reicht sie per `rethrow` durch; `deleteUser` signalisiert Ablehnungen sichtbar statt still.
8. **Keine neuen Abhängigkeiten**, keine Interface-Umbrüche außer der bewussten, kleinen `deleteFile`-Erweiterung, keine UI-Änderungen.

## 3. Testergebnisse

- `flutter analyze` → **No issues found!** (0 Issues, Lints `flutter_lints` + `analysis_options.yaml`).
- `flutter test` (komplette Suite) → **151/151 Tests bestanden** (vorher 140; +9 Datei-Containment- und +8 UserManager-Sicherheitstests, einzelne Test-Umstellungen).
- Gezielte Sicherheitstests grün: Traversal (`../`, `..`, `.`, Backslash), absolute Pfade, Drive-Buchstaben, NUL, leerer Pfad, `updateJsonKey`, Symlink-Ausbruch (Read/Write/Delete), unsichere Benutzernamen in allen sechs Operationen, Traversal-Lösch-Schutz mit „Kannarinen“-Datei, Legacy-Profil `Max Müller` (Erhalt → sicheres Löschen), Trim-Normalisierung `' alice '` → `alice`.

## 4. Verbleibende Risiken (bewusst dokumentiert)

- **TOCTOU / Symlink-Race:** Eine Prüfung vor dem Zugriff kann keinen zwischenzeitlichen Austausch eines Verzeichnisses durch einen Symlink atomar verhindern (dart:io bietet kein `O_NOFOLLOW`). Praktische Minderung: Auf Android ist das appDir privat und nicht angreifer-beschreibbar; auf Linux-Desktop hätte ein Angreifer mit Schreibzugriff auf das appDir ohnehin direkten Datenzugriff. Schutz wirkt gegen statische und vorkonfigurierte Symlink-Lagen.
- **Legacy-Login unverändert:** Whitelist-ferne Legacy-Profile (z. B. Umlaute/Leerzeichen) können sich nach der Härtung nicht mehr einloggen (sichtbarer Hinweis „Benutzer ist nicht registriert“). Die Daten bleiben unangetastet; Löschung ist über `deleteUser` sicher möglich. Keine automatische Umbenennung/Migration (wie gefordert) – eine gesonderte Migrations-Freigabe wäre nötig, um solche Profile wieder login-fähig zu machen.
- **Lange Namen:** Kein neues Längenlimit eingeführt (Bestandskompatibilität); `ENAMETOOLONG`/`E2BIG` werden weiterhin als `PersistenceException` kontrolliert behandelt.
- **Andere externe Pfadquellen:** Aktuell keine weiteren Pfad-Einstiegspunkte in der Anwendung; bei künftigen Features müssen neue „relative Path“-Aufrufe durch `FileService` gehen, um die Containment-Prüfung zu erben.

## 5. Commit

- Local Commit: **`2599b58`** auf `main` („security(paths): Benutzer- und Dateipfade absichern (Ticket 1)“, 9 Dateien, +621/−50) – nach erfolgreicher Prüfung (`flutter analyze` 0 Issues, `flutter test` 151/151 grün).
- **Push an `origin` bewusst NICHT ausgeführt** – erfolgt erst nach deiner Freigabe („Commit und Push erst nach erfolgreicher Prüfung“).
