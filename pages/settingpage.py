# settingpage.py
from kivy.uix.screenmanager import Screen
from typing import Any, Dict
from kivy.app import App

from contr_str import let_uppercase_first
from constants import DIR_FLAGS
from data_manager import load_data, save_data
from constants import DATA_APP


class SettingPage(Screen):
    def __init__(self, app: App, **kwargs: Dict[str, Any]) -> None:
        """
        Initialize the SettingPage screen.

        :param app: The main application instance.
        :param kwargs: Additional keyword arguments.
        """
        super(SettingPage, self).__init__(**kwargs)
        self.app = app

    def upd_page(self, *args: Any) -> None:
        """
        Update the text elements on the settings page based on the application's base text data.
        """
        # Title box definitions
        self.ids.t_box_settings.ids.lab_tit_page.text = self.app.base_txt[
            "tit_page_sett"
        ]
        # Middle box definitions
        self.ids.lab_tit_lang.text = self.app.base_txt["languages"]
        self.ids.box_flag_1.ids.img_flag.source = (DIR_FLAGS + "flag_germany.png")
        self.ids.box_flag_1.ids.lab_flag.text = let_uppercase_first(
            self.app.base_txt["german"]
        )

        self.ids.box_flag_2.ids.img_flag.source = (DIR_FLAGS + "flag_uk.png")
        self.ids.box_flag_2.ids.lab_flag.text = let_uppercase_first(
            self.app.base_txt["english"]
        )

        # Checkbox "Eingeloggt bleiben" laden
        app_data = load_data(DATA_APP)
        stay_logged = app_data.get("stay_logged_in", False)
        self.ids.cb_stay_logged.active = stay_logged

        # Bottom box definitions
        self.ids.but_back_settings.text = let_uppercase_first(
            self.app.base_txt["back"]
        )
        self.ids.but_quit_settings.text = let_uppercase_first(
            self.app.base_txt["exit"]
        )

    def on_stay_logged_toggle(self, active: bool) -> None:
        """
        Speichert den Zustand der Checkbox "Eingeloggt bleiben" in app_data.json.

        :param active: True wenn aktiviert, False sonst
        """
        app_data = load_data(DATA_APP)
        app_data["stay_logged_in"] = active
        save_data(DATA_APP, app_data)
