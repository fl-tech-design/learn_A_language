# main.py
# Import constants from constants.py
from constants import (
    LIST_KV_FILES,
    SPL_SCREEN_START_APP,
    DATA_BASE,
    TXT_BASE,
    APP_TITLE,
    TXT_APP,
    DATA_APP,
    CONFIG_STAT,
)

# Kivy window configuration
from kivy.config import Config


def config_win_size(h: str = "850", w: str = "450", resizable: bool = False) -> None:
    """
    Configure the Kivy window size and resizability.

    Args:
        h: Window height as string (Kivy expects strings for Config).
        w: Window width as string.
        resizable: Whether the user can resize the window.
    """
    Config.set("graphics", "resizable", "1" if resizable else "0")
    Config.set("graphics", "height", h)
    Config.set("graphics", "width", w)
    Config.write()


if CONFIG_STAT:
    config_win_size()

import sys

from kivy.app import App
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.lang import Builder
from kivy.clock import Clock

# Import data controller
from data_manager import load_data, update_data
from user_manager import change_login_state

# Import pages
from pages.loadingpage import LoadingPage
from pages.startpage import StartPage
from pages.learningpage import LearningPage
from pages.wordpage import WordPage
from pages.settingpage import SettingPage

# Import popups
from popups.pop_info import Pop_Info
from popups.pop_u_login import Pop_Login
from popups.pop_create_user import Pop_Create_User

# Load all KV files
for kv_file in LIST_KV_FILES:
    Builder.load_file(kv_file)

class MainApp(App):
    """Main application class managing the ScreenManager and global app state."""

    def build(self) -> ScreenManager:
        """
        Builds the main application interface.

        Initializes data, loads JSON configuration, and sets up the ScreenManager.

        Returns:
            ScreenManager: The main ScreenManager for the application.
        """
        global app
        app = self
        self.title = APP_TITLE

        # Initialize data containers
        self.base_data: dict = {}
        self.base_txt: dict = {}
        self.app_data: dict = {}
        self.app_txt: dict = {}
        self.color1: list = []
        self.color2: list = []
        self.color3: list = []
        self.user_data: dict = {}
        self.word_mode: str = "new"

        self.load_app_data()

        print("self.user_data:", self.user_data)

        # Defer login popup until the window is fully initialized
        Clock.schedule_once(lambda dt: self._check_user_status(), 0)

        # Initialize the ScreenManager
        self.scr_man = ScreenManager()
        return self._create_screen_manager()

    def _check_user_status(self) -> None:
        """
        Prüft den Benutzerstatus.
        - Kein User registriert → Registrierungspopup öffnen (erster Start)
        - User registriert aber nicht eingeloggt → Login-Popup öffnen
        """
        registered_users = self.app_data.get("registered_user", [])

        if not registered_users:
            # Erster Start: noch kein User registriert
            popup = Pop_Create_User(app)
            popup.open()
        elif not self.app_data.get("user_logged_in", False):
            # User existieren, aber keiner eingeloggt
            popup = Pop_Login(app)
            popup.open()

    def _create_screen_manager(self) -> ScreenManager:
        """
        Creates and configures the ScreenManager with initial screens.

        Returns:
            ScreenManager: The configured ScreenManager.
        """
        # Loading screen
        self.spl_scr_start = LoadingPage(
            app,
            self.base_txt,
            self.scr_man,
            SPL_SCREEN_START_APP,
            "page_start",
            name="spl_scr_start",
        )
        self.scr_man.add_widget(self.spl_scr_start)

        # Start page
        self.start_page = self._create_screen("page_start", StartPage(app))
        self.scr_man.add_widget(self.start_page)
        Clock.schedule_once(lambda dt: self.start_page.children[0].upd_page(), 0)

        # Settings page
        self.setting_page = self._create_screen("page_setting", SettingPage(app))
        self.scr_man.add_widget(self.setting_page)

        self.learning_page = self._create_screen("page_learning", LearningPage(app))
        self.scr_man.add_widget(self.learning_page)

        self.word_page = self._create_screen("page_word", WordPage(app))
        self.scr_man.add_widget(self.word_page)

        return self.scr_man

    def _create_screen(self, name: str, widget: Screen) -> Screen:
        """
        Helper method to wrap a widget in a Screen.

        Args:
            name: Screen name used by the ScreenManager.
            widget: The root widget of the screen.

        Returns:
            Screen: The created screen containing the widget.
        """
        screen = Screen(name=name)
        screen.add_widget(widget)
        return screen

    def change_screen(self, new_transition: str, new_scr_name: str) -> None:
        """
        Switches to another screen with a transition animation.

        Args:
            new_transition: Transition direction (e.g. 'left', 'right').
            new_scr_name: Name of the target screen.
        """
        self.root.transition.direction = new_transition
        self.root.current = new_scr_name
        new_screen = self.scr_man.get_screen(new_scr_name)
        Clock.schedule_once(lambda dt: new_screen.children[0].upd_page(), 0)

    def load_app_data(self) -> None:
        """
        Loads base data (colors, texts, app settings) from JSON files.
        Converts color values from 0-255 range to 0-1 float range.
        """
        print("load_app_data() from main.py")
        self.base_data = load_data(DATA_BASE)
        current_lang = self.base_data.get("curr_lang", "de")

        self.base_txt = load_data(TXT_BASE).get(current_lang, {})
        self.app_data = load_data(DATA_APP)
        self.app_txt = load_data(TXT_APP).get(current_lang, {})

        colors = self.base_data.get("colors", {})
        self.color1 = [c / 255 for c in colors.get("color1", [255, 255, 255])]
        self.color2 = [c / 255 for c in colors.get("color2", [255, 255, 255])]
        self.color3 = [c / 255 for c in colors.get("color3", [255, 255, 255])]

    def open_inf_pop(self, *args) -> None:
        """Opens an info popup with text depending on the current screen."""
        if self.scr_man.current == "page_start":
            inf_msg = self.base_txt.get("inf_start", "")
        elif self.scr_man.current == "page_setting":
            inf_msg = self.base_txt.get("inf_settings", "")
        else:
            inf_msg = ""

        popup = Pop_Info(app, inf_msg)
        popup.open()

    def change_language(self, new_language: str) -> None:
        """
        Changes the application language and reloads all text data.

        Args:
            new_language: The language name to switch to (e.g. 'German', 'English').
        """
        if new_language == self.base_txt.get("german", "German"):
            update_data(DATA_BASE, "curr_lang", "de")
        elif new_language == self.base_txt.get("english", "English"):
            update_data(DATA_BASE, "curr_lang", "en")

        self.load_app_data()

        new_screen = self.scr_man.get_screen("page_setting")
        Clock.schedule_once(lambda dt: new_screen.children[0].upd_page(), 0)

    def open_login_popup(self) -> None:
        """Öffnet das Login-Popup zum Wechseln des Benutzers (ohne App-Neustart)."""
        popup = Pop_Login(app)
        popup.open()

    def _app_stop(self) -> None:
        """Cleanly stops the application and saves logout state."""
        # Prüfe ob "Eingeloggt bleiben" aktiviert ist
        app_data = load_data(DATA_APP)
        stay_logged = app_data.get("stay_logged_in", False)

        if not stay_logged:
            change_login_state(False)
        self.stop()


if __name__ == "__main__":
    app = MainApp()
    app.run()
