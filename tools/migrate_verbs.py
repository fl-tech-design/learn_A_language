#!/usr/bin/env python3
"""Migrate old key-based verb JSONs to the new list-based schema.

Usage:
    python tools/migrate_verbs.py assets/language_dict/de/ assets/language_dict/en/

Skips files already in list schema (those containing 'translations' key in
past/present/future).
"""

import json
import os
import sys

# Person prefixes in extraction order — 'you_plural_' must precede 'you_' to
# avoid ambiguous matches (both keys start with 'you_').
PERSON_PREFIXES = ['i_', 'you_plural_', 'you_', 'he_she_it_', 'we_', 'they_']

# Target position for the new list schema (0=ich, 1=du, 2=er/sie/es, 3=wir, 4=ihr, 5=sie)
POSITION_MAP = {
    'i_': 0,
    'you_plural_': 4,
    'you_': 1,
    'he_she_it_': 2,
    'we_': 3,
    'they_': 5,
}
TENSES = ['past', 'present', 'future']


def is_list_schema(data: dict) -> bool:
    """Return True if data already uses the new list-based schema."""
    for tense in TENSES:
        if tense in data and isinstance(data[tense], dict):
            if 'translations' in data[tense]:
                return True
    return False





def _validate_and_extract(tense_data: dict, filepath: str, tense: str) -> tuple[list[str], list[list[str]]] | None:
    """Extract translations and examples from an old-schema tense map.
    
    Returns (translations, examples) or None on validation failure.
    translations: 6 strings (ich → sie)
    examples: 6 lists of 3 strings each
    """
    result: dict[int, tuple[str, list[str]]] = {}
    available = set(tense_data.keys())

    for prefix in PERSON_PREFIXES:
        matches = [k for k in available if k.startswith(prefix)]
        if len(matches) != 1:
            print(
                f"SKIP {filepath}: tense={tense} prefix={prefix} "
                f"matches={matches} (available: {sorted(available)})",
                file=sys.stderr,
            )
            return None
        key = matches[0]
        available.remove(key)

        person = tense_data[key]
        if not isinstance(person, dict):
            print(
                f"SKIP {filepath}: tense={tense} key={key} is not an object",
                file=sys.stderr,
            )
            return None

        trans = person.get('translation', '')

        # Extract example: old schema has 'example' as a single-key object
        raw_ex = person.get('example', {})
        if isinstance(raw_ex, dict):
            vals = list(raw_ex.values())
            ex_text = str(vals[0]) if vals else ''
        elif isinstance(raw_ex, str):
            ex_text = raw_ex
        else:
            ex_text = ''

        pos = POSITION_MAP[prefix]
        result[pos] = (trans, [ex_text, '', ''])

    if len(result) != 6:
        print(
            f"SKIP {filepath}: tense={tense} expected 6 persons, got {len(result)}",
            file=sys.stderr,
        )
        return None

    translations = [result[i][0] for i in range(6)]
    examples = [result[i][1] for i in range(6)]
    return translations, examples


def migrate_file(filepath: str) -> bool:
    """Migrate a single verb JSON file from old to new schema.

    Returns True on success, False on skip/error.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if is_list_schema(data):
        print(f"  FIX-SORT: {filepath}")
        # Re-sort: old order was [i_, you_plural_, you_, he_she_it_, we_, they_]
        # correct order is  [i_, you_, he_she_it_, we_, you_plural_, they_]
        # old index → new index: 0→0, 2→1, 3→2, 4→3, 1→4, 5→5
        reorder = [0, 2, 3, 4, 1, 5]
        for tense in TENSES:
            if tense in data and isinstance(data[tense], dict):
                td = data[tense]
                if isinstance(td.get('translations'), list):
                    td['translations'] = [td['translations'][i] for i in reorder]
                if isinstance(td.get('examples'), list):
                    td['examples'] = [td['examples'][i] for i in reorder]
                if isinstance(td.get('audio'), list):
                    td['audio'] = [td['audio'][i] for i in reorder]
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        return True

    # Validate top-level structure
    if not isinstance(data, dict):
        print(f"SKIP {filepath}: root is not an object", file=sys.stderr)
        return False

    infinitive = data.get('infinitive')
    if not infinitive:
        print(f"SKIP {filepath}: missing infinitive", file=sys.stderr)
        return False

    new_data = {'infinitive': infinitive}
    errors = False

    for tense in TENSES:
        if tense not in data:
            print(f"SKIP {filepath}: missing tense '{tense}'", file=sys.stderr)
            errors = True
            break

        result = _validate_and_extract(data[tense], filepath, tense)
        if result is None:
            errors = True
            break

        trans, ex = result
        new_data[tense] = {
            'translations': trans,
            'examples': ex,
            'audio': [[], [], [], [], [], []],
        }

    if errors:
        return False

    # Write back (overwrite)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(new_data, f, indent=2, ensure_ascii=False)
        f.write('\n')

    return True


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} DIR [DIR ...]")
        sys.exit(1)

    error_files = []
    migrated = 0
    skipped = 0

    for dirpath in sys.argv[1:]:
        if not os.path.isdir(dirpath):
            print(f"Not a directory: {dirpath}", file=sys.stderr)
            continue

        json_files = sorted(
            os.path.join(dirpath, f)
            for f in os.listdir(dirpath)
            if f.endswith('.json')
        )

        for filepath in json_files:
            basename = os.path.basename(filepath)
            # Skip already-migrated to_be files
            if basename.endswith('_to_be.json'):
                print(f"  SKIP (to_be pilot): {filepath}")
                skipped += 1
                continue

            try:
                ok = migrate_file(filepath)
                if ok:
                    migrated += 1
                    print(f"  OK: {filepath}")
                else:
                    error_files.append(filepath)
            except Exception as e:
                print(f"SKIP {filepath}: exception: {e}", file=sys.stderr)
                error_files.append(filepath)

    print(f"\nMigrated: {migrated}")
    print(f"Skipped:  {skipped}")
    print(f"Errors:   {len(error_files)}")

    if error_files:
        print("\nError files:", file=sys.stderr)
        for ef in error_files:
            print(f"  {ef}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()