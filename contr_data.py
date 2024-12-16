from kivy.uix.behaviors import DragBehavior

# datacontrol.py
import json
import os
import logging
from typing import Dict, Any
from constants import DATA_BASE, DIR_USERFILES

# Konfiguriere das Logging
logging.basicConfig(
    filename="errors.log",
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


def load_base_data(f_path: str) -> Dict[str, Any]:
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


def save_base_data(data: Dict[str, Any]) -> None:
    """
    Speichert Daten in eine JSON-Datei.

    :param file_path: Der Pfad zur JSON-Datei
    :param data: Die Daten, die in der JSON-Datei gespeichert werden sollen
    """
    try:
        with open(DATA_BASE, "w") as file:
            json.dump(data, file, indent=4)
    except IOError as e:
        logging.error(f"Error saving JSON file {DATA_BASE}: {e}")


def update_base_data(key: str, new_value: Any) -> None:
    """
    Ändert den Wert eines bestimmten Schlüssels in einer JSON-Datei.

    :param key: Der Schlüssel des Wertes, der geändert werden soll
    :param new_value: Der neue Wert, der dem Schlüssel zugewiesen werden soll
    """
    data = load_base_data(DATA_BASE)

    if key in data:
        data[key] = new_value
        save_base_data(data)
    else:
        logging.error(f"Schlüssel '{key}' nicht gefunden.")


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
    file_path = f'{DIR_USERFILES}data_{username}.json'

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
        with open(f'data_{curr_language}.json', "r") as file:
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
        with open(f'{DIR_USERFILES}data_{username}.json', "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file data_{username}.json: {e}")
        return {}
