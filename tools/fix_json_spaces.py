#!/usr/bin/env python3
"""
Entfernt Leerzeichen/Tabs direkt vor schließenden Anführungszeichen in JSON-Dateien.
Betrifft sowohl Werte als auch Keys.

Beispiele:
    "infinitive "       -> "infinitive"
    "avoir le droit "   -> "avoir le droit"
    " "                 -> ""

Verwendung:
    python fix_json_spaces.py ORDNER                    # ändert, legt .bak an
    python fix_json_spaces.py ORDNER --dry              # nur anzeigen
    python fix_json_spaces.py ORDNER --dry --report     # mit Zeilen-Details
    python fix_json_spaces.py ORDNER -r --ext .txt      # rekursiv, auch .txt
"""
import re
import sys
import shutil
import json
import argparse
from pathlib import Path

PATTERN = re.compile(r'"((?:[^"\\]|\\.)*?)[ \t]+"')


def parse_args():
    p = argparse.ArgumentParser(description="Trailing-Leerzeichen aus JSON-Strings entfernen.")
    p.add_argument("folder", nargs="?", default=".")
    p.add_argument("--dry", "-n", action="store_true", help="nur anzeigen, nichts ändern")
    p.add_argument("--no-backup", action="store_true", help="keine .bak-Dateien anlegen")
    p.add_argument("--recursive", "-r", action="store_true", help="auch Unterordner durchsuchen")
    p.add_argument("--ext", default=".json", help="Dateiendung (Standard: .json)")
    p.add_argument("--report", action="store_true", help="jede Änderung mit Vorher/Nachher zeigen")
    return p.parse_args()


def main():
    args = parse_args()
    folder = Path(args.folder)

    if not folder.is_dir():
        print(f"Fehler: {folder} ist kein Verzeichnis.")
        sys.exit(1)

    globber = folder.rglob(f"*{args.ext}") if args.recursive else folder.glob(f"*{args.ext}")
    files = sorted(globber)

    if not files:
        print(f"Keine *{args.ext}-Dateien in {folder} gefunden.")
        return

    print(f"Verzeichnis: {folder}")
    print(f"Dateien:     {len(files)}")
    print(f"Modus:       {'DRY-RUN (nur anzeigen)' if args.dry else 'ÄNDERN'}")
    print("-" * 70)

    changed_files = 0
    total_replacements = 0
    space_only_strings = 0
    skipped_unchanged = 0
    invalid_before = []
    invalid_after = []

    for f in files:
        rel = f.relative_to(folder)
        try:
            original = f.read_text(encoding="utf-8")
        except Exception as e:
            print(f"[LESEFEHLER]    {rel}: {e}")
            continue

        # Wie viele " " (nur-Leerzeichen-Strings) gibt es? (Teilmenge von n)
        space_only_count = len(re.findall(r'" "', original))

        new_content, n = PATTERN.subn(r'"\1"', original)

        if n == 0:
            skipped_unchanged += 1
            print(f"[OK]            {rel}")
            continue

        # --- Sicherheitscheck: Original gültiges JSON? ---
        was_valid = True
        try:
            json.loads(original)
        except json.JSONDecodeError as e:
            was_valid = False
            invalid_before.append((rel, str(e)))

        # --- Sicherheitscheck: Nach Fix noch gültig? ---
        is_valid = True
        try:
            json.loads(new_content)
        except json.JSONDecodeError as e:
            is_valid = False
            invalid_after.append((rel, str(e)))

        if was_valid and not is_valid:
            print(f"[WARN]          {rel}: Fix würde JSON ungültig machen! Übersprungen.")
            continue

        changed_files += 1
        total_replacements += n
        space_only_strings += space_only_count

        marker = "WÜRDE FIXEN" if args.dry else "FIX        "
        print(f"[{marker}] {rel}  ({n} Ersetzungen, {space_only_count} davon leere Strings)")

        if args.report:
            for i, (ol, nl) in enumerate(zip(original.splitlines(),
                                              new_content.splitlines()), 1):
                if ol != nl:
                    print(f"      Zeile {i}:")
                    print(f"        - {ol.strip()}")
                    print(f"        + {nl.strip()}")

        if not args.dry:
            try:
                if not args.no_backup:
                    backup = f.with_name(f.name + ".bak")
                    if not backup.exists():
                        shutil.copy2(f, backup)
                f.write_text(new_content, encoding="utf-8")
            except Exception as e:
                print(f"[SCHREIBFEHLER] {rel}: {e}")

    print("-" * 70)
    verb = "würden entfernt" if args.dry else "entfernt"
    print(f"Fertig: {changed_files} von {len(files)} Datei(en) betroffen.")
    print(f"        {total_replacements} Leerzeichen {verb}, "
          f"davon {space_only_strings} aus '\" \"' → '\"\"' (leere Platzhalter).")
    if skipped_unchanged:
        print(f"        {skipped_unchanged} Datei(en) ohne Änderungsbedarf.")

    if invalid_before:
        print(f"\nHinweis: {len(invalid_before)} Datei(en) waren BEREITS VOR dem Fix "
              f"kein gültiges JSON — bitte separat prüfen.")

    if not args.dry and not args.no_backup and changed_files:
        print("\nBackups liegen als *.json.bak daneben (werden nicht überschrieben).")


if __name__ == "__main__":
    main()