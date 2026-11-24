#!/usr/bin/env python3
"""Benennt die Audio-Ordner auf den Stil '<lang>_audio_<verbKey>' um.

Ziel-Layout (passend zu den Wort-Dateien '<lang>_to_<verbKey>.json'):
    assets/audio/de/verbs/sein/   -> assets/audio/de/verbs/de_audio_to_be/
    assets/audio/fr/verbs/etre/   -> assets/audio/fr/verbs/fr_audio_to_be/
    assets/audio/el/verben/eimai/ -> assets/audio/el/verbs/el_audio_to_be/

Regeln:
  * Der Zielname wird aus dem JSON-Dateinamen abgeleitet (verbKey):
    de_to_be.json -> de_audio_to_be
  * Der Zwischenordner wird ueberall auf 'verbs' vereinheitlicht.
  * Dateien und Dateinamen bleiben unveraendert (nur Ordnerpfad).
  * Sonderfall 'mehrere Wortfiles -> gleicher Audio-Ordner'
    (z. B. es/verbs/poder fuer es_to_can + es_to_be_allowed_to):
    Die Dateien werden in JEDEN Zielordner kopiert (doppelte Ausgabe gewollt),
    danach wird der Quell-Ordner entfernt. Es geht nichts verloren.

Zusaetzlich:
  - Alle 'audio'-Pfade in den language_dict-JSONs werden entsprechend
    umgeschrieben (nur der Ordneranteil, Dateinamen bleiben).
  - Optional: pubspec.yaml-Assetliste regenerieren (Option --pubspec).

Aufruf:
    python tools/rename_audio_folders.py            # Dry-Run
    python tools/rename_audio_folders.py --execute  # wirklich umbenennen
    python tools/rename_audio_folders.py --execute --pubspec
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AUDIO_ROOT = REPO_ROOT / "assets" / "audio"
DICT_ROOT = REPO_ROOT / "assets" / "language_dict"
PUBSPEC = REPO_ROOT / "pubspec.yaml"

VERB_KEY_RE = re.compile(r"^[a-z]{2}_(?P<verbKey>to_.+)\.json$")


def load_json(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def audio_src_dir(lang: str, verbKey: str) -> Path:
    """Aktueller Audio-Ordner einer Wort-Datei.

    Bevorzugt wird der tatsaechlich in der JSON referenzierte Ordner
    (robust gegen Schreibvarianten wie 'to be', Akzente). Fallback:
    Kategorie + Infinitiv.
    """
    jpath = DICT_ROOT / lang / f"{lang}_{verbKey}.json"
    data = load_json(jpath)
    src = None
    for tense in ("past", "present", "future"):
        td = data.get(tense) or {}
        for voices in td.get("audio") or []:
            if not isinstance(voices, list):
                continue
            for p in voices:
                if isinstance(p, str) and p.startswith("audio/"):
                    seg = p.split("/")
                    if len(seg) >= 4:
                        src = seg[1:4]  # [lang, kategorie, verb]
                        break
                if src:
                    break
            if src:
                break
        if src:
            break

    kategorie = "verbs"
    if src:
        kategorie, verb_name = src[1], src[2]
    else:
        verb_name = str(data.get("infinitive") or "").strip()
        if not verb_name:
            return AUDIO_ROOT / lang / "verbs" / verbKey
        if ((AUDIO_ROOT / lang / "verbs" / verb_name).exists() or
                (AUDIO_ROOT / lang / "verben" / verb_name).exists()):
            if (AUDIO_ROOT / lang / "verben" / verb_name).exists() and not (
                    AUDIO_ROOT / lang / "verbs" / verb_name).exists():
                kategorie = "verben"
    return AUDIO_ROOT / lang / kategorie / verb_name


def audio_dst_dir(lang: str, verbKey: str) -> Path:
    return AUDIO_ROOT / lang / "verbs" / f"{lang}_audio_{verbKey}"


def old_prefix(src_dir: Path) -> str:
    rel = src_dir.relative_to(REPO_ROOT / "assets").as_posix()
    return f"{rel}/"  # z. B. "audio/de/verbs/sein/"


def new_prefix(dst_dir: Path) -> str:
    rel = dst_dir.relative_to(REPO_ROOT / "assets").as_posix()
    return f"{rel}/"  # z. B. "audio/de/verbs/de_audio_to_be/"


def rewrite_audio_paths(data, old_pref: str, new_pref: str,
                        changed: list[str]) -> None:
    """Ersetzt rekursiv alle 'audio/...' Pfade mit old_pref durch new_pref."""
    if isinstance(data, dict):
        for k, v in data.items():
            if k == "audio" and isinstance(v, list):
                for i, row in enumerate(v):
                    if isinstance(row, list):
                        for j, p in enumerate(row):
                            if isinstance(p, str) and p.startswith(old_pref):
                                fname = Path(p).name
                                row[j] = f"{new_pref}{fname}"
                                changed.append(p)
                    elif isinstance(row, str) and row.startswith(old_pref):
                        fname = Path(row).name
                        v[i] = f"{new_pref}{fname}"
                        changed.append(row)
            else:
                rewrite_audio_paths(v, old_pref, new_pref, changed)
    elif isinstance(data, list):
        for item in data:
            rewrite_audio_paths(item, old_pref, new_pref, changed)


def collect_plans():
    """Sammelt pro (lang, verbKey) Quell- und Zielordner."""
    plans = []
    for lang_dir in sorted(DICT_ROOT.iterdir()):
        if not lang_dir.is_dir():
            continue
        lang = lang_dir.name
        for jpath in sorted(lang_dir.glob(f"{lang}_*.json")):
            m = VERB_KEY_RE.match(jpath.name)
            if not m:
                continue
            verbKey = m.group("verbKey")
            plans.append((lang, verbKey,
                          audio_src_dir(lang, verbKey),
                          audio_dst_dir(lang, verbKey)))
    return plans


def move_or_copy(lang: str, verbKey: str, src: Path, dst: Path,
                 dry_run: bool) -> None:
    """Bewegt den Quell-Ordner zum Ziel.

    Bei MULTI-Gruppen (eine Quelle -> mehrere Ziele) darf die Quelle nur
    KOPIERT werden; Loeschen uebernimmt danach `cleanup_src`.
    """
    if src == dst:
        return
    if not src.is_dir():
        print(f"  [WARN] Quelle fehlt: {src.relative_to(REPO_ROOT)}")
        return

    if dry_run:
        print(f"    {src.relative_to(REPO_ROOT)}  ->  "
              f"{dst.relative_to(REPO_ROOT)}")
        return

    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.resolve() != src.resolve():
        copy_src_to_dst(src, dst)
        cleanup_src(src)
        return
    src.rename(dst)
    print(f"    [move] {src.name} -> {dst.name}")


def copy_src_to_dst(src: Path, dst: Path) -> None:
    """Kopiert den Inhalt von src nach dst (nie ueberschreiben)."""
    dst.mkdir(parents=True, exist_ok=True)
    for item in src.iterdir():
        if item.is_dir():
            continue  # nur Audio-Dateien
        target = dst / item.name
        if not target.exists():
            shutil.copy2(item, target)
    print(f"    [copy] {src.name} -> {dst.name}")


def cleanup_src(src: Path) -> None:
    if src.is_dir():
        shutil.rmtree(src)
        print(f"    [moved] {src.relative_to(REPO_ROOT)} entfernt (leer)")


def update_json_paths(lang: str, verbKey: str, src: Path, dst: Path,
                      dry_run: bool) -> None:
    if src == dst:
        return
    jpath = DICT_ROOT / lang / f"{lang}_{verbKey}.json"
    data = load_json(jpath)
    op, np_ = old_prefix(src), new_prefix(dst)
    changed: list[str] = []
    rewrite_audio_paths(data, op, np_, changed)
    if changed:
        print(f"    JSON {jpath.name}: {len(changed)} Pfad(e)")
    if changed and not dry_run:
        save_json(jpath, data)


def build_pubspec_audio_paths() -> list[str]:
    """Erzeugt die neuen Asset-Zeilen fuer den Audio-Bereich."""
    lines = []
    for lang_dir in sorted(AUDIO_ROOT.iterdir()):
        if not lang_dir.is_dir():
            continue
        verbs_dir = lang_dir / "verbs"
        if not verbs_dir.is_dir():
            continue
        for d in sorted(verbs_dir.iterdir()):
            if d.is_dir():
                lines.append(f"    - {d.relative_to(REPO_ROOT).as_posix()}/")
    return lines


def update_pubspec(dry_run: bool) -> None:
    if not PUBSPEC.exists():
        print("  [SKIP] pubspec.yaml nicht gefunden.")
        return
    old: list[str] = []
    new = build_pubspec_audio_paths()
    with open(PUBSPEC, encoding="utf-8") as f:
        lines = f.readlines()

    out: list[str] = []
    in_audio = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("- assets/audio/"):
            in_audio = True
            old.append(stripped)
            continue  # alte Zeile entfernen
        if in_audio and not stripped.startswith("- assets/audio/"):
            # Audio-Block endet -> neue Liste hier einfuegen
            for nl in new:
                out.append(nl + "\n")
            in_audio = False
        out.append(line)
    if in_audio:
        for nl in new:
            out.append(nl + "\n")

    if dry_run:
        print(f"  pubspec: {len(old)} alte -> {len(new)} neue Audio-Zeilen")
    else:
        with open(PUBSPEC, "w", encoding="utf-8") as f:
            f.writelines(out)
        print(f"  pubspec.yaml: {len(old)} alte -> {len(new)} neue Audio-Zeilen")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Audio-Ordner auf '<lang>_audio_<verbKey>' umbenennen.")
    ap.add_argument("--execute", action="store_true",
                    help="Wirklich umbenennen (ohne: Dry-Run).")
    ap.add_argument("--pubspec", action="store_true",
                    help="Zusaetzlich pubspec.yaml-Assetliste aktualisieren.")
    args = ap.parse_args()

    dry_run = not args.execute
    plans = collect_plans()
    print(f"{len(plans)} Wort-Dateien gefunden.\n")

    # Aufdopplung: gleiche Quelle -> mehrere Ziele (Sonderfall).
    by_src: dict[str, list[tuple[str, str, Path, Path]]] = defaultdict(list)
    for lang, verbKey, src, dst in plans:
        by_src[str(src)].append((lang, verbKey, src, dst))

    for key in sorted(by_src):
        group = sorted(by_src[key])
        langs = {g[0] for g in group}
        label = "[MULTI] " if len(group) > 1 else ""
        print(f"{label}{sorted(langs)[0]}:" if len(langs) == 1
              else f"[WARN] {sorted(langs)} -> {key}")

        for lang, verbKey, src, dst in group:
            update_json_paths(lang, verbKey, src, dst, dry_run)

        if len(group) > 1:
            # Sonderfall: eine Quelle -> mehrere Ziele. Erst alle kopieren,
            # danach die Quelle entfernen.
            for lang, verbKey, src, dst in group:
                if dry_run:
                    move_or_copy(lang, verbKey, src, dst, dry_run=True)
                else:
                    copy_src_to_dst(src, dst)
            if not dry_run:
                cleanup_src(group[0][2])
        else:
            lang, verbKey, src, dst = group[0]
            move_or_copy(lang, verbKey, src, dst, dry_run)

    if args.pubspec:
        print()
        update_pubspec(dry_run)

    print()
    if dry_run:
        print("DRY-RUN beendet – nichts wurde veraendert.")
        print("Zum Ausfuehren: python tools/rename_audio_folders.py --execute")
    else:
        print("Fertig.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
