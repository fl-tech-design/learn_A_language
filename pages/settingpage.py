# settingpage.py
from kivy.uix.screenmanager import Screen
from typing import Any, Dict
from kivy.app import App

from contr_str import let_uppercase_first
from constants import DIR_FLAGS
from managers.data_manager import load_data, save_data
from constants import DATA_APP


class SettingPage(Screen):
    def __init__(self, app: App, **kwargs: Dict[str, Any]) -> None:
        super(SettingPage, self).__init__(**kwargs)
        self.app = app

    def upd_page(self, *args: Any) -> None:
        self.ids.t_box_settings.ids.lab_tit_page.text = self.app.base_txt["tit_page_sett"]
        self.ids.lab_tit_lang.text = self.app.base_txt["languages"]
        self.ids.box_flag_1.ids.img_flag.source = (DIR_FLAGS + "flag_germany.png")
        self.ids.box_flag_1.ids.lab_flag.text = let_uppercase_first(self.app.base_txt["german"])
        self.ids.box_flag_2.ids.img_flag.source = (DIR_FLAGS + "flag_uk.png")
        self.ids.box_flag_2.ids.lab_flag.text = let_uppercase_first(self.app.base_txt["english"])

        app_data = load_data(DATA_APP)
        stay_logged = app_data.get("stay_logged_in", False)
        self.ids.cb_stay_logged.active = stay_logged

        self.ids.but_back_settings.text = let_uppercase_first(self.app.base_txt["back"])
        self.ids.but_quit_settings.text = let_uppercase_first(self.app.base_txt["exit"])

    def on_stay_logged_toggle(self, active: bool) -> None:
        app_data = load_data(DATA_APP)
        app_data["stay_logged_in"] = active
        save_data(DATA_APP, app_data)

    def on_words_per_session_toggle(self, count: int, state: str) -> None:
        if state == "down":
            app_data = load_data(DATA_APP)
            app_data["words_per_session"] = count
            save_data(DATA_APP, app_data)

    def go_back(self) -> None:
        """Wechselt zur zuletzt geöffneten Seite."""
        self.app.go_back()
