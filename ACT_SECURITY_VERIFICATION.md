# ACT_SECURITY_VERIFICATION – Verifikation der Sicherheitsmassnahmen (Ticket 1)

- **Datum:** 21.11.2026
- **Geprüfter Commit:** `39fe9ac` („security(paths): Benutzer- und Dateipfade absichern (Ticket 1)“)
- **Geprüfter HEAD (Stand Verifikation):** `ef2af8a` („docs(security): Referenz-Commit-Hash in Berichten aktualisiert“)
- **Scope:** `lib/`, `test/` – Zielplattformen Android + Linux
- **Auftrag:** reine Verifikation der bereits umgesetzten Sicherheitsmassnahmen. **Keine Codeänderungen** unter `lib/`/`test/`, kein Commit, kein Push.

## 0. Methodik & Ergebnis in Kürze

1. Statische Verifikation des Commits `39fe9ac`: Dateizugriffe, Pfad-Containment (lexikalisch + kanonisch/Symlink), Username-Whitelist, Exception-Flüsse (`PathRejectedException`), relevante Tests.
2. Dynamische Verifikation: vollständige Test-Suite (`flutter test`) sowie statische Analyse (`flutter analyze`).

**Gesamturteil: Alle geforderten Schutzziele sind umgesetzt und belegt – VERIFIZIERT / BESTANDEN.**

- `flutter analyze` → **No issues found!** (0 Issues)
- `flutter test` (komplette Suite) → **209/209 bestanden** (`EXIT=0`, „All tests passed!“) – *aktualisiert am 22.11.2026, Stand HEAD `93c5e0f`; die Ticket-1-Verifikation zählte 151 Testfälle (siehe Notiz in Abschnitt 5).*

## 1. Legacy-Benutzer – `deleteUser('Max Müller')`

**Kann das Profil gelöscht werden? – JA.**
`UserManagerImpl.deleteUser` (`lib/managers/user_manager.dart:122–180`) verlangt `trim != ''`, prüft die Mitgliedschaft in `registered_user` und entfernt den Eintrag aus der Liste (inkl. Login-Reset, falls der gelöschte Benutzer eingeloggt ist). Die eigentliche Dateilöschung läuft über das neue `FileService.deleteFile`.

**Wie werden `.json` und `.bak` behandelt?**
Eine Schleife über `['.json', '.json.bak']` (`user_manager.dart:163`) ruft für beide Dateien `deleteFile` auf (Z. 166). `deleteFile` (`lib/services/file_service.dart:371–382`) unterliegt derselben zentralen Containment-Prüfung wie Lesen/Schreiben; fehlende Dateien werden still ignoriert (`if (!await file.exists()) return;`). Für ein Normalkonto werden damit Primärdatei und Backup-Generation vollständig entfernt.

**Ist die Whitelist bewusst anders umgesetzt? – JA (gewollt und dokumentiert).**
`deleteUser` erzwingt im Gegensatz zu den fünf anderen Benutzernamen-Operationen (`createUserFile`, `loadUserdata`, `saveUserdata`, `addNewUserToList`, `setLoggedUname`) **keine** Namens-Whitelist. Grund: Legacy-Profile (Whitelist-ferne Namen wie Umlaute/Leerzeichen, z. B. `Max Müller`) müssen weiterhin löschbar bleiben. Die Sicherheit wird stattdessen auf der Datei-Ebene erzwungen:
- Ein unschädlicher Legacy-Name (`Max Müller`) passiert `_assertSafeRelativePath` und `_ensureCanonicalWithinAppDir` → die Datei(en) werden sicher gelöscht.
- Ein manipulierter Name (Traversal wie `../…`) wird von `deleteFile` abgelehnt → `PathRejectedException` wird gefangen und als **sichtbarer** Hinweis gemeldet (nie als stiller Erfolg verkauft, `user_manager.dart:167–177`); eine „Kanarien“-Datei bleibt nachweislich unangetastet.

**Belegende Tests (grün):**
- `Legacy-Profile (Whitelist-ferne Namen) bleiben erhalten und lassen sich sicher löschen` – `Max Müller`, inkl. „Lesen → null, Datei bleibt unangetastet“ und „Löschen → Datei weg, Liste leer“ (`test/user_manager_test.dart`).
- `entfernt auch die .bak-Datei des Benutzers` – `alice` mit `.json` + `.json.bak`.
- `entfernt manipulative Namen aus der Liste, löscht aber keine Dateien über den Traversal-Pfad` – mit Kanarien-Datei (`../…`).

**Befund / Kleinst-Lücke:** Ein Legacy-Test, der **gleichzeitig** `.json` **und** `.json.bak` anlegt, fehlt; der kombinierte Fall wird aber durch die identische Löschschleife und den separaten `alice`-`.bak`-Test implizit abgedeckt. **Kein neuer Test eingefügt** (Auftrag: keine Codeänderungen).

## 2. Symlink-Containment – `_ensureCanonicalWithinAppDir`

**Aufbau:** `_canonicalAppDirPath` (Z. 89–100) liefert den kanonischen Basis-Pfad (Symlink-aufgelöst; Fallback auf lexikalischen Pfad, falls noch nicht auflösbar). `_resolveAppPath`/`_assertSafeRelativePath` (Z. 102–127) prüfen die Pfadform lexikalisch (leer, NUL, absolut, Windows-Drive, `..`/`.`-Segmente auf Slash **und** Backslash). `_ensureCanonicalWithinAppDir` (Z. 138–159) prüft die kanonische Zugehörigkeit, und `_isWithin` (Z. 161–165) vergleicht real-pfadbasiert (keine String-Prefix-Falle).

**Kanonischer Pfad bei nicht existierenden Dateien / verschachtelten, noch nicht existierenden Verzeichnissen:**
- Datei fehlt → `File.resolveSymbolicLinks()` wirft `FileSystemException` → Fallback auf `File(...).parent.resolveSymbolicLinks()`, das die nächstliegende **existierende** Verzeichnisebene kanonisch auflöst.
- Existieren weder Datei **noch** Parent → früher `return` (kein Symlink kann ins Leere zeigen); der Pfad war zuvor bereits lexikalisch validiert.
- **Schreibpfade:** `_writeFileAtomic` erzeugt den Parent zuerst (`parent.create(recursive: true)`, Z. 341–343) und führt die kanonische Prüfung danach aus (Z. 347). Ein über einen Symlink angelegter/traversierter Parent existiert damit zum Prüfzeitpunkt und wird zuverlässig als „ausserhalb“ erkannt.

**Können vorhandene Symlinks in einem Parent-Verzeichnis umgangen werden? – Nein (statische Lagen).**
`parent.resolveSymbolicLinks()` löst die gesamte Kette auf; das Ergebnis wird real-pfadbasiert gegen den kanonischen App-Dir verglichen. Ein Ausbruch über eine Symlink-Kette wird abgelehnt.

**Sind Lesen, Schreiben und Löschen gleichermassen abgesichert? – JA.**
Je ein Aufruf der Prüfung in:
- `loadJson` (Z. 264),
- `_writeFileAtomic`/`saveJson` (Z. 347),
- `deleteFile` (Z. 373).

**Belegender Test (grün):** `Symlink-Ausbruch wird abgelehnt (Lesen, Schreiben, Löschen)` – legt einen Symlink `linked → outside` an und verifiziert `PathRejectedException` für `saveJson`/`loadJson`/`deleteFile` von `linked/x.json` sowie, dass die Outside-Datei unangetastet bleibt (`test/file_service_test.dart`).

**Dokumentiertes Restrisiko (akzeptiert):** TOCTOU/Symlink-Race – ein zwischen Prüfung und Zugriff ausgetauschtes Verzeichnis ist mit `dart:io` (kein `O_NOFOLLOW`) nicht atomar abwehrbar; auf Android ist das appDir privat/nicht angreifer-beschreibbar, auf Linux-Desktop besässe ein Angreifer mit Schreibzugriff auf das appDir ohnehin direkten Datenzugriff. Siehe `ACT_SECURITY_PATHS.md`/`_UMSETZUNG.md`.

## 3. Fehlerbehandlung – `PathRejectedException` an relevanten Aufrufstellen

`PathRejectedException extends PersistenceException` (`file_service.dart:34–39`); damit greifen alle bestehenden `on PersistenceException`-Blöcke weiterhin kontrolliert. Zusätzlich verifizierte, explizite Behandlung:

| Stelle | Datei / Zeile | Verhalten |
|--------|---------------|-----------|
| `UserState._saveSafe` | `user_state.dart:131` (vor Z. 134) | eigener `on PathRejectedException`-Zweig → Log + Bus |
| `VocabManagerImpl._saveSafe` | `vocab_manager.dart:47` (vor Z. 50) | eigener `on PathRejectedException`-Zweig → Log + Bus |
| `UserState.registerUser` | `user_state.dart:87` | defensiver `on PathRejectedException`-Catch um `addNewUserToList`/`changeLoginState`/`setLoggedUname` |
| `_writeFileAtomic` | `file_service.dart:356` | `rethrow` – Ablehnung wird NIE als „normaler Schreibfehler“ verpackt |
| `deleteUser` | `user_manager.dart:167–174` | unterscheidet `PathRejectedException` von generischer `PersistenceException` (getrennte Meldungen); fängt intern → keine unkontrollierte Ablehnung an die UI |
| `loadLanguageDictFromDir` | `file_service.dart:407` | unsicherer Sprachcode ⇒ `{}` + Log (read-only Best-Effort) |

**Vollständigkeit des Angriffsrestes:** Außerhalb von `file_service.dart` existiert kein direkter `File(...)`-Zugriff; einzige Ausnahme ist `recoverAppData` (`user_manager.dart:247`), das `Directory.list()` auf dem appDir selbst nutzt (read-only, `.bak`/`.tmp` gefiltert) und bewusst ungefiltert bleibt (Bestandserhalt), mit Abfangen ungültiger Namen an den Operations-Grenzen. `updateJsonKey` läuft vollständig über die `loadJson`/`saveJson`-Containment-Prüfung (Test `updateJsonKey lehnt Traversal-Pfade ab`).

**UI-Beobachtung (nicht sicherheitskritisch):** `SettingsScreen._requestDeleteUser` (`settings_screen.dart:77`) ruft `um.deleteUser(name)` und zeigt den zurückgegebenen Hinweistext aktuell nicht an (danach nur `dataState.loadAppData()`). Da `deleteUser` intern fängt, ist das rein kosmetisch; empfohlene Folgearbeit wäre die Anzeige des Rückgabewerts.

## 4. Ergebnisse & Abschluss

**Dynamische Verifikation (tatsächlich ausgeführt):**
- `flutter analyze` → **No issues found!** (0 Issues, Lints `flutter_lints` + `analysis_options.yaml`).
- `flutter test` (vollständige Suite) → **151/151 bestanden** (`EXIT=0`, „All tests passed!“).

**Belegte Sicherheitstests (einzeln ausgeführt, grün):**
- `file_service_test.dart`: Traversal (`../`), absolute Pfade (Unix & Windows-Drive), Backslash-Traversal, NUL/leer, `.`-Segmente, `updateJsonKey`-Traversal, legitime Unterverzeichnisse, Symlink-Ausbruch (Lesen/Schreiben/Löschen).
- `user_manager_test.dart`: unsichere Namen über alle sechs Operationen, Traversal-Lösch-Schutz (Kanarien-Datei), `.bak`-Löschung, **Legacy-Profil `Max Müller`** (Erhalt → sicheres Löschen).

**Status der vier Prüfpunkte:**
1. Legacy-Benutzer: **verifiziert** (Profil löschbar; `.json`+`.bak` via `deleteFile`; Whitelist bei `deleteUser` bewusst anders – Datei-Containment statt Name; Test vorhanden).
2. Symlink-Containment: **verifiziert** (kanonische Auflösung inkl. Nicht-Existenz-Fällen; statische Parent-Symlinks nicht umgehbar; Lesen/Schreiben/Löschen gleichermassen).
3. Fehlerbehandlung: **verifiziert** (`PathRejectedException` erbt von `PersistenceException`; explizite Zweige und `rethrow` an allen relevanten Stellen).
4. Abschluss: dieser Bericht; keine Codeänderungen, kein Commit, kein Push.

**Referenzen:** `ACT_SECURITY_PATHS.md` (Phase-1-Audit, Basis `02df0e9`), `ACT_SECURITY_PATHS_UMSETZUNG.md` (Phase-2-Bericht, Commit `39fe9ac`).

## 5. Android-Auto-Backup – User-Daten von Cloud-Backups ausgeschlossen

- **Datum:** 22.11.2026
- **Fix:** `android/app/src/main/AndroidManifest.xml` Z. 6: `android:allowBackup="false"` im `<application>`-Tag ergänzt (einzige Manifest-Änderung; kein `fullBackupContent`, kein `dataExtractionRules`, keine `res/xml`-Regeln).
- **Begründung:** Rein lokale App, keine backup-würdigen Daten; Nutzerprofile/Lernfortschritt (`data_app/files_user/data_*.json`, `data_app/app_data.json`, `data_app/last_session.json`) sollen nicht in Google-Cloud-Backups bzw. `adb backup` landen. Ein Geräte-Umzug ist damit **bewusst ausgeschlossen** – Wörterbücher/`data_base` sind aus den Asset-Bundles regenerierbar (`lib/services/file_service.dart` `initialize()`, Z. 238–258). `allowBackup="false"` deaktiviert Auto Backup ab API 23, `adb backup` und – bei targetSdk 36/compileSdk 36, minSdk 24 – Cloud-/Device-Transfer unter API 31+.
- **Verifikation (Build):** `flutter build apk --debug` ✓ → `aapt dump xmltree app-debug.apk AndroidManifest.xml` ⇒ `A: android:allowBackup(0x01010280)=(type 0x12)0x0` (= **false**). applicationId: `com.example.learn_a_language` (`android/app/build.gradle.kts` Z. 19).
- **Testanzahl (aktuell gehalten):** `flutter test` → **209/209 bestanden** (`EXIT=0`, „All tests passed!“). Hinweis: Die 151 Testfälle der Ticket-1-Verifikation (Abschnitt 4) sind durch nachfolgende Feature-Commits (WordSearch, Crossword, Hangman, Fill In) auf 209 angewachsen; die Manifest-Änderung betrifft keine Dart-Logik.