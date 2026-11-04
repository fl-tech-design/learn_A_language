# user_manager.py
import json
import os
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
from constants import DATA_APP, DIR_USERFILES, DIR_LANGUAGES
from data_manager import load_data, save_data

# Konfiguriere das Logging
logging.basicConfig(
    filename="errors.log",
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


def create_user_file(username: str, m_lang: str, language_dict: dict) -> str:
    """
    Erstellt eine JSON-Datei mit Benutzerdaten, einschließlich der Muttersprache,
    des Lernfortschritts und eines leeren Vokabel-Dicts (wird bei erstem Login gefüllt).

    Args:
        username: Der Benutzername, der als Dateiname und in den JSON-Daten gespeichert wird.
        m_lang: Die Muttersprache des Benutzers.
        language_dict: Das Wörterbuch, das dem Benutzer zugewiesen wird.

    Returns:
        Erfolgsmeldung oder Fehlermeldung
    """
    user_data = {
        "u_name": username,
        "m_lang": m_lang,
        "progress": {
            "A1": 0,
            "A2": 0,
            "B1": 0,
            "B2": 0,
            "C1": 0,
            "C2": 0,
        },
        "learned_languages": [],
        "language": language_dict,
        "vocab": {},
    }

    file_path = f"{DIR_USERFILES}data_{username}.json"

    if os.path.exists(file_path):
        print(f"Fehler: Die Datei für den Benutzer {username} existiert bereits.")
        return f"Benutzer {username} existiert bereits."

    try:
        with open(file_path, "w") as json_file:
            json.dump(user_data, json_file, indent=4)
        print(f"Benutzer {username} wurde erfolgreich erstellt.")
        return f"Benutzer {username} wurde erfolgreich erstellt."
    except Exception as e:
        print(f"Fehler beim Erstellen der Datei: {e}")
        return ""


def load_userdata(username: str) -> Dict[str, Any]:
    """
    Lädt die Benutzerdaten einer JSON-Datei.

    Args:
        username: Der Benutzername

    Returns:
        Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
    """
    try:
        with open(f"{DIR_USERFILES}data_{username}.json", "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file data_{username}.json: {e}")
        return {}


def save_userdata(username: str, data: Dict[str, Any]) -> None:
    """
    Speichert die kompletten Benutzerdaten zurück in die JSON-Datei.

    Args:
        username: Der Benutzername
        data: Die kompletten Benutzerdaten
    """
    file_path = f"{DIR_USERFILES}data_{username}.json"
    try:
        with open(file_path, "w") as file:
            json.dump(data, file, indent=4)
    except IOError as e:
        logging.error(f"Error saving userdata file {file_path}: {e}")



def extract_all_words_from_language_dict(language_dict: dict) -> List[Dict[str, Any]]:
    """
    Extrahiert rekursiv alle Wörter/Sätze aus einem verschachtelten Sprach-Dict.

    Die JSON-Struktur sieht so aus:
    {
        "verbs": {
            "to_be": {
                "past": {
                    "i_was": {"translation": "ich war", "level": 0, "example": {...}},
                    ...
                },
                ...
            },
            ...
        },
        ...
    }

    Returns:
        Liste von Dicts mit keys: key, word, translation, example (optional)
    """
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
    """
    Initialisiert das vocab-Dict in der User-Datei mit allen Wörtern aus dem
    Sprach-Dict, falls es noch nicht existiert. Wird bei erstem Login aufgerufen.

    Jedes Wort bekommt Level 0 und kein letztes Wiederholungsdatum.

    Falls language_dict leer ist, wird basierend auf m_lang die richtige
    Sprach-JSON-Datei aus language_dict/ geladen.

    Args:
        username: Der Benutzername
        language_dict: Das vollständige Sprach-Dict (kann leer sein)
    """
    import json

    user_data = load_userdata(username)

    if user_data.get("vocab"):
        return

    # Wenn language leer ist, basierend auf m_lang die richtige JSON laden
    if not language_dict:
        m_lang = user_data.get("m_lang", "de")
        lang_file = os.path.join(DIR_LANGUAGES, f"verbs_a1_{m_lang}.json")
        if os.path.exists(lang_file):
            with open(lang_file, "r", encoding="utf-8") as f:
                language_dict = json.load(f)
        else:
            logging.error(f"Sprachdatei {lang_file} nicht gefunden!")
            return

    words = extract_all_words_from_language_dict(language_dict)
    vocab = {}
    for w in words:
        vocab[w["key"]] = {
            "word": w["word"],
            "translation": w["translation"],
            "example": w.get("example", ""),
            "level": 0,
            "last_reviewed": None,
        }

    user_data["vocab"] = vocab
    save_userdata(username, user_data)
    print(f"Vokabeln für {username} initialisiert: {len(vocab)} Wörter")


def get_words_by_level(username: str, level: int) -> List[Dict[str, Any]]:
    """
    Gibt alle Vokabeln eines bestimmten Levels zurück.

    Args:
        username: Der Benutzername
        level: Das Level (0-8)

    Returns:
        Liste von Vokabel-Dicts mit keys: key, word, translation, example, level
    """
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})

    result = []
    for key, v in vocab.items():
        if v.get("level") == level:
            result.append({
                "key": key,
                "word": v.get("word", ""),
                "translation": v.get("translation", ""),
                "example": v.get("example", ""),
                "level": v.get("level", 0),
            })

    return result


def get_new_words(username: str) -> List[Dict[str, Any]]:
    """
    Gibt alle noch nie gesehenen Wörter (Level 0) zurück.

    Args:
        username: Der Benutzername

    Returns:
        Liste von Vokabel-Dicts mit Level 0
    """
    return get_words_by_level(username, 0)


def update_word_level(username: str, word_key: str, known: bool) -> Optional[int]:
    """
    Aktualisiert den Lernlevel eines Wortes nach einer Abfrage.

    Spaced-Repetition-Logik:
    - Wenn bekannt (known=True): Level +1 (max 8)
    - Wenn nicht bekannt (known=False): Level auf 0 zurücksetzen

    Args:
        username: Der Benutzername
        word_key: Der Schlüssel des Wortes im vocab-Dict
        known: True wenn das Wort bekannt war, False sonst

    Returns:
        Neues Level oder None bei Fehler
    """
    user_data = load_userdata(username)
    vocab = user_data.get("vocab", {})

    if word_key not in vocab:
        logging.error(f"Wort {word_key} nicht im vocab von {username}")
        return None

    current_level = vocab[word_key].get("level", 0)

    if known:
        new_level = min(current_level + 1, 8)
    else:
        new_level = 0

    vocab[word_key]["level"] = new_level
    vocab[word_key]["last_reviewed"] = datetime.now().isoformat()

    save_userdata(username, user_data)
    return new_level

def add_new_user_to_list(username: str) -> None:
    """
    Fügt einen neuen Benutzernamen zur registered_user-Liste in app_data.json hinzu.
    Die Liste wächst dynamisch – es gibt kein festes Limit mehr.

    Args:
        username: Der Benutzername, der hinzugefügt werden soll.
    """
    data = load_data(DATA_APP)

    if username not in data.get("registered_user", []):
        data.setdefault("registered_user", []).append(username)
        save_data(DATA_APP, data)


def change_login_state(new_state: bool) -> None:
    """
    Ändert den Login-Status in app_data.json.

    Args:
        new_state: True wenn eingeloggt, False wenn ausgeloggt
    """
    data = load_data(DATA_APP)
    data["user_logged_in"] = new_state
    save_data(DATA_APP, data)


def set_logged_uname(logged_uname: str) -> None:
    """
    Setzt den aktuell eingeloggten Benutzernamen in app_data.json.

    Args:
        logged_uname: Der Benutzername
    """
    print("logged_uname: ", logged_uname)
    data = load_data(DATA_APP)
    data["logged_u_name"] = logged_uname
    save_data(DATA_APP, data)