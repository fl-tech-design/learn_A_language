# language_manager.py
import json
import logging
from typing import Dict, Any

# Konfiguriere das Logging
logging.basicConfig(
    filename="errors.log",
    level=logging.ERROR,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


def load_language_file(curr_language: str) -> Dict[str, Any]:
    """
    Lädt eine Sprach-JSON-Datei und gibt ihren Inhalt zurück.

    Args:
        curr_language: Der Sprachcode (z.B. 'de', 'en')

    Returns:
        Der Inhalt der JSON-Datei oder ein leeres Dictionary im Fehlerfall
    """
    try:
        with open(f"data_{curr_language}.json", "r") as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logging.error(f"Error loading JSON file data_{curr_language}.json: {e}")
        return {}