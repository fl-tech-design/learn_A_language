# main.py

from kivy.config import Config
from kivy.core.window import Window

# Set the window to be non-resizable and specify its size
Config.set("graphics", "resizable", "0")
Config.write()
Window.size = (450, 850)  # Example for a 9:16 aspect ratio

from kivy.app import App
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.lang import Builder
from kivy.clock import Clock

# Import DataControl
from contr_data import load_base_data
from contr_data import update_base_data

# Import pages
from pages.loadingpage import LoadingPage
from pages.startpage import StartPage
from pages.settingpage import SettingPage

from constants import (
    LIST_KV_FILES,
    SPL_SCREEN_START_APP,
    DATA_BASE,
    TXT_BASE,
    APP_TITLE,
)

from popups.pop_info import Pop_Info

# Load all KV files
for kv_file in LIST_KV_FILES:
    Builder.load_file(kv_file)




class MainApp(App):
    def build(self) -> ScreenManager:
        """
        Builds the main application interface.

        Initializes the DataControl, loads data, and sets up the ScreenManager.

        Returns:
            ScreenManager: The main ScreenManager for the application.
        """
        global app
        app = self
        self.title = APP_TITLE

        # Initialize DataControl and load JSON data
        self.base_data, self.base_txt = {}, {}
        self.color1, self.color2, self.color3 = [], [], []
        self.load_base_data()

        # Initialize the ScreenManager
        self.scr_man = ScreenManager()

        return self._create_screen_manager()

    def _create_screen_manager(self) -> ScreenManager:
        """
        Creates and configures the ScreenManager.

        Adds the initial screens (LoadingPage, StartPage, and SettingPage) to the ScreenManager.

        Returns:
            ScreenManager: The configured ScreenManager.
        """
        # Create the LoadingPage
        self.spl_scr_start = LoadingPage(
            app,
            self.base_txt,
            self.scr_man,
            SPL_SCREEN_START_APP,
            "page_start",
            name="spl_scr_start",
        )
        self.scr_man.add_widget(self.spl_scr_start)

        # Create the StartPage
        self.start_page = self._create_screen("page_start", StartPage(app))
        self.scr_man.add_widget(self.start_page)
        Clock.schedule_once(lambda dt: self.start_page.children[0].upd_page(), 0)

        # Create the SettingPage
        self.setting_page = self._create_screen("page_setting", SettingPage(app))
        self.scr_man.add_widget(self.setting_page)

        return self.scr_man

    def _create_screen(self, name: str, widget: Screen) -> Screen:
        """
        Helper method to create a screen with a widget.

        Args:
            name (str): The name of the screen.
            widget (Screen): The widget to add to the screen.

        Returns:
            Screen: The created screen with the widget added.
        """
        screen = Screen(name=name)
        screen.add_widget(widget)
        return screen

    def change_screen(self, new_transition: str, new_scr_name: str) -> None:
        """
        Changes the current screen with a specified transition.

        Args:
            new_transition (str): The direction of the transition (e.g., 'left', 'right').
            new_scr_name (str): The name of the screen to switch to.
        """
        self.root.transition.direction = new_transition
        self.root.current = new_scr_name
        new_screen = self.scr_man.get_screen(new_scr_name)
        Clock.schedule_once(lambda dt: new_screen.children[0].upd_page(), 0)

    def load_base_data(self) -> None:
        """
        load base data in the app.

        Loads the colors and text data, and converts color values from 0-255 to 0-1 range.
        """
        # Store the loaded colors as instance variables
        self.base_data = load_base_data(DATA_BASE)
        self.base_txt = load_base_data(TXT_BASE)[self.base_data["curr_lang"]]
        self.color1 = [c / 255 for c in self.base_data["colors"]["color1"]]
        self.color2 = [c / 255 for c in self.base_data["colors"]["color2"]]
        self.color3 = [c / 255 for c in self.base_data["colors"]["color3"]]

    def open_inf_pop(self, *args):
        if self.scr_man.current == "page_start":
            inf_msg = self.base_txt["inf_start"]
        elif self.scr_man.current == "page_setting":
            inf_msg = self.base_txt["inf_settings"]
        popup = Pop_Info(app, inf_msg)
        popup.open()

    def change_language(self, new_language: str) -> None:
        """
        Change the application's language setting and update the page accordingly.

        :param new_language: The new language to set (e.g., "German" or "English").
        """
        if new_language == self.base_txt["german"]:
            update_base_data("curr_lang", "de")
        elif new_language == self.base_txt["english"]:
            update_base_data("curr_lang", "en")
        self.load_base_data()
        new_screen = self.scr_man.get_screen("page_setting")
        Clock.schedule_once(lambda dt: new_screen.children[0].upd_page(), 0)

if __name__ == "__main__":
    app = MainApp()
    app.run()
