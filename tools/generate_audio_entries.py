#!/usr/bin/env python3
"""
generate_audio_entries.py

Schreibt fuer jede Verb-JSON (de_/en_) den neuen `audio`-Block pro Zeitform:

    "audio": [
        [ "…_m.mp3", "…", "…", "…", "…", "…" ],   # Index 0 = Stimme 0 (m)
        [ "…_f.mp3", "…", "…", "…", "…", "…" ]    # Index 1 = Stimme 1 (f)
    ]

Jede innere Liste hat GENAU 6 Eintraege in Konjugationsreihenfolge
(Index 0..5 = ich, du, er/sie/es, wir, ihr, sie) – identisch zu `translations`.

Zuordnung: Eine `translation` wird normalisiert (lowercase, `/` und Leerzeichen
-> `_`, Klammern bleiben, z. B. "he/she/it works" -> "he_she_it_works") und als
`audio_<normalisiert>_<g>.mp3` im Audio-Unterordner des Verbs gesucht.

DE: Sind noch keine `_f`-Dateien da, werden beide Stimmen-Listen mit `_m`-Pfaden
gefuellt (keine Fehler beim Abspielen). Sobald die deutschen `_f`-Audios
nachgeliefert sind, erkennt das Skript das automatisch und befuellt Stimme 1
mit den `_f`-Pfaden (einfach neu ausfuehren).
EN: Beide Stimmen (`_m` + `_f`) existieren und werden getragen.

FR: Es gibt nur `_f`-Audios (keine `_m`). Stimme 0 (m) bleibt deshalb BEWUSST
leer, damit der bestehende audio_service-Fallback (leere Stimme -> andere
Stimme) automatisch die `_f`-Stimme abspielt. Stimme 1 (f) erhaelt den Pfad
`audio/fr/<fr_verb_ordner>/audio_<fr_konjugation_normalisiert>_f.mp3`.
Die Zuordnung JSON-Dateiname -> fr-Audio-Ordner ist eine explizite Konfig-
Tabelle ([FR_JSON_TO_AUDIO_DIR]); die Normalisierung ([norm_fr]) wurde aus den
real existierenden Dateinamen abgeleitet (Apostroph-Elision `j'ai` -> `jai`,
Akzent-Ersetzung `e^tre`-Formen, `/` und Leerzeichen -> `_`).

Validierung: je Stimme/Zeitform = 6, jede referenzierte Datei existiert;
fehlende/ueberzaehlige Dateien werden gemeldet. Bei FR wird zusaetzlich nach
dem Schreiben jeder generierte f-Pfad gegen das Dateisystem geprueft
(NICHT blind schreiben: fehlende Dateien werden geloggt, der Eintrag bleibt leer).

Aufruf:
    python generate_audio_entries.py                    # de, en und fr
    python generate_audio_entries.py --lang fr          # nur fr
    python generate_audio_entries.py --lang fr --only fr_to_be.json  # Stichprobe
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG_DICT = os.path.join(PROJECT_ROOT, "assets", "language_dict")
AUDIO_ROOT = os.path.join(PROJECT_ROOT, "assets", "audio")
PERSON_COUNT = 6
TENSES = ("past", "present", "future")

# ── FR: Explizite Zuordnung JSON-Dateiname -> fr-Audio-Ordner. ────────────────
# Diese 30er-Tabelle ist die dokumentierte Konfiguration (KEINE Improvisation):
# Der Ordner ist der franzoesische Verbbegriff, der zum JSON-Dateinamen passt
# (fr_to_be.json -> être, fr_to_have.json -> avoir, ...). Achtung: fr_to_must
# UND fr_to_should zeigen beide auf 'devoir' (das Franzoesische deckt "muessen"
# und "sollen" mit demselben Verb ab) – deshalb 30 JSONs auf 29 Audio-Ordner.
FR_JSON_TO_AUDIO_DIR = {
    "fr_to_be.json": "être",
    "fr_to_be_allowed_to.json": "avoir le droit de",
    "fr_to_begin.json": "commencer",
    "fr_to_buy.json": "acheter",
    "fr_to_can.json": "pouvoir",
    "fr_to_close.json": "fermer",
    "fr_to_come.json": "venir",
    "fr_to_drink.json": "boire",
    "fr_to_eat.json": "manger",
    "fr_to_end.json": "terminer",
    "fr_to_find.json": "trouver",
    "fr_to_go.json": "aller",
    "fr_to_have.json": "avoir",
    "fr_to_help.json": "aider",
    "fr_to_learn.json": "apprendre",
    "fr_to_like.json": "aimer",
    "fr_to_live.json": "habiter",
    "fr_to_make.json": "faire",
    "fr_to_must.json": "devoir",
    "fr_to_need.json": "avoir besoin",
    "fr_to_open.json": "ouvrir",
    "fr_to_read.json": "lire",
    "fr_to_see.json": "voir",
    "fr_to_sell.json": "vendre",
    "fr_to_should.json": "devoir",
    "fr_to_speak.json": "parler",
    "fr_to_understand.json": "comprendre",
    "fr_to_want.json": "vouloir",
    "fr_to_work.json": "travailler",
    "fr_to_write.json": "écrire",
}

# FR: Akzent-Ersetzung (aus den realen Dateinamen abgeleitet: êtes -> etes,
# étaient -> etaient, écrire -> ecrire, fermâmes -> fermames, commençons ->
# commencons ...).
FR_ACCENT_MAP = {
    "à": "a", "á": "a", "â": "a", "ä": "a", "ã": "a", "å": "a", "ā": "a",
    "è": "e", "é": "e", "ê": "e", "ë": "e", "ē": "e", "ė": "e", "ę": "e",
    "ì": "i", "í": "i", "î": "i", "ï": "i", "ī": "i", "į": "i",
    "ò": "o", "ó": "o", "ô": "o", "ö": "o", "õ": "o", "ō": "o",
    "ù": "u", "ú": "u", "û": "u", "ü": "u", "ū": "u", "ů": "u",
    "ñ": "n", "ç": "c", "ć": "c", "č": "c",
    "ž": "z", "ź": "z", "ż": "z", "š": "s", "ś": "s",
    "ł": "l", "ø": "o", "æ": "ae", "œ": "oe",
}


def norm(phrase: str) -> str:
    """Normalisiert eine Konjugationsphrase zum Datei-Basisnamen-Teil."""
    p = phrase.strip().lower()
    out = re.sub(r"[^0-9a-zäöüßéèàç()]+", "_", p)
    out = re.sub(r"_+", "_", out).strip("_")
    return out


def norm_fr(phrase: str) -> str:
    """FR-spezifische Normalisierung, abgeleitet aus den realen Dateinamen:

    - lowercase
    - Apostroph-Elision wird ENTFERNT (kein '_'):  "j'ai"     -> "jai",
      "j'étais" -> "jetais"
    - Akzente werden ERSETZT (nicht entfernt):    "êtes"     -> "etes",
      "étaient" -> "etaient", "écrire" -> "ecrire", "commençons" -> "commencons"
    - `/` und Leerzeichen (sowie alles andere) -> "_"

    Beispiele aus echten Dateien:
      "je suis"           -> "je_suis"           (audio_je_suis_f.mp3)
      "il/elle/on est"    -> "il_elle_on_est"    (audio_il_elle_on_est_f.mp3)
      "ils/elles étaient" -> "ils_elles_etaient" (audio_ils_elles_etaient_f.mp3)
    """
    p = phrase.strip().lower().replace("'", "").replace("\u2019", "")
    p = "".join(FR_ACCENT_MAP.get(ch, ch) for ch in p)
    out = re.sub(r"[^0-9a-z]+", "_", p)
    return out.strip("_")


def voice_suffix(lang: str, voice: int, de_has_f: bool) -> str:
    """Stimmen-Kuerzel je Stimme (0/1).

    DE: Stimme 0 ist immer 'm'. Stimme 1 wird 'f', sobald _f-Dateien im Order
    liegen (de_has_f=True); bis dahin bleibt sie 'm', damit keine Luecken enstehen.
    EN: Stimme 0 = 'm', Stimme 1 = 'f' (beide Dateigeschlechter vorhanden).
    """
    if lang == "de":
        return "f" if (voice == 1 and de_has_f) else "m"
    return "m" if voice == 0 else "f"


def audio_subdir(lang: str, infinitive: str, jfile: str = "") -> str:
    """Audio-Unterordner je Sprache.

    FR nutzt die explizite Zuordnung JSON-Dateiname -> fr-Ordner
    ([FR_JSON_TO_AUDIO_DIR]); unbekannte Dateien fallen auf den Infinitiv zurueck.
    """
    if lang == "de":
        return os.path.join(AUDIO_ROOT, "de", "verben", infinitive)
    if lang == "fr":
        return os.path.join(AUDIO_ROOT, "fr", FR_JSON_TO_AUDIO_DIR.get(jfile, infinitive))
    return os.path.join(AUDIO_ROOT, "en", infinitive)


def load_json(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path: str, data) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def process_language(lang: str, json_dir: str,
                     only_file: str | None = None) -> int:
    json_files = sorted(p for p in os.listdir(json_dir) if p.endswith(".json"))
    if only_file:
        if only_file in json_files:
            json_files = [only_file]
        else:
            print(f"[{lang}] {only_file} nicht gefunden – übersprungen.")
            return 0
    total_missing = {"m": 0, "f": 0}
    orphans_acc = []
    write_missing: list[str] = []

    for jfile in json_files:
        jpath = os.path.join(json_dir, jfile)
        data = load_json(jpath)
        infinitive = (data.get("infinitive") or "").strip()
        sub = audio_subdir(lang, infinitive, jfile)
        subdir_name = os.path.basename(sub)

        if lang == "fr" and not os.path.isdir(sub):
            print(f"  [WARN] {jfile}: Audio-Ordner {sub!r} nicht gefunden – "
                  "alle f-Eintraege bleiben leer.")

        # Verfuegbare Basenamen je Stimme im Audio-Ordner.
        available: dict[str, set[str]] = {"m": set(), "f": set()}
        if os.path.isdir(sub):
            for fn in os.listdir(sub):
                m = re.match(r"^audio_(.+)\.mp3$", fn)
                if not m:
                    continue
                base = m.group(1)
                if base.endswith("_f"):
                    base = base[:-2]
                    g = "f"
                elif base.endswith("_m"):
                    base = base[:-2]
                    g = "m"
                else:
                    g = "m"
                available[g].add(base)

        lang_missing = {"m": 0, "f": 0}
        de_has_f = lang == "de" and bool(available["f"])
        for tense in TENSES:
            tense_data = data.get(tense)
            if not isinstance(tense_data, dict):
                continue
            translations = tense_data.get("translations") or []
            lists = [[], []]

            if lang == "fr":
                # ── FR: Stimme 0 (m) bleibt BEWUSST leer. Der bestehende
                # audio_service-Fallback (leere Stimme -> andere Stimme)
                # spielt dann automatisch die `_f`-Stimme ab. ──
                for i in range(PERSON_COUNT):
                    phrase = translations[i] if i < len(translations) else ""
                    base_fr = norm_fr(phrase) if phrase else ""
                    if base_fr and base_fr in available["f"]:
                        lists[1].append("audio/fr/%s/audio_%s_f.mp3"
                                        % (subdir_name, base_fr))
                    else:
                        lists[1].append("")
                        lang_missing["f"] += 1
                    lists[0].append("")
                tense_data["audio"] = lists
                continue

            # ── de/en (bestehende Logik, unveraendert) ──
            for i in range(PERSON_COUNT):
                phrase = translations[i] if i < len(translations) else ""
                base = norm(phrase) if phrase else ""
                for voice in (0, 1):
                    g = voice_suffix(lang, voice, de_has_f)
                    if base and base in available[g]:
                        rel = ("audio/%s/%s/%s/audio_%s_%s.mp3"
                               % (lang, "verben" if lang == "de" else "",
                                  infinitive, base, g))
                        rel = re.sub(r"/+", "/", rel)
                        lists[voice].append(rel)
                    else:
                        lists[voice].append("")
                        lang_missing[g] += 1
            tense_data["audio"] = lists

        # Ueberzaehlige Dateien (keiner Translation zugeordnet) melden.
        norm_func = norm_fr if lang == "fr" else norm
        wanted: set[str] = set()
        for tense in TENSES:
            td = data.get(tense)
            if isinstance(td, dict):
                for i in range(PERSON_COUNT):
                    tr = (td.get("translations") or [])
                    if i < len(tr):
                        wanted.add(norm_func(tr[i]))
        for g in ("m", "f"):
            orphans = sorted(available[g] - wanted)
            if orphans:
                orphans_acc.append((lang, infinitive, g, orphans))

        save_json(jpath, data)

        # Verifikation (fr): jeder geschriebene f-Pfad muss als Datei
        # existieren. Falls nicht: loggen statt blind schreiben.
        if lang == "fr":
            for tense in TENSES:
                td = data.get(tense)
                if not isinstance(td, dict):
                    continue
                audio_lists = td.get("audio") or []
                if not isinstance(audio_lists, list) or len(audio_lists) < 2:
                    continue
                for i, rel in enumerate(audio_lists[1]):
                    if not rel:
                        continue
                    # JSON-Pfade sind assets-relativ (audioplayers ergaenzt
                    # 'assets/'); reale Datei liegt unter assets/.
                    real = os.path.join(PROJECT_ROOT, "assets", rel)
                    if not os.path.isfile(real):
                        write_missing.append(
                            f"[{jfile}] {tense}[{i}]: {rel} existiert NICHT")

        total_missing["m"] += lang_missing["m"]
        total_missing["f"] += lang_missing["f"]
        if lang == "fr":
            status = "OK" if lang_missing["f"] == 0 else "MISSING"
        else:
            status = "OK" if lang_missing["m"] == 0 else "MISSING"
        print(f"[{lang}] {jfile:32s} infinitive={infinitive!r:24s} "
              f"m-missing={lang_missing['m']} f-missing={lang_missing['f']} "
              f"({status})")

    print(f"\n[{lang}] Gesamt  m-missing={total_missing['m']}  "
          f"f-missing={total_missing['f']}  (Personen je Stimme)")
    for lang_, inf_, g_, orph in orphans_acc:
        print(f"  [{lang_}] {inf_!r}/{g_}: nicht zugeordnet -> {orph}")
    if orphans_acc:
        print(f"  [{lang}] Hinweis: {len(orphans_acc)} Verben mit "
              "nicht zugeordneten Audiodateien (bitte pruefen).")
    for line in write_missing:
        print(f"  [FEHLT] {line}")
    if write_missing:
        print(f"  [{lang}] Fehlende f-Pfade: {len(write_missing)} – "
              "Eintraege bleiben leer (kein blindes Schreiben).")

    return 1 if (lang == "de" and total_missing["m"] > 0) else (
        1 if (lang == "fr" and
              (total_missing["f"] > 0 or bool(write_missing))) else 0)


def main() -> int:
    p = argparse.ArgumentParser(
        description="Audio-Eintraege fuer Verb-JSONs generieren (de/en/fr).")
    p.add_argument("--lang", nargs="*", choices=["de", "en", "fr"],
                   default=["de", "en", "fr"],
                   help="Sprachen (Standard: alle drei)")
    p.add_argument("--only", default=None,
                   help="Nur diese JSON-Datei verarbeiten (z. B. fr_to_be.json)")
    args = p.parse_args()

    rc = 0
    for lang in args.lang:
        jdir = os.path.join(LANG_DICT, lang)
        if not os.path.isdir(jdir):
            print(f"[{lang}] Verzeichnis fehlt: {jdir} – übersprungen.")
            continue
        rc |= process_language(lang, jdir, only_file=args.only)
    print("\nFertig.")
    return rc


if __name__ == "__main__":
    sys.exit(main())