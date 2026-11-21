# ACT_SECURITY_PATHS – Audit: Benutzer- und Dateipfade absichern

- **Datum:** 21.11.2026
- **Basis-Commit:** `02df0e9` (`main`, Arbeitsbaum sauber)
- **Scope:** `lib/`, `test/`, Zielplattformen Android + Linux
- **Status:** Phase 1 Audit abgeschlossen, Phase 2 freigegeben und umgesetzt (Ergänzungen eingearbeitet, siehe Abschnitt 8)

## 1. Methodik

1. Volltextsuche über `lib/` und `test/` nach Dateizugriffen (`File`, `Directory`, `rootBundle`, `resolveSymbolicLinks`, Pfad-Interpolationen, `appDir`-Nutzung).
2. Nachverfolgung jedes externen Eingangs (Benutzername, Sprachcode, JSON-Felder) bis zum Dateizugriff inkl. aller Caller.
3. Prüfung auf Traversal-Primitive (`../`, `.`, absolute Pfade, Windows-Drive/Backslash, NUL) und Symlink-Lagen.
4. Risikobewertung getrennt für Android und Linux-Desktop.
5. Konzept zentrale Absicherung (zwei Schichten) ohne neue Abhängigkeiten und ohne Interface-Brüche.

## 2. Inventar der Dateioperationen und Aufrufstellen

| # | Datei / Methode | Zeile¹ | Pfadkonstruktion | Eingabe | Validierung damals |
|---|------------------|--------|------------------|---------|---------------------|
| 1 | `FileServiceImpl.initialize` | 66 | `File('$dir/.initialized')` | Konstante | – |
| 2 | `FileServiceImpl.initialize` | 141 | `File('$dir/$rel')` (Asset-Kopie) | Konstante Liste (69–132) | – |
| 3 | `FileServiceImpl.loadJson` | 160 | `File('$dir/$relativePath')` | **Caller** | ❌ |
| 4 | `FileServiceImpl.loadJson` | 172 | `File('$dir/$relativePath.bak')` | **Caller** | ❌ |
| 5 | `FileServiceImpl.loadJson` (Reparatur) | 181 | `_writeFileAtomic(file.path, …)` | **Caller** | ❌ |
| 6 | `FileServiceImpl.saveJson` | 213 | `_writeFileAtomic('$dir/$relativePath', …)` | **Caller** | ❌ |
| 7 | `FileServiceImpl._writeFileAtomic` | 233/241/244 | `File(abs)`, `.bak`, `.tmp` | intern | ❌ |
| 8 | `FileServiceImpl.loadBundledJson` | 262–276 | `rootBundle.loadString(assetPath)` | Caller | n/a (Bundle, kein FS) |
| 9 | `FileServiceImpl.loadLanguageDictFromDir` | 282/287 | `Directory('$dir/language_dict/$langCode')` + `list()` | `langCode` | ❌ |
| 10 | `UserManagerImpl.createUserFile` | 49/68 | `data_app/files_user/data_$normalized.json` | Username | ✅ Whitelist |
| 11 | `UserManagerImpl.loadUserdata` | 74–75 | `data_app/files_user/data_$username.json` | **Username** | ❌ |
| 12 | `UserManagerImpl.saveUserdata` | 82–83 | `data_app/files_user/data_$username.json` | **Username** | ❌ |
| 13 | `UserManagerImpl._readAppData` | 168 | `data_app/app_data.json` | Konstante | – |
| 14 | `UserManagerImpl._saveAppDataSilently` | 191 | `data_app/app_data.json` | Konstante | – |
| 15 | `UserManagerImpl.deleteUser` | 134/138 | `File('$dir/…/data_$username.json')` (+ `.bak`) | **Username** | ❌ (nur trim + Listenmitglied) |
| 16 | `recoverAppData` | 206–231 | `Directory.list()` (nur lesend) | Dateinamen | Filter `data_*.json`; `u_name` ungeprüft |

¹ Zeilennummern beziehen sich auf den Ausgangsstand (Basis-Commit).

**Aufrufstellen der kritischen Pfade:**

- `loadUserdata(username)` ← `UserState.login` (Login-Dialog im Start-Screen **und Auto-Login im LoadingScreen**), `UserState._loadSafe/_loadUserData`, `VocabManagerImpl._loadSafe`, `UserState.addCourse/removeCourse` (dort mit `_userData!.uName` aus der User-JSON).
- `saveUserdata(username, …)` ← `_saveSafe` in `user_state.dart`/`vocab_manager.dart`.
- `deleteUser(username)` ← `SettingsScreen._requestDeleteUser` (Freitext-Dialog).
- `setLoggedUname(user)` ← `UserState.login/registerUser`; schreibt nach `app_data.json` und wird **beim nächsten Appstart durch den Auto-Login direkt zu einem Dateipfad**.
- `addNewUserToList(user)` ← `UserState.registerUser`.
- `loadLanguageDictFromDir(langCode)` ← `VocabManagerImpl` mit `ud.mLang` (JSON-Feld) bzw. abgeleitetem `'de'/'en'`.
- `updateJsonKey` ← `DataState.changeLanguage` (`data_base/base_data.json`, Konstante) und `SettingsScreen._updateAppDataKeySafe` (`data_app/app_data.json`, Konstante).


## 3. Externe Eingaben → Dateipfad

| Eingabe | Quelle | Pfadfluss | Gating vor Umsetzung |
|---------|--------|-----------|----------------------|
| Benutzername (Registrierung) | Dialog Freitext | `createUserFile` → `data_$name.json` | ✅ Whitelist `^[A-Za-z0-9_-]+$` |
| Benutzername (Login-Dialog) | Aus Liste (`registered_user`) | `login` → `loadUserdata` | ⚠️ Liste kann manipulierte Traversal-Strings enthalten |
| `logged_u_name` (Persistenz) | `app_data.json`, Auto-Login | automatisch beim Start → `loadUserdata` | ❌ ohne Gating, ohne UI-Schritt |
| Benutzername (Löschen) | Dialog Freitext | `deleteUser` → Datei + `.bak` | ⚠️ nur `users.contains(…)` |
| `u_name` (User-JSON) | Datei auf Disk | `addCourse/removeCourse/…` → `loadUserdata/saveUserdata(u_name)` | ❌ |
| `m_lang` (User-JSON) | Datei auf Disk | `loadLanguageDictFromDir(mLang)` | ❌ |

## 4. Prüfung auf Pfadprimitive (Ergebnisse)

### 4.1 `../`-Traversal
**Vorhanden.** Template `data_app/files_user/data_$name.json`; ein manipulierter Name wie `/../../../../etc/passwd` ergibt nach Normalisierung Pfade ausserhalb des App-Verzeichnisses. Betroffen waren Read (`loadUserdata`), Write (`saveUserdata`), Delete (+`.bak`) und `loadLanguageDictFromDir`. Die Registrierung war durch die Whitelist gehärtet – die Brücke bildeten manipulierte Felder (`registered_user`, `logged_u_name`, `u_name`, `m_lang`) bzw. ein bearbeitetes `app_data.json` (Backup-Restore, Storage-Tampering); der **Auto-Login zündet ohne UI-Schritt**.

### 4.2 Absolute Pfade / Windows-Varianten
`loadJson`/`saveJson` akzeptierten absolute Pfade (führendes `/`, Windows-Drive `C:\…`). Backslash als Separator wurde nirgends behandelt (auf Windows voll wirksam, auf Linux nur „normales“ Dateizeichen). NUL-Sequenzen führten zu OS-Fehlern (bereits kontrolliert), werden der Vollständigkeit halber mit abgelehnt.

### 4.3 Symlinks
**Keine einzige `resolveSymbolicLinks`-Nutzung** im gesamten Codebestand. Das appDir selbst kann ein Symlink sein (z. B. Home auf anderem Device, macOS `/var`↔`/private/var`) – String-Prefix-Vergleiche wären anfällig für False-Positive/False-Negatives. Ein im appDir platzierter Symlink (Linux-Desktop: nutzerkontrolliert; Android: privates `/data/user/0/<pkg>/files`, praktisch nicht) würde Pfade nach aussen umlenken.

## 5. Risikobewertung

- **Android:** App-Sandbox + SELinux/UID-Trennung begrenzen Ausbrüche auf das **app-eigene** Datenverzeichnis (u. a. shared_prefs, eigene DBs). Real-Szenario: manipulierter Auto-Login-Name liest/überschreibt/löscht app-eigene Daten. **Risiko mittel** (Integrität/Verfügbarkeit eigener Daten), Exploiterbarkeit niedrig (lokaler Storage-Zugriff nötig).
- **Linux-Desktop:** Kein Sandbox. Gleiche Einstiegspfade, aber Ziel pfadfrei bis in den gesamten nutzerzugänglichen Bereich. **Risiko mittel–hoch** bei Storage-Tampering; über die UI allein nicht erreichbar.
- **Gesamt:** Keine Remote- oder UI-only-Schwachstelle, aber die Datei-API war ein ungehärteter Vertrauensanker; Auto-Login und `u_name`/`m_lang` bildeten verlässliche Brücken. Die Ticket-Härtung (Defense-in-Depth) ist gerechtfertigt.


## 6. Umsetzungskonzept (Phase 2, freigegeben)

### Ebene A – `FileServiceImpl` (zentrale Pfad-Containment)
1. **`PathRejectedException extends PersistenceException`** – eigene Exception, erbend, damit alle bestehenden `on PersistenceException`-Catch-Blöcke kontrolliert greifen und gezielt auf diesen Typ geprüft werden kann. Ein abgelehnter Pfad wird bei `loadJson` **nicht** als „{ } / Datei fehlt“ gewertet.
2. **Lexikalische Prüfung `_assertSafeRelativePath`/`_resolveAppPath`:** leer, NUL, absolut (`/`-Prefix, Windows-Drive-Regex), `..`/`.`-Segmente (Split auf **Slash UND Backslash**) → `PathRejectedException`; Rückgabe `'$dir/safePath'`.
3. **Kanonische Containment-Prüfung `_ensureCanonicalWithinAppDir`:** kanonischer App-Dir als Basis (auflösbar, mit Fallback auf lexikalischen Pfad), Ziel `File.resolveSymbolicLinks()` (sonst Parent; wenn nichts existiert → überspringen); Ergebnis ausserhalb der Basis → `PathRejectedException`.
4. Anwendung in `loadJson`, `saveJson`, `_writeFileAtomic` (Backstop nach `parent.create`; `PathRejectedException` wird per `rethrow` NICHT als generische PersistenceException verpackt), `loadLanguageDictFromDir` (Ablehnung ⇒ `{}` + Log) und neuem **`deleteFile(relativePath)`**.
5. **TOCTOU (Ergänzung 1):** dart:io bietet keinen atomaren „O_NOFOLLOW“-Zugriff. Die Prüfung schützt belastbar gegen statische/vorkonfigurierte Symlink-Lagen; ein **Tausch eines Verzeichnisses durch einen Symlink zwischen Prüfung und Zugriff ist nicht vollständig abwehrbar**. Praktisch hat ein Angreifer mit Schreibzugriff auf das appDir (Linux-Desktop) ohnehin direkten Datenzugriff; auf Android ist das appDir nicht angreifer-beschreibbar. Restrisiko wird in ACT_SECURITY_PATHS_UMSETZUNG.md dokumentiert.

### Ebene B – `UserManagerImpl` (zentrale Namensvalidierung)
- Eine Privatmethode `String? _safeUsername(String)` = `trim` + bestehende Whitelist; angewendet in **allen** Benutzernamen-Pfaden:
  - `createUserFile`: Semantik unverändert (über Helper).
  - `loadUserdata`: ungültig ⇒ `null` (kein Dateizugriff; sichtbar als „nicht registriert“).
  - `saveUserdata`: ungültig ⇒ `PathRejectedException`.
  - `addNewUserToList`/`setLoggedUname`: ungültig ⇒ `PathRejectedException` – manipulierte Namen können nie mehr in `registered_user`/`logged_u_name` landen (Auto-Login-Vektor geschlossen). Nebeneffekt: gepolsterte Namen werden normalisiert (behebt Trim-Inkonsistenz aus `registerUser`).
  - `deleteUser`: leeres ⇒ „Kein Benutzername angegeben.“ (bestehende Test-Erwartung); Dateilöschung **nur** über das neue `FileService.deleteFile` mit Containment-Prüfung (Legacy-sicher, siehe unten); die Liste wird in jedem Fall bereinigt.
- `recoverAppData`: bewusst **nicht** gefiltert – Bestandsdaten bleiben erhalten; ungültige Namen werden an den Operations-Grenzen abgefangen.

### Ergänzung 2 – `updateJsonKey()`
Vollständiger Pfad: `DataState.changeLanguage`/`SettingsScreen._updateAppDataKeySafe` → `updateJsonKey` → `loadJson` + `saveJson`. Beide Aufrufe laufen jetzt durch `_resolveAppPath`/`_ensureCanonicalWithinAppDir`; damit ist auch dieser Einstiegspunkt abgedeckt (eigener Regressionstest ergänzt).

### Ergänzung 3 – Legacy-Benutzer (Namen ausserhalb der Whitelist)
- **Keine automatische Umbenennung/Migration** (nur mit gesonderter Freigabe).
- **Identifikation:** Legacy-Profile bleiben in `registered_user` sichtbar (`recoverAppData` filtert nicht). Ein Login liefert den sichtbaren Hinweis „Benutzer ist nicht registriert.“ – die Datei bleibt unangetastet (kein stiller Datenverlust).
- **Sicheres Löschen:** `deleteUser` entfernt den Eintrag aus der Liste und löscht die Datei über `FileService.deleteFile`; `deleteFile` erzwingt die zentrale Containment-Prüfung. Unschädliche Legacy-Namen (z. B. `Max Müller`) werden weiterhin gelöscht; Namen mit Traversal-Primitiven können **nie** Dateien ausserhalb löschen (Ablehnung wird gemeldet, nie verschwiegen).

### Ergänzung 4 – Fehlerbehandlung
Untersucht wurden alle `catch`-Blöcke, die `PersistenceException` fangen. Da `PathRejectedException` davon erbt, greifen bestehende Blöcke sicher. Zusätzlich:
- Explizite `on PathRejectedException`-Zweige (vor dem `PersistenceException`-Zweig) in `UserState._saveSafe`, `VocabManagerImpl._saveSafe` und `UserState.registerUser`;
- `_writeFileAtomic` reicht `PathRejectedException` per `rethrow` durch (wird nie als „normale Schreibfehler“-PersistenceException versteckt);
- `deleteUser` unterscheidet `PathRejectedException` von generischen Persistenzfehlern (unterschiedliche Meldungen).
- Kein stillschweigendes Herunterstufen: Ein abgelehnter Pfad führt nie zu `{}`/Erfolgsrückgabe ohne Hinweis.

## 7. Notwendige Tests (Phase 2)

- `test/file_service_test.dart`: `loadJson`/`saveJson`/`updateJsonKey`/`deleteFile` – Traversal, absolute Pfade, Windows-Drive, Backslash, NUL, leerer Pfad, legitime Unterverzeichnisse, Symlink-Ausbruch.
- `test/user_manager_test.dart`: unsichere Namen über alle sechs Operationen, Legacy-Löschung, keine Opfer-Dateien bei Traversal-Namen, Trim-Normalisierung.

## 8. Dokumentierte Entscheidungen aus den Ergänzungen

- **TOCTOU/Symlink (1):** ehrlich dokumentiert – keine Behauptung vollständiger Race-Condition-Sicherheit; Schutz gegen statische Lagen; Restrisiko dokumentiert.
- **updateJsonKey (2):** zentral abgedeckt über `loadJson`/`saveJson`; eigener Test.
- **Legacy (3):** Erhalt der Profile, sichtbarer Hinweis statt stillem Verlust, sicheres Löschen via `deleteFile`; keine Automatik-Migration.
- **Fehler (4):** alle relevanten Catch-Blöcke geprüft; explizite `PathRejectedException`-Zweige; kein „als normaler Dateifehler verpacken“.

→ Ergebnis, geänderte Dateien, Testergebnisse, Restrisiken und Commit-Hash: **ACT_SECURITY_PATHS_UMSETZUNG.md** (Commit `2599b58`)
