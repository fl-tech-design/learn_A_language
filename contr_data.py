from kivy.uix.behaviors import DragBehavior

# datacontrol.py
import json
import os
import logging
from typing import Dict, Any
from constants import DATA_BASE, DIR_USERFILES, DATA_APP

# Konfiguriere das Logging
logging.basicConfig(
    filename="errors.log",
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


def load_data(f_path: str) -> Dict[str, Any]:
    """
    Lädt eine JSON-Datei und gibt ihren Inhalt zurück.
    :return: Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
    """
    try:
        with open(f_path, "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file {f_path}: {e}")
        return {}


def save_data(f_path: str, data: Dict[str, Any]) -> None:
    """
    Speichert Daten in eine JSON-Datei.

    :param file_path: Der Pfad zur JSON-Datei
    :param data: Die Daten, die in der JSON-Datei gespeichert werden sollen
    """
    try:
        with open(f_path, "w") as file:
            json.dump(data, file, indent=4)
    except IOError as e:
        logging.error(f"Error saving JSON file {f_path}: {e}")


def update_data(f_path: str, keyword: str, new_value: Any) -> None:
    """
    Ändert den Wert eines bestimmten Schlüssels in einer JSON-Datei.

    :param key: Der Schlüssel des Wertes, der geändert werden soll
    :param new_value: Der neue Wert, der dem Schlüssel zugewiesen werden soll
    """
    data = load_data(f_path)

    if keyword in data:
        data[keyword] = new_value
        save_data(f_path, data)
    else:
        logging.error(f"Schlüssel '{keyword}' nicht gefunden.")


def create_user_file(username: str, m_lang: str, language_dict: dict):
    """
    Erstellt eine JSON-Datei mit Benutzerdaten, einschließlich der Muttersprache, des Lernfortschritts und eines Wörterbuchs.

    :param username: Der Benutzername, der als Dateiname und in den JSON-Daten gespeichert wird.
    :param m_lang: Die Muttersprache des Benutzers, die in den JSON-Daten gespeichert wird.
    :param language_dict: Das Wörterbuch, das dem Benutzer zugewiesen wird.
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
        "learned_languages": [],  # Liste der gelernten Sprachen (initial leer)
        "language": language_dict,  # Das zugewiesene Wörterbuch
    }

    # Definiere den Dateipfad für die JSON-Datei
    file_path = f"{DIR_USERFILES}data_{username}.json"

    # Überprüfe, ob die Datei bereits existiert
    if os.path.exists(file_path):
        print(f"Fehler: Die Datei für den Benutzer {username} existiert bereits.")
        return f"Benutzer {username} existiert bereits."

    # Schreibe die Benutzerdaten in die JSON-Datei
    try:
        with open(file_path, "w") as json_file:
            json.dump(user_data, json_file, indent=4)
        print(f"Benutzer {username} wurde erfolgreich erstellt.")
        return f"Benutzer {username} wurde erfolgreich erstellt."
    except Exception as e:
        print(f"Fehler beim Erstellen der Datei: {e}")
        return ""


def load_language_file(curr_language: str):
    """
    Lädt eine JSON-Datei und gibt ihren Inhalt zurück.
    :return: Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
    """
    try:
        with open(f"data_{curr_language}.json", "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file data_{curr_language}.json: {e}")
        return {}


def load_userdata(username: str):
    """
    Lädt eine JSON-Datei und gibt ihren Inhalt zurück.
    :return: Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
    """
    try:
        with open(f"{DIR_USERFILES}data_{username}.json", "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file data_{username}.json: {e}")
        return {}

def add_new_user_to_list(username: str):
    data = load_data(DATA_APP)

    if "" in data["registered_user"]:  # Überprüfen, ob ein Platzhalter existiert
        index = data["registered_user"].index("")  # Ersten Index von "" finden
        data["registered_user"][index] = username  # Platzhalter ersetzen
    else:
        data["registered_user"].append(username)

    save_data(DATA_APP, data)    



def change_login_state(new_state: bool):
    data = load_data(DATA_APP)
    data["user_logged_in"] = new_state
    save_data(DATA_APP, data)

def set_logged_uname(logged_uname: str):
    data = load_data(DATA_APP)
    data["logged_u_name"] = logged_uname
    save_data(DATA_APP, data)