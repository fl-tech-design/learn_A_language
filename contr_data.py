from kivy.uix.behaviors import DragBehavior

# datacontrol.py
import json
import logging
from typing import Dict, Any
from constants import DATA_BASE

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
