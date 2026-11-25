#!/usr/bin/env python3
"""
check_assets.py

Konsistenz-Check zwischen pubspec.yaml-Asset-Deklaration und den tatsaechlich
vorhandenen Asset-Ordnern/-Dateien (AK aus Tickets #48 und #58).

Prueft beides:
  1. Rueckrichtung: Jede in pubspec.yaml deklarierte Asset-Zeile unter
     `flutter: assets:` muss existieren (Ordner mit trailing `/`, sonst Datei).
  2. Vorwaertsrichtung: Alle Wörterbuch-Dateien `language_dict/{code}/{code}_*.json`
     und alle Audio-Ordner `audio/{code}/verbs/{code}_audio_*` muessen in
     pubspec.yaml deklariert sein.

So verhindert der Check, dass z. B. eine neue Sprache oder ein neues Verb
(fachlich auf Platte vorhanden) das App-Bundle nicht erreicht, weil die
pubspec.yaml-Deklaration vergessen wurde – und dass tote Deklarationen
(Ausserungen auf nicht vorhandene Assets) ins Bundle-Leeren laufen (Assets,
die beim Build nicht gefunden werden, faellen bei Flutter mit einem Buildfehler).

Aufruf:
    python3 tools/check_assets.py            # normal, meldet Probleme mit Exit-Code
    python3 tools/check_assets.py --silent   # nur Exit-Code (fuer CI/Git-Hooks)

Exit-Code 0 = konsistent, 1 = Probleme gefunden.
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(REPO_ROOT, "pubspec.yaml")

ASSET_LINE_RE = re.compile(r"^\s*-\s+(assets/.+?)\s*$")


def parse_assets(pubspec_path: str) -> list[str]:
    """Liest die Asset-Liste aus dem `flutter: assets:`-Block der pubspec.yaml."""
    lines = open(pubspec_path, encoding="utf-8").read().splitlines()
    assets = []
    in_assets = False
    for line in lines:
        stripped = line.strip()
        if stripped == "assets:":
            in_assets = True
            continue
        if in_assets and (not stripped or stripped.startswith("#") or
                          re.match(r"^[A-Za-z]+:", stripped)):
            # Block-Ende: Folgeblock wie 'fonts:' beginnt mit key: (ohne '- ')
            if stripped != "assets:":
                in_assets = False
        if not in_assets:
            continue
        m = ASSET_LINE_RE.match(line)
        if m:
            assets.append(m.group(1).strip())
    return assets


def walk_dict_json() -> list[str]:
    """Alle language_dict-Dateien auf Platte (flaches Schema)."""
    root = os.path.join(REPO_ROOT, "assets", "language_dict")
    result = []
    if not os.path.isdir(root):
        return result
    for code in sorted(os.listdir(root)):
        code_dir = os.path.join(root, code)
        if not os.path.isdir(code_dir):
            continue
        for name in sorted(os.listdir(code_dir)):
            if name.endswith(".json") and name.startswith(f"{code}_"):
                result.append(os.path.join("assets", "language_dict", code))
    return result


def walk_audio_dirs() -> list[str]:
    """Alle Audio-Ordner unter audio/{code}/verbs/* (eine Deklaration je Ordner)."""
    root = os.path.join(REPO_ROOT, "assets", "audio")
    result = []
    if not os.path.isdir(root):
        return result
    for code in sorted(os.listdir(root)):
        verbs = os.path.join(root, code, "verbs")
        if not os.path.isdir(verbs):
            continue
        for name in sorted(os.listdir(verbs)):
            if name.startswith(f"{code}_audio_"):
                result.append(os.path.join("assets", "audio", code, "verbs", name))
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--silent", action="store_true",
                    help="Keine Meldungen, nur Exit-Code.")
    args = ap.parse_args()

    declared = parse_assets(PUBSPEC)
    problems: list[str] = []

    # 1) Deklaration existiert auf der Platte?
    for rel in declared:
        is_dir = rel.endswith("/")
        path = os.path.join(REPO_ROOT, *rel.strip("/").split("/"))
        if is_dir:
            if not os.path.isdir(path):
                problems.append(f"DEKLARIERT, aber Ordner fehlt: {rel}")
        else:
            if not os.path.isfile(path):
                problems.append(f"DEKLARIERT, aber Datei fehlt: {rel}")

    declared_dirs = {a for a in declared if a.endswith("/")}
    declared_plain = {a for a in declared if not a.endswith("/")}

    # 2) Vorwaerts: Wörterbuch-Ordner deklariert?
    for rel_dir in walk_dict_json():
        decl = f"{rel_dir}/"
        if decl not in declared_dirs:
            problems.append(f"DICT-ORDNER nicht in pubspec.yaml: {decl}")

    # 3) Vorwaerts: Audio-ordner deklariert?
    for rel_dir in walk_audio_dirs():
        decl = f"{rel_dir}/"
        if decl not in declared_dirs:
            problems.append(f"AUDIO-ORDNER nicht in pubspec.yaml: {decl}")

    # Sicherheitsnetz: tote Datei-Deklarationen (ohne trailing slash) sind nicht
    # Teil der Consultation, nur Ordner/Dateien. Keine weiteren Pruefungen.

    if not args.silent:
        if problems:
            print(f"{len(problems)} Problem(e) gefunden:")
            for p in problems:
                print(f"  - {p}")
        else:
            print(f"OK: {len(declared)} Asset-Zeile(n) konsistent.")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())