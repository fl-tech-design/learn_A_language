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

Validierung: je Stimme/Zeitform = 6, jede referenzierte Datei existiert;
fehlende/ueberzaehlige Dateien werden gemeldet.
"""

from __future__ import annotations

import json
import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG_DICT = os.path.join(PROJECT_ROOT, "assets", "language_dict")
AUDIO_ROOT = os.path.join(PROJECT_ROOT, "assets", "audio")
PERSON_COUNT = 6
TENSES = ("past", "present", "future")


def norm(phrase: str) -> str:
    """Normalisiert eine Konjugationsphrase zum Datei-Basisnamen-Teil."""
    p = phrase.strip().lower()
    out = re.sub(r"[^0-9a-zäöüßéèàç()]+", "_", p)
    out = re.sub(r"_+", "_", out).strip("_")
    return out


def voice_suffix(lang: str, voice: int, de_has_f: bool) -> str:
    """Stimmen-Kuerzel je Stimme (0/1).

    DE: Stimme 0 ist immer 'm'. Stimme 1 wird 'f', sobald _f-Dateien im Order
    liegen (de_has_f=True); bis dahin bleibt sie 'm', damit keine Luecken enstehen.
    EN: Stimme 0 = 'm', Stimme 1 = 'f' (beide Dateigeschlechter vorhanden).
    """
    if lang == "de":
        return "f" if (voice == 1 and de_has_f) else "m"
    return "m" if voice == 0 else "f"


def audio_subdir(lang: str, infinitive: str) -> str:
    if lang == "de":
        return os.path.join(AUDIO_ROOT, "de", "verben", infinitive)
    return os.path.join(AUDIO_ROOT, "en", infinitive)


def load_json(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path: str, data) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def process_language(lang: str, json_dir: str) -> None:
    json_files = sorted(p for p in os.listdir(json_dir) if p.endswith(".json"))
    total_missing = {"m": 0, "f": 0}
    orphans_acc = []

    for jfile in json_files:
        jpath = os.path.join(json_dir, jfile)
        data = load_json(jpath)
        infinitive = (data.get("infinitive") or "").strip()
        sub = audio_subdir(lang, infinitive)

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
        wanted: set[str] = set()
        for tense in TENSES:
            td = data.get(tense)
            if isinstance(td, dict):
                for i in range(PERSON_COUNT):
                    tr = (td.get("translations") or [])
                    if i < len(tr):
                        wanted.add(norm(tr[i]))
        for g in ("m", "f"):
            orphans = sorted(available[g] - wanted)
            if orphans:
                orphans_acc.append((lang, infinitive, g, orphans))

        save_json(jpath, data)
        total_missing["m"] += lang_missing["m"]
        total_missing["f"] += lang_missing["f"]
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

    return 1 if (lang == "de" and total_missing["m"] > 0) else 0


def main() -> int:
    rc = 0
    for lang in ("de", "en"):
        rc |= process_language(lang, os.path.join(LANG_DICT, lang))
    print("\nFertig.")
    return rc


if __name__ == "__main__":
    sys.exit(main())