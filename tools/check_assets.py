#!/usr/bin/env python3
"""
check_assets.py

Konsistenz-Check zwischen pubspec.yaml-Asset-Deklaration und den tatsaechlich
vorhandenen Asset-Ordnern/-Dateien (AK aus Tickets #48 und #58).

Prueft beides:
  1. Rueckrichtung: Jede in pubspec.yaml deklarierte Asset-Zeile unter
     `flutter: assets:` muss existieren (Ordner mit trailing `/`, sonst Datei).
  2. Vorwaertsrichtung: (entfällt seit Ticket #68) – die Sprachdaten
     (language_dict/audio/grammar) sind NICHT mehr Teil des Bundles, sondern
     kommen ausschließlich über nachinstallierbare Sprachpakete. Es werden nur
     noch die nicht-Sprach-Assets (images/fonts/game_assets/data_base/data_app)
     geprüft; deren Vorwaertsrichtung ist nicht erforderlich.

So verhindert der Check, dass eine tote Deklaration (Ausserung auf ein nicht
vorhandenes Asset) ins Bundle-Leeren laufen: Assets, die beim Build nicht
gefunden werden, faellen bei Flutter mit einem Buildfehler.

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