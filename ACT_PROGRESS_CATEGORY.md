# ACT_PROGRESS_CATEGORY – Lernfortschritt in der Kategorie

- **Datum:** 23.11.2026 19:17 CET (tatsaechliches Erstellungsdatum, gemessen via `date`; nicht blind uebernommen)
- **Basis-Commit (IST):** `d74bb54` = `d74bb5430f844049842bcb003d198e7b4ef0f575` (`main`, `origin/main`)
- **Referenzstand Pruefer:** `d74bb54` – identisch, kein neuerer Commit (Verweis: `git log -1 --oneline`).
- **Arbeitsbaum:** enthaelt 3 uncommittete Eintraege (siehe Abschnitt 2). Sie verursachen die 5 Testfehler NICHT (K3, Abschnitt 2/9).
- **Scope (Phase 1b):** Analyse + Bericht, KEINE Codeaenderung. Einzige neue Datei: dieser Bericht.
- **Status:** Phase 1b abgeschlossen. Keine Umsetzung von T1–T5 vor dokumentierter Freigabe durch Hanspeter.

## 1. Ausgangslage und Ziel

Der Lernfortschritt ist heute einzig ueber die Userbox erreichbar (`start_screen.dart:413-415`,
`_UserInfoBox._buildBoxBody` → `_actionOutlined(l10n.btnProgress)` → `pushNamed('/progress')`).
Ziel: Jede Sprachkategorie erhaelt ganz unten in der Scroll-Spalte einen Button, der die aktuelle
Kategorie per `pushNamed('/progress_group', arguments: cat.id)` mit aktuellen Fortschrittsdaten laedt.
Nebenbefunde F5–F11 werden im selben Ticket behandelt bzw. dokumentiert (nur mit Freigabe).

## 2. Git-Status des tatsaechlichen Standes (KORRIGIERT gem. K3)

- `git rev-parse HEAD` → `d74bb5430f844049842bcb003d198e7b4ef0f575`
- `git --no-pager log -1 --oneline` → `d74bb54 refactor(audio): Audio-Ordner auf <lang>_audio_<verbKey>-Stil umbenannt`
- HEAD ist exakt der Referenzstand, kein zusaetzlicher Commit.

**`git status --porcelain` (vollstaendig):**
```
 D assets/grammar/grammar_fr/grammar_a1_de_fr.json
?? assets/grammar/grammar_de/grammar_a1_de_es.json
?? assets/grammar/grammar_de/grammar_a1_de_fr.json
```

Diese 3 Eintraege sind WIP von Hanspeter (per Angabe in Phase 1b mitzunehmen). Sie betreffen ausschliesslich
Grammatik-Unterlevel-Assets (`grammar_a1_de_es.json`, `grammar_a1_de_fr.json`, Verschieben des fr-Layouts).

**K3 – Ursache der 5 Testfehler (belegt):** Die Testgruppe „GrammarDocument – echtes Asset" in
`test/grammar_test.dart` enthaelt genau 5 Tests. Alle 5 lesen `File('assets/grammar/grammar_de_en.json')`
und scheitern identisch. Aus dem echten Testlauf (`flutter test`, Log `/tmp/base_test2.txt`):
```
Expected: true
Actual: <false>
cwd=/mnt/d/home_main/fl-tech-design/Projects/Project_lAl/learn_A_language, expected assets/grammar/grammar_de_en.json
```
Belege:
- `git log -1 --stat -- assets/grammar` → letzter Commit auf diesen Pfad ist **e05bcc3**. Darin wurde
  `assets/grammar/grammar_de_en.json` bzw. alle `grammar_*.json` nach **`assets/grammar/grammar_de/`** verschoben
  (und `grammar_fr/grammar_a1_de_fr.json` hinzugefuegt).
- `ls assets/grammar` → enthaelt nur die Unterordner `grammar_de/`, `grammar_es/`, `grammar_fr/`.
- `ls assets/grammar/grammar_de` → enthaelt u. a. `grammar_de_en.json`; ein File `assets/grammar/grammar_de_en.json`
  (direkt unter `grammar/`) existiert NICHT.
- Die 3 WIP-Eintraege betreffen nur `a1_de_es`/`a1_de_fr`, nicht `grammar_de_en.json` – sie verursachen die
  Fehler also nicht. **Die Formulierung „Blocker durch unsauberen Arbeitsbaum" ist damit gestrichen.**

**Offene Entscheidung D11 (rote Baseline):**
- **D11a:** Erst Befund F11 in einem eigenen Ticket beheben, dann dieses Ticket auf gruener Testbasis umsetzen (Empfehlung des Pruefers).
- **D11b:** Parallel umsetzen, mit dokumentierten 5 bekannten Grammatik-Fehlern und pfadgenauen Commits.
## 3. Verifizierte Fakten (Abgleich mit Prueferliste, Stand d74bb54)

| # | Befund (Datei:Zeile) | Status |
|---|----------------------|--------|
| 1 | einziger `/progress`-Einstieg, `l10n.btnProgress` – `start_screen.dart:413-415` | ✅ |
| 2 | Route `/category` String-Id, 3 `_modeButton`+Back, `didPopNext`→`_refreshCounts`, `_start` setzt wordMode/selectedCategoryId, BoxBottom ausserhalb Expanded, 6 Kategorien/1 Datei – `category_screen.dart:33,48-50,72-86,100-137` | ✅ |
| 3 | ProgressScreen listet Collections; 1 Kat.→`/progress_group`(String), sonst `/collection`(mode progress); Helfer `wordCategoryTitle/wordCollectionTitle/categoryCountLabel` – `progress_screen.dart:9-46,59-60,95-106` | ✅ |
| 4 | ProgressGroupScreen read-only; `_summaryRow` learned≥8 / inProgress 1–7 (falsch `catDueWords`)/ newCount==0; Daten via `getGroupWords` – `progress_group_screen.dart:102-104,160-173` | ✅ |
| 5 | getGroupWords liest je Aufruf neu (kein Cache); getCategoryCounts status-/terminbasiert – `vocab_queries.dart:181-191,220-258` | ✅ |
| 6 | routeObserver, statsVersion/notifyStatsChanged, resolveActiveLang – `navigation_state.dart:9-10,26,37-40,70-77` | ✅ |
| 7 | `/progress_group` in restorable+stringArg; LoadingScreen stellt activeCourseId her – `session_manager.dart:63,71`; `loading_screen.dart:87-99` | ✅ |
| 8 | Routen vorhanden; keine neue noetig – `main.dart:117-140` | ✅ |
| 9 | courseFlagAsset/courseLanguageName (hartkodiert deutsch=F5); appLanguages enthaelt el(labelKey greek) – `language_registry.dart:34-65,170-184` | ✅ |
| 10 | _discoverDictLanguages: Seeds de/en/fr + Discovery + refreshAvailableCourses – `data_state.dart:56-70,48-49` | ✅ (el/ru je Bundle-Dicts, laut e05bcc3 vorhanden) |
| 11 | l10n.yaml de/en/es/fr/ru/el/it/pt; 8 arb-Dateien – `l10n.yaml:1-5`; `ls lib/l10n/app_*.arb` → de/el/en/es/fr/it/pt/ru | ✅ |
| 12 | Keys vorhanden (btnProgress/titPageProgress/infProgress/cat*/lab*Short/noWords/colWord/colLevel/greek); catInProgressWords existiert NICHT – `app_localizations.dart:243,831,837,1071`; `grep -rn catInProgressWords lib test` → none | ✅ |

**Abweichungen zur Prueferliste:** keine inhaltlichen. Einzig Fakt 10 („waechst um el/ru") haengt von tatsaechlich
im Bundle vorhandenen Dicts ab; der Mechanismus stimmt.

## 4. Arbeitspakete T1–T5 mit Einfuegestellen und Diff-Skizzen

### T1 – Button „Lernfortschritt" als letztes Element (category_screen.dart)
Einfuegestelle: Scroll-`Column` (Zeilen 104–128), NACH dem Back-SizedBox (119–127), vor schliessendem `]),` (Zeile 128).
`BoxBottom` (132–136) bleibt ausserhalb des Expanded und unveraendert.

```dart
// nach dem l10n.back-TextButton (119-127):
const SizedBox(height: AppTheme.contentSpacing),
SizedBox(
  height: 50, width: double.infinity,
  child: OutlinedButton(
    onPressed: (cat == null || counts.total == 0) // D4
        ? null
        : () => Navigator.of(context).pushNamed('/progress_group', arguments: cat.id),
    child: Text(l10n.btnProgress, style: const TextStyle(fontSize: AppTheme.btnFontSize)),
  ),
),
```

**E1 – Null-Promotion belegt:** `cat` ist eine lokale `final`-Variable (`final cat = _category;`,
`category_screen.dart:92`). Im false-Zweig des `||`-Ternary (`cat == null || counts.total == 0`)
wird `cat` als non-null promoted; das im false-Zweig erzeugte Closure erbt die Promotion der `final`-Variable.
Isolierter Analyzer-Beleg: `/tmp/np_check.dart` mit identischer Struktur → `dart analyze` meldet
`No issues found!`. Alternativmuster (falls ein Refactor das bricht): lokale non-nullable Variable via Guard,
oder Helper-Methode, die eine non-nullable `WordCategory` erwartet:
```dart
// Alternativmuster (robust):
final cat = _category;
final enabled = cat != null && counts.total > 0;
SizedBox(height: 50, width: double.infinity, child: OutlinedButton(
  onPressed: !enabled ? null : () => Navigator.of(context)
      .pushNamed('/progress_group', arguments: cat!.id),
  ...
));
```
**Erster Frame:** `_counts` ist initial `null` → `counts.total == 0` → Button ist beim ersten Frame deaktiviert
und wird erst aktiv, nachdem `_refreshCounts()` (via `didChangeDependencies`) die Zaehler gesetzt hat
(`category_screen.dart:31-37`). Dieses Verhalten ist gewollt (D4) und muss im Test beruecksichtigt werden (pump + settle).

### T2 – Summary-Beschriftung (progress_group_screen.dart)
Einfuegestelle `:168` in `_summaryRow`: `l10n.catDueWords` → `l10n.catInProgressWords`. Zahlen bleiben Level-Partition (D6). Zeilendoc 20–21 („farbig = Level 1-7 (in Arbeit)") passt zur neuen Beschriftung.

### T3 – hartkodierten Titel ersetzen (progress_screen.dart) → OFFENE ENTSCHEIDUNG D10 (K2)
Einfuegestelle `:80`: `'Lernfortschritt'` → l10n-Text. **K2-Korrektur:** Der bisherige Hinweis „laut Ticket
beabsichtigt (Dopplung)" ist falsch. Das Ticket sagte nur „Layout unveraendert", nicht „Titel doppelt".
T3 wird daher als offene Entscheidung D10 gefuehrt (siehe Abschnitt 5), keine eigene Entscheidung durch mich.

## 5. Entscheidungsliste D1–D11 (Bewertung; Entscheidung trifft Hanspeter)

| # | Bewertung |
|---|-----------|
| D1 | ✅ sinnvoll; Learning/Collection unveraendert |
| D2 | ✅ `/progress_group` nimmt String-Id (session stringArgRoutes) |
| D3 | ✅ konsistent mit Scroll-Struktur, BoxBottom fix |
| D4 | ✅ verhindert leere Fortschrittsseite; `counts.total` vorhanden (`app_models.dart:589`) |
| D5 | ✅ einfach, kein neuer Key |
| D6 | ✅ fokussiert; F8 nur dokumentiert |
| D7 | ✅ aber ProgressScreen muss neu Provider lesen (E5) |
| D8 | ✅ Zielversion `1.12.0+24` (`1.11.0+23` vergeben, `pubspec.yaml:4`) |
| D9 | offen; Empfehlung JA (risikoarmer 1-Zeilen-Fix) |
| D10 | **T3-Text (K2):** a) `l10n.catSelect` als Zwischenueberschrift (Empfehlung des Pruefers; Key existiert: `learning_screen.dart:154`, `app_en.arb:30`, `app_de.arb:30`; kein neuer Key) – b) `l10n.titPageProgress` (Titel erscheint dann doppelt: BoxTitle `:66` + Zentrum) – c) 120-px-Block entfernen (Layoutaenderung). |
| D11 | rote Baseline: a) erst F11 in eigenem Ticket beheben, dann dieses Ticket gruen (Empfehlung des Pruefers) – b) parallel mit dokumentierten 5 bekannten Grammatik-Fehlern und pfadgenauen Commits |

## 6. Nebenbefunde

- **F5:** `courseLanguageName` liefert app-weit deutsche Namen unabhaengig vom UI-Locale – `language_registry.dart:170-180`. Nur dokumentiert.
- **F6:** `_langLabel` mappt `'greek'` nicht (Default-Zweig), zeigt rohen Key – `start_screen.dart:31-39`. Fix = T5, Entscheidung D9.
- **F7:** `_showCreateUser` nutzt `appLanguages.firstWhere((c) => c.code == code)` auf entdeckte Dict-Sprachen; bei kuenftigen it/pt-Dicts (nicht in `appLanguages`) → `StateError` – `start_screen.dart:98-104`. Nur dokumentieren.
- **F8:** Definitions-Differenz Level-Partition vs. status-/terminbasiert – `progress_group_screen.dart:102-104` vs. `vocab_queries.dart:220-258`. Nur dokumentieren (D6).
- **F9 (neu, E5):** `getUserStats` ohne `langCode` aggregiert ALLE Sprachen (`vocab_queries.dart:374-377`; Userbox `_UserInfoBox` ruft ohne langCode: `start_screen.dart:368`). Der Fortschritt (`/progress_group`) zeigt genau eine Sprache (via `resolveActiveLang`). **Zahlen duerfen daher abweichen** – kein Fix in diesem Ticket.
- **F10 (neu, K1):** `courseFlagAsset` (`language_registry.dart:183-184`):
  `_flagForCode[code] ?? appLanguages.first.flagAsset`. `appLanguages.first` ist `de` (Deutschland-Flagge,
  `language_registry.dart:34-39`), NICHT `'en'`. Der Code ist korrekt; der Doc-Kommentar in Zeile 182
  („{} → Standard-Fallback „en") ist falsch. **Kommentar-Fix nur mit ausdruecklicher Freigabe**, nicht eigenmaechtig.
- **F11 (neu, Grammatik still ausgefallen seit e05bcc3; alle 4 Punkte am Code belegt):**
  1. `grammar_manager.dart:19` `assetPath = 'assets/grammar/grammar_de_en.json'`; Level-Pfad Zeile 34-35
     `'assets/grammar/grammar_${key.toLowerCase()}_de_en.json'` → beide zeigen ins Leere (Dateien liegen in `grammar_de/`).
  2. `pubspec.yaml` deklariert nur `- assets/grammar/` (Asset-Liste, kein Unterordner). Flutter-Asset-Verzeichnisse
     sind nicht rekursiv → Dateien in `grammar_de/` werden nicht gebundelt.
  3. `FileService.loadBundledJson` faengt Fehler ab und liefert `{}` (`file_service.dart:377-391`); leeres
     `GrammarDocument` → `GrammarScreen` zeigt `l10n.grammarNoTopics` (`grammar_screen.dart:51-55`), nur Log, kein Crash.
  4. `FileServiceImpl.initialize` kopiert keine Grammatik-Assets – `file_service.dart:190-200` (`data_base`, `data_app`,
     `language_dict`); es gibt keinen Ersatzpfad.
  **Empfehlung: eigenes Ticket.** `assets/`, die pubspec-Assetliste, `grammar_manager.dart` und `grammar_test.dart`
  bleiben Tabuzone dieses Tickets.

## 7. Randbedingungen und Risiken (KORRIGIERT gem. K1)

- **Sprachkontext neuer Einstieg:** `/progress_group` loest die Sprache via `resolveActiveLang` auf
  (`progress_group_screen.dart:37-39`; NavigationState `navigation_state.dart:70-77`: activeLangCode → erste
  Vocab-Sprache → 'de'). Kein Umbau.
- **Session-Restore:** `/progress_group` ist restorable + String-Args (`session_manager.dart:63,71`); `activeCourseId`
  wird wiederhergestellt (`loading_screen.dart:87-99`). Keine Session-Aenderung. Regressionstest in Abschnitt 8 (E3).
- **loggedUName leer:** `_refreshCounts` bricht ab (`category_screen.dart:61-63`); Button sieht `counts.total==0` → disabled.
- **Kategorie ohne Woerter:** `getGroupWords` leer → `l10n.noWords` (`progress_group_screen.dart:81-83`); Button disabled.
- **Keine Seiteneffekte auf wordMode/selectedCategoryId:** T1 ruft KEINE `setWordMode`/`setSelectedCategoryId` auf.
- **Zaehler-Refresh nach Rueckprung:** `CategoryScreen.didPopNext` → `_refreshCounts` (`category_screen.dart:48-50`, RouteAware 38-44).
- **Layout 360 dp / Querformat:** Scroll-Spalte waechst um 50 px + Spacing; `SingleChildScrollView` scrollt,
  `BoxBottom` fix ausserhalb Expanded. Unkritisch (vertikal scrollbar).
- **Mehrsprachig (de/en/fr/es/el/ru):** Flagge via `courseFlagAsset`. **K1:** unbekannter Code → Fallback
  `appLanguages.first` = `de` = **Deutschland-Flagge** (nicht 'en'). Name via `courseLanguageName` (beachte F5: deutsch).
  `_flagForCode` enthaelt de/en/es/fr/ru/el/it/pt (`language_registry.dart:93-102`).
- **T3-Titel:** je nach D10-Option a/b/c unterschiedliches Layout; keine Dopplung ohne Freigabe.

## 8. Testplan (Stil `test/due_word_screen_test.dart` + `test/helpers/fakes.dart`)

Harness: `FakeFileService(store)`, `FakeUserManager.seed`, `FakeVocabManager`, `DataState.loadAppData`,
`MultiProvider` (DataState/NavigationState/UserState/VocabQueries), `MaterialApp` mit
`AppLocalizations.localizationsDelegates` + `supportedLocales` + `locale`; fuer Navigation eine `routes`-Map
(inkl. `/progress_group`) und/oder ein `NavigatorObserver`.

- **test/category_screen_test.dart (E2):**
  - **Schleife ueber alle 6 `courseWordCategories`** (`app_models.dart:525-562`): Button sichtbar und letztes Element.
  - **„Letztes Element" geometrisch:** `getBottom` des neuen Buttons > `getBottom` des Zurueck-`TextButton`
    (und Rueck-Button ist das unmittelbar davor liegende Element).
  - **disabled:** `tester.widget<OutlinedButton>(...).onPressed == null`, wenn `total == 0` oder Kategorie nicht aufloesbar.
  - **Navigation:** Tap → `/progress_group`; Argument via `ModalRoute.of(context).settings.arguments` asserten
    (= Kategorie-Id) und/oder `NavigatorObserver.didPush`.
  - **Keine Seiteneffekte:** `NavigationState.wordMode` und `.selectedCategoryId` unveraendert nach Tap.
  - **Zaehler-Refresh** nach Rueckprung via `didPopNext`/`routeObserver` (pump + settle).
  - **Erster Frame deaktiviert**, aktiv nach `_refreshCounts` (E1).
- **test/progress_group_screen_test.dart:** mittlere Summary-Spalte = „In Arbeit"/„In progress" (E4 pro Locale);
  Sprachanzeige korrekt (Flagge + `courseLanguageName`, z. B. el → „Griechisch"); read-only; `noWords` bei leerer Liste.
- **test/progress_screen_test.dart:** kein hartkodierter Titel – Locale `en` zeigt „Learning Progress"; Sprachanzeige korrekt.
- **test/session_manager_test.dart (E3):** Regressionstest Session-Restore: Stack `/category` → `/progress_group`
  wird persistiert und wiederhergestellt, inklusive Kategorie-Id (`arguments`) und `activeCourseId`.
- **Bei D9=ja:** el-Muttersprachen-Label = `l10n.greek` (nicht roher Key „greek").
- **E4 – l10n-Vollstaendigkeit:** `catInProgressWords` in JEDER `lib/l10n/app_*.arb` (aktuell 8: de/el/en/es/fr/it/pt/ru,
  belegt via `ls`), Template `app_en.arb`, generierte Klassen gemaess `l10n.yaml` aktualisiert (arb-dir `lib/l10n`,
  template `app_en.arb`, output `app_localizations.dart`, nullable-getter false), `flutter gen-l10n` ohne Warnungen.
  Test: pro unterstuetztem Locale liefert der Getter einen nicht-leeren, vom Key verschiedenen Text.
  Verbatim-Texte (vom Pruefer, wortgleich): de „In Arbeit", en „In progress", es „En curso", fr „En cours",
  ru „В работе", el „Σε εξέλιξη", it „In corso", pt „Em curso".

## 9. Baseline und Delta (KORRIGIERT gem. K3; E6)

**Baseline am tatsaechlichen HEAD (d74bb54), gemessen mit Flutter 3.47.9 / Dart 3.13.7:**

- **`flutter analyze` → `12 issues found` (alle info, 0 Errors/Warnings), Dauer ca. 164 s.** Einzelaufstellung
  (Regelname + Fundstelle):
  1. `avoid_redundant_argument_values` – `lib/managers/user_manager.dart:75:14`
  2. `use_build_context_synchronously` – `lib/screens/crossword_screen.dart:90:18`
  3. `use_build_context_synchronously` – `lib/screens/crossword_screen.dart:92:28`
  4. `use_build_context_synchronously` – `lib/screens/fill_in_screen.dart:98:18`
  5. `use_build_context_synchronously` – `lib/screens/fill_in_screen.dart:100:28`
  6. `use_build_context_synchronously` – `lib/screens/game_screen.dart:86:18`
  7. `use_build_context_synchronously` – `lib/screens/game_screen.dart:88:28`
  8. `no_leading_underscores_for_local_identifiers` – `test/course_language_test.dart:49:23`
  9. `avoid_redundant_argument_values` – `test/helpers/fakes.dart:170:14`
  10. `avoid_redundant_argument_values` – `test/loading_screen_test.dart:100:16`
  11. `avoid_redundant_argument_values` – `test/user_data_roundtrip_test.dart:59:16`
  12. `avoid_redundant_argument_values` – `test/user_manager_test.dart:17:14`

  Alle 12 sind rein info-level und **vorbestehend auf HEAD** (keine wird durch T1–T5 beruehrt).
- **CI:** `.github/workflows/ci.yml` fuehrt `flutter analyze` (Schritt „Analyze", Zeile 37) OHNE `--fatal-infos` aus
  → info-level macht CI nicht rot. Der Schritt „Test" (`flutter test`, Zeile 41) schlaegt jedoch aktuell fehl →
  **CI ist derzeit ROT wegen der 5 Grammatik-Fehler**, nicht wegen analyze-Infos.
- **`flutter test` → `209 passed, 5 failed` → „Some tests failed."** Die 5 Fehler liegen ausschliesslich in
  `test/grammar_test.dart` („GrammarDocument – echtes Asset"), alle mit `expected assets/grammar/grammar_de_en.json`.
  **K3:** Ursache ist NICHT der unsaubere Arbeitsbaum, sondern der seit e05bcc3 verschobene Pfad
  (`assets/grammar/grammar_de_en.json` existiert nicht mehr; Datei liegt in `grammar_de/`) – siehe Abschnitt 2 und F11.
- **Abnahmekriterien nach Umsetzung:** `flutter analyze` nicht hoeher als Baseline (12 info, 0 error);
  keine neuen Testfehler; bei D11b genau die 5 bekannten Grammatik-Fehler unveraendert. Gesamtzahlen vorher/nachher
  angeben. Erwartet bei D11a: analyze ≤ 12 info / 0 error, Tests gruen (209 ok / 0 fail, sobald F11 behoben ist).

## 10. Commit-Hygiene und Abschluss (E7)

- Nur explizite Ticket-Pfade stagen, **kein `git add -A`**, keine `assets/`, `tools/`, `language_dict/`,
  pubspec-Assetliste, `grammar_manager.dart`, `grammar_test.dart` (Tabuzone dieses Tickets).
- Commit-Messages im Repo-Stil (vgl. `git --no-pager log`).
- Version `1.12.0+24` NUR im letzten Umsetzungs-Commit (`pubspec.yaml:4`).
- Schlussbericht als `ACT_PROGRESS_CATEGORY_UMSETZUNG.md`.
- README-Aenderungen nur auf ausdruecklichen Wunsch.

## 11. Aufwandsschaetzung (Phase 2, nach Freigabe, inkl. Tests)

T1 0.5–1.0 h · T2 0.5–1.0 h · T3 (je D10) 0.25–0.5 h · T4 0.75–1.5 h · T5 0.25 h · l10n-Regeneration (E4)/Version/Commits 0.5 h
→ **ca. 3–4.5 h** (ohne F11, das ein eigenes Ticket ist).

## 12. Offene Punkte (Entscheidung Hanspeter)

1. **D1–D8** aus Abschnitt 5.
2. **D9** ja/nein fuer T5 (greek-Label).
3. **D10** T3-Text: a / b / c.
4. **D11** rote Baseline: a (erst F11 beheben) oder b (parallel mit dokumentierten 5 Fehlern).
5. **F10** Kommentar-Fix in `language_registry.dart:182` nur mit ausdruecklicher Freigabe.
6. **F11** Grammatik-Ausfall: eigenes Ticket.

**STOPP:** Keine Umsetzung von T1–T5 bis zur dokumentierten Freigabe.

## 13. Zielverfeinerung laut Hanspeter (Ergaenzung nach Phase 1b)

Hanspeter hat das Ziel praezisiert und in Phase 1b per Rueckfrage entschieden („alles in einem"):

- **Ziel (neu):** Jede Sprachkategorie hat eine eigene Fortschrittsanzeige, die im weiteren Verlauf
  **zusammenklappbar** sein soll (da weitere Woerter hinzukommen). Standardmässig zeigt sich pro Verb die
  Grundform; die Personen/Zeitformen werden per Klick auf den Verb-Kopf ein-/ausgeblendet.
- **Zusaetzliche Vorbereitung:** Eine **lokalisierte Ueberkategorie „Verben"** in der eingestellten App-Sprache
  (App-Locale = `DataState.currLang` → `appLocale`, `data_state.dart:37-45`, nicht die Kurs-/Lernsprache).
  Später kommen „Adjektive" als eigene Ueberkategorie auf **gleicher Ebene** wie „Verben" (neues Ticket) hinzu;
  die Struktur soll das ohne Umbau erlauben.

### Neue Arbeitspakete (zusaetzlich zu T1–T5)

**T6 – Zusammenklappbare Verben in `/progress_group` (progress_group_screen.dart):**
- Heute: `_buildList` (Z. 117–157) rendert pro Verb `_verbHeader` (Z. 186–199) und darunter sofort
  `_tenseHeader`/`_wordRow` (Z. 136–145, 201–227).
- Vorschlag: Zustand `final Set<String> _collapsed = {};` (initial leer → **alle aufgeklappt**, nichts geht verloren).
  `_verbHeader` erhaelt `onTap` (Toggle) + ein Hinweis-Icon (Chevron expand_less/expand_more).
  In `_buildList` nur dann Tenses/Zeilen rendern, wenn das Verb nicht collapsed ist.
- echte UI-Entscheidung (zur Bestaetigung): Chevron im Verb-Kopf ja/nein; Standard-Aufklappstatus = alles offen.

**T7 – Ueberkategorie „Verben" (lokalisierte Dach-Ebene):**
- Heute nur flach: `courseWordCollections` = [`erste_verben`, `weitere_verben`] (`app_models.dart:566-585`),
  durchlaufen in `learning_screen.dart:139-196`, `collection_screen.dart`, `progress_screen.dart`.
- Vorschlag: neue Dach-Datenebene (z. B. `courseTopCategories` mit id `verbs`, titleKey `catVerbs`, enthaelt
  beide Verb-Sammlungen). Titel über `l10n.catVerbs` in der App-Sprache. Später zweite Top-Kategorie
  `adjectives` auf gleicher Ebene. Minimale UI-Andockung: als Ueberschrift/aufklappbare Gruppe ueber den
  Verb-Sammlungen in `learning_screen.dart` + `progress_screen.dart`.
- **Neue l10n-Keys nötig** (z. B. `catVerbs`): erfordert verbindliche Uebersetzungen vom Pruefer -> sprengt
  die bisherige Randbedingung „keine neuen Keys ausser `catInProgressWords`" → ausdrueckliche Freigabe noetig.
  Ich uebernehme KEINE eigenen Uebersetzungen.

### Neue Entscheidungen (Vorschlaege mit Empfehlung, Hanspeter bestaetigt nur noch)

| # | Punkt | Vorschlag / Empfehlung |
|---|-------|------------------------|
| D12 | Standard-Aufklappstatus per Verb | alles offen (konservativ, kein Datenverlust) |
| D13 | Chevron-Icon im Verb-Kopf | ja (erkennbare Aufklappbarkeit) |
| D14 | Ueberkategorie „Verben" als eigene Ebene vorsehen | ja; `courseTopCategories` mit `catVerbs`; Adjektive docken später auf gleicher Ebene an |
| D15 | Neue l10n-Keys | ja (`catVerbs` u. a.); verbindliche Texte vom Pruefer, nicht von mir |
| D16 | App-Sprache fuer Ueberkategorie-Titel | App-Locale (`appLocale`), nicht Kurs-/Lernsprache |

Offen/zu bestaetigen: D9 (greek), D10 (T3-Text a/b/c), D11 (rote Baseline a/b), D12–D16. F10-Kommentar-Fix nur mit Freigabe. F11 eigenes Ticket.

### Auswirkung auf Testplan (Ergaenzung)
- **T6:** Test, dass Klick auf Verb-Kopf die Tenses-/Personenzeilen aus- und wieder einblendet (Geometrie/Found);
  Standardzustand aufgeklappt; Chevron-Icon vorhanden.
- **T7:** Test Ueberkategorie: Titel „Verben"/„Verbs" je App-Locale; Gruppe listet beide Verb-Sammlungen; spater `adjectives` auf gleicher Ebene (Struktur-Test auf `courseTopCategories`).

### Auswirkung auf Aufwandsschaetzung (Phase 2)
T1 0.5–1.0 h · T2 0.5–1.0 h · T3 (D10) 0.25–0.5 h · T4 0.75–1.5 h · T5 (D9) 0.25 h · **T6 (Foldable) 1.0–1.5 h** ·
**T7 (Ueberkategorie + l10n-Keys) 1.5–2.5 h** · l10n-Regeneration/Version/Commits 0.5 h → **ca. 5.5–9.25 h** total (ohne F11).

## 14. Beschlossene Entscheidungen (Freigabe Hanspeter, 23.11.2026) – FINAL

Alle offenen Punkte wurden von Hanspeter schrittweise entschieden:

| # | Punkt | Entscheidung (Hanspeter) |
|---|-------|--------------------------|
| D9 | greek-Muttersprachen-Label | **ja** – richtig anzeigen (statt „greek" → „Griechisch") |
| D10 | T3-Titel-Text | **c** – mittleren 120-px-Block in `progress_screen.dart` entfernen; nur obere Ueberschrift bleibt |
| D11 | Reihenfolge rote Baseline | **a** – zuerst F11 (Grammatik) in eigenem Ticket beheben, dann dieses Ticket auf gruener Basis |
| D12 | Standard-Aufklappstatus der Verben | **zugeklappt** (nur Verbnamen sichtbar) – platzsparend |
| D13 | Auf-/Zuklapp-Pfeil (Chevron) im Verb-Kopf | **ja** |
| D14 | Ueberkategorie „Verben" | **ja** – eigene Gruppe, unter der die beiden Verb-Sammlungen stehen; Adjektive spaeter als zweite Gruppe auf gleicher Ebene |
| D16 | Sprache des Ueberkategorie-Titels | **App-Sprache** (`appLocale`), nicht Kurs-/Lernsprache (implizit via D14) |
| D15 | Neue l10n-Keys | **akzeptiert** – z. B. `catVerbs` („Verben"/„Verbs"/…); verbindliche Uebersetzungen vom Pruefer anfordern, NICHT von mir erfinden |

Damit ist die Entscheidungsliste D1–D16 abgeschlossen und der Report dient als Freigabegrundlage fuer Phase 2.

**Noch offen / separat:** F11 (Grammatik-Fix) als eigenes Ticket – laut D11a zuerst umsetzen. Die Tabuzone dieses Tickets
(`assets/`, pubspec-Assetliste, `grammar_manager.dart`, `grammar_test.dart`) bleibt fuer das Fortschritts-Ticket unberuehrt.
