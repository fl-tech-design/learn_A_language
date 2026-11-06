# logging_helper.py
# Zentralisierte Logging-Konfiguration für die gesamte App.
# Alle Module nutzen einen eigenen Logger (getLogger(__name__)).
# Die Konfiguration wird ein einziges Mal hier geladen und über die
# Kivy-App initialisiert.

import logging
import os
from pathlib import Path
from typing import Optional


def setup_logging(log_level: int = logging.ERROR) -> logging.Logger:
    """
    Richtet das zentrale Logging ein und schreibt Fehler in eine Datei.

    Das Log-Verzeichnis orientiert sich am Betriebssystem:
      - Windows: %APPDATA%/lAl/logs/errors.log
      - macOS:   ~/Library/Logs/lAl/errors.log
      - Linux:   ~/.local/share/lAl/logs/errors.log

    Auf Android (Buildozer/Kivy) wird der Pfad über
    App.user_data_dir ermittelt, sofern verfügbar.

    Args:
        log_level: Mindest-Log-Level (Default: ERROR).

    Returns:
        Der konfigurierte Root-Logger.
    """
    # Basis-Verzeichnis für Log-Dateien bestimmen
    log_dir = None
    try:
        # Versuche, über Kivy App den user_data_dir zu nutzen (Android / mobil)
        from kivy.app import App

        app = App.get_running_app()
        if app is not None:
            log_dir = Path(app.user_data_dir) / "logs"
    except Exception as e:
        import sys
        print(f"[logging_helper] Failed to get Kivy app user_data_dir: {e}", file=sys.stderr)
        log_dir = None

    if log_dir is None:
        # Fallback auf plattformspezifisches Standard-Verzeichnis
        home = Path.home()
        if os.name == "nt":  # Windows
            base = Path(os.getenv("APPDATA", home / "AppData" / "Roaming"))
            log_dir = base / "lAl" / "logs"
        elif os.name == "posix":
            if "darwin" in os.uname().sysname.lower():  # macOS
                log_dir = home / "Library" / "Logs" / "lAl"
            else:  # Linux
                log_dir = home / ".local" / "share" / "lAl" / "logs"
        else:
            log_dir = Path.cwd() / "logs"

    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "errors.log"

    logging.basicConfig(
        filename=str(log_file),
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        force=True,
    )

    root_logger = logging.getLogger()
    return root_logger


def get_logger(name: str) -> logging.Logger:
    """
    Gibt einen benannten Logger zurück (einmal pro Modul).

    Args:
        name: Name des Loggers (in der Regel __name__).

    Returns:
        Ein konfiguriertes logging.Logger-Objekt.
    """
    return logging.getLogger(name)
