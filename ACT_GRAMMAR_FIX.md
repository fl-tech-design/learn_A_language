# ACT_GRAMMAR_FIX – Grammatik-Assets (F11) beheben

- **Datum:** 23.11.2026
- **Basis-Commit:** `d74bb54` = `d74bb5430f844049842bcb003d198e7b4ef0f575`
- **Status:** umgesetzt + verifiziert (eigenes Vorhaben, zuerst laut D11a von Hanspeter freigegeben)

## Befund F11 (aus ACT_PROGRESS_CATEGORY.md, Abschnitt 6)
Die Grammatik war seit e05bcc3 still ausgefallen: Die Asset-Dateien wurden in den Unterordner
`assets/grammar/grammar_de/` verschoben, aber Code, Test und pubspec zeigten weiter auf die alten Pfade.

- `GrammarManagerImpl.assetPath` und Level-Pfad zeigten auf `assets/grammar/grammar_de_en.json`
  bzw. `assets/grammar/grammar_<level>_de_en.json` (existieren nicht mehr).
- `test/grammar_test.dart._realDoc` las `File('assets/grammar/grammar_de_en.json')` (fehlt) → 5 Testfehler.
- `pubspec.yaml` deklarierte nur `assets/grammar/` (nicht rekursiv) → `grammar_de/` wurde nicht gebuendelt.

## Aenderungen (pfadgenaue, minimal)
| Datei | Aenderung |
|-------|-----------|
| `lib/managers/grammar_manager.dart` | `assetPath` + Level-Pfad + Doc-Kommentar auf `assets/grammar/grammar_de/...` korrigiert |
| `lib/models/grammar_models.dart` | Doc-Kommentar auf `assets/grammar/grammar_de/grammar_de_en.json` korrigiert |
| `test/grammar_test.dart` | `_realDoc()`-Pfad auf `assets/grammar/grammar_de/grammar_de_en.json` korrigiert |
| `pubspec.yaml` | Asset-Eintrag `assets/grammar/` → `assets/grammar/grammar_de/` |

## Verifikation
- `flutter test`: **214 passed, 0 failed** (vorher 209 ✓ / 5 ✗) – „All tests passed!".
- `flutter analyze`: **12 info, 0 errors** – identisch mit Baseline, keine neuen Issues.

## Hinweis / naechster Schritt
Dieser Fix ist ein eigenes Vorhaben und gehoert NICHT in den Commit des Fortschritts-Tickets (Tabuzone).
Fuer diesen Fix ist ein separater, pfadgenauer Commit vorgesehen (nur die 4 oben genannten Dateien).
