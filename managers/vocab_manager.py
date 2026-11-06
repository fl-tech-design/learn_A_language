# vocab_manager.py
# Vokabel-Extraktion, Spaced Repetition, Prüfung.
#
# Nutzt den zentralen Logger aus logging_helper.

import json
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

from managers.data_manager import load_data, save_data
from managers.user_manager import load_userdata, save_userdata
from constants import DATA_APP, DIR_USERFILES, DIR_LANGUAGES

# Zentralisierter Logger (einmal pro Modul)
import logging
logging.basicConfig(
    filename="errors.log",
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
log = logging.getLogger(__name__)

# Spaced Repetition: Tage bis zur nächsten Wiederholung pro Level
REPEAT_INTERVAL_DAYS = {
    0: 1,
    1: 2,
    2: 3,
    3: 5,
    4: 7,
    5: 10,
    6: 14,
    7: 21,
    8: None,
}


def extract_all_words_from_language_dict(language_dict: dict) -> List[Dict[str, Any]]:
    """Extrahiert rekursiv alle Wörter/Sätze aus einem verschachtelten Sprach-Dict."""
    words = []

    def _recurse(data, current_key=""):
        if isinstance(data, dict):
            if "translation" in data and "word" not in data:
                word_key = current_key.split("/")[-1] if current_key else ""
                word_text = word_key.replace("_", " ")
                example = data.get("example", {})
                example_text = ""
                if isinstance(example, dict) and example:
                    example_key = list(example.keys())[0]
                    example_text = example.get(example_key, "")
                words.append({
                    "key": word_key,
                    "word": word_text,
                    "translation": data["translation"],
                    "example": example_text,
                })
            else:
                for key, value in data.items():
                    new_key = f"{current_key}/{key}" if current_key else key
                    _recurse(value, new_key)
        elif isinstance(data, list):
            for item in data:
                _recurse(item, current_key)

    _recurse(language_dict)
    return words


def init_vocab_for_user(username: str, language_dict: dict) -> None:
    """Initialisiert das vocab-Dict in der User-Datei mit allen Wörtern."""
    import json

    user_data = load_userdata(username)

    if user_data.get("vocab"):
        return

    if not language_dict:
        m_lang = user_data.get("m_lang", "de")
        lang_file = os.path.join(DIR_LANGUAGES, f"verbs_a1_{m_lang}.json")
        if os.path.exists(lang_file):
            with open(lang_file, "r", encoding="utf-8") as f:
                language_dict = json.load(f)
        else:
            logging.error("Sprachdatei %s nicht gefunden!", lang_file)
            return

    words = extract_all_words_from_language_dict(language_dict)
    vocab = {}
    for w in words:
        vocab[w["key"]] = {
            "word": w["word"],
            "translation": w["translation"],
            "example": w.get("example", ""),
            "level": 0,
            "status": "new",
            "last_reviewed": None,
            "review_due": None,
        }

    user_data["vocab"] = vocab
    save_userdata(username, user_data)
    logging.info("Vokabeln für %s initialisiert: %d Wörter", username, len(vocab))


def migrate_vocab_for_user(username: str) -> None:
    """
    Migriert bestehende User-Dateien: Fügt fehlende Felder (status, review_due)
    zu allen vocab-Einträgen hinzu. Wird bei jedem Login aufgerufen.
    """
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})
    changed = False

    for word_key, entry in vocab.items():
        if "status" not in entry:
            entry["status"] = "new" if entry.get("level", 0) == 0 else "seen"
            changed = True
        if "review_due" not in entry:
            entry["review_due"] = None
            changed = True
        if "last_reviewed" not in entry:
            entry["last_reviewed"] = None
            changed = True
        if "level" not in entry:
            entry["level"] = 0
            changed = True

    if changed:
        save_userdata(username, user_data)
        logging.info("Vokabeln für %s migriert (%d Einträge)", username, len(vocab))


def get_due_words(username: str) -> List[Dict[str, Any]]:
    """
    Gibt alle Wörter zurück, deren review_due <= heute ist.
    Inkludiert neue Wörter (level 0, status 'new').
    """
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})
    today = datetime.now().date()
    due_words = []

    for word_key, entry in vocab.items():
        level = entry.get("level", 0)
        status = entry.get("status", "new")
        review_due_str = entry.get("review_due")

        if level == 8:
            continue

        if status == "new":
            due_words.append({"key": word_key, **entry})
            continue

        if review_due_str:
            try:
                review_due = datetime.fromisoformat(review_due_str).date()
                if review_due <= today:
                    due_words.append({"key": word_key, **entry})
            except ValueError:
                log.warning("Ungültiges review_due für %s: %s", word_key, review_due_str)
                due_words.append({"key": word_key, **entry})
        else:
            due_words.append({"key": word_key, **entry})

    return due_words


def get_words_by_level(username: str, target_level: int) -> List[Dict[str, Any]]:
    """Gibt alle Wörter mit einem bestimmten Level zurück."""
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})
    return [
        {"key": k, **v} for k, v in vocab.items() if v.get("level", 0) == target_level
    ]


def get_new_words(username: str) -> List[Dict[str, Any]]:
    """Gibt alle neuen Wörter zurück (level 0, status 'new')."""
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})
    return [
        {"key": k, **v}
        for k, v in vocab.items()
        if v.get("level", 0) == 0 and v.get("status") == "new"
    ]


def get_seen_words(username: str) -> List[Dict[str, Any]]:
    """Gibt alle gelernten Wörter zurück (level > 0)."""
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})
    return [
        {"key": k, **v} for k, v in vocab.items() if v.get("level", 0) > 0
    ]


def get_mastered_words(username: str) -> List[Dict[str, Any]]:
    """Gibt alle vollständig gelernten Wörter zurück (level 8)."""
    return get_words_by_level(username, 8)


def get_words_due_count(username: str) -> int:
    """Gibt die Anzahl fälliger Wörter zurück."""
    return len(get_due_words(username))


def get_new_words_count(username: str) -> int:
    """Gibt die Anzahl neuer Wörter zurück."""
    words = get_words_by_level(username, 0)
    return len([w for w in words if w.get("status") == "new"])


def check_word_answer(username: str, word_key: str, user_input: str) -> Dict[str, Any]:
    """
    Prüft die Benutzereingabe gegen die korrekte Übersetzung.
    Berücksichtigt Case-insensitive und ignoriert Leerzeichen.

    Spaced-Repetition-Logik:
    - Richtig: Level +1 (max 8), review_due berechnen, status auf "seen" (bei erstem Mal)
    - Falsch: Level auf 0, review_due auf morgen

    Args:
        username: Der Benutzername
        word_key: Der Schlüssel des Wortes im vocab-Dict
        user_input: Die Eingabe des Benutzers

    Returns:
        Dict mit keys: correct (bool), correct_word (str), new_level (int),
                       message (str), status_changed (bool)
    """
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})

    if word_key not in vocab:
        logging.error("Wort %s nicht im vocab von %s", word_key, username)
        return {
            "correct": False,
            "correct_word": "",
            "new_level": 0,
            "message": "Wort nicht gefunden",
            "status_changed": False,
        }

    word_entry = vocab[word_key]
    correct_translation = word_entry.get("translation", "")
    current_level = word_entry.get("level", 0)
    current_status = word_entry.get("status", "new")

    # Vergleich: case-insensitive, Leerzeichen ignorieren
    user_clean = user_input.strip().lower().replace(" ", "")
    correct_clean = correct_translation.strip().lower().replace(" ", "")
    is_correct = user_clean == correct_clean

    result = {
        "correct": is_correct,
        "correct_word": correct_translation,
        "new_level": current_level,
        "message": "",
        "status_changed": False,
    }

    if is_correct:
        new_level = min(current_level + 1, 8)
        word_entry["level"] = new_level
        word_entry["last_reviewed"] = datetime.now().isoformat()

        # Status auf "seen" setzen bei erstem erfolgreichen Lernen
        if current_status == "new":
            word_entry["status"] = "seen"
            result["status_changed"] = True

        # review_due berechnen (außer Level 8 = gelernt)
        if new_level < 8:
            days = REPEAT_INTERVAL_DAYS.get(new_level, 1)
            next_due = datetime.now() + timedelta(days=days)
            word_entry["review_due"] = next_due.date().isoformat()
        else:
            word_entry["review_due"] = None

        result["new_level"] = new_level
        if new_level == 8:
            result["message"] = "Ausgezeichnet! Wort gelernt (Level 8)."
        else:
            result["message"] = "Richtig! Gut gemacht."
    else:
        word_entry["level"] = 0
        word_entry["status"] = "new"
        word_entry["last_reviewed"] = datetime.now().isoformat()
        word_entry["review_due"] = (datetime.now() + timedelta(days=1)).date().isoformat()
        result["new_level"] = 0
        result["message"] = f"Leider falsch. Richtig wäre: {correct_translation}"

    save_userdata(username, user_data)
    return result
