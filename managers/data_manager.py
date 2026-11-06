# data_manager.py
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

    Returns:
        Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
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

    Args:
        f_path: Der Pfad zur JSON-Datei
        data: Die Daten, die in der JSON-Datei gespeichert werden sollen
    """
    try:
        with open(f_path, "w") as file:
            json.dump(data, file, indent=4)
    except IOError as e:
        logging.error(f"Error saving JSON file {f_path}: {e}")


def update_data(f_path: str, keyword: str, new_value: Any) -> None:
    """
    Ändert den Wert eines bestimmten Schlüssels in einer JSON-Datei.

    Args:
        f_path: Der Pfad zur JSON-Datei
        keyword: Der Schlüssel des Wertes, der geändert werden soll
        new_value: Der neue Wert, der dem Schlüssel zugewiesen werden soll
    """
    data = load_data(f_path)

    if keyword in data:
        data[keyword] = new_value
        save_data(f_path, data)
    else:
        logging.error(f"Schlüssel '{keyword}' nicht gefunden.")