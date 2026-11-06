# user_manager.py
import json
import os
import logging
from typing import Dict, Any
from constants import DATA_APP, DIR_USERFILES
from managers.data_manager import load_data, save_data

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