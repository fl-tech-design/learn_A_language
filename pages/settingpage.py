# settingpage.py
from kivy.uix.screenmanager import Screen
from typing import Any, Dict
from kivy.app import App

from contr_str import let_uppercase_first
from constants import DIR_FLAGS

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
        self.ids.box_flag_1.ids.lab_flag.text = let_uppercase_first(self.app.base_txt["german"])
        
        self.ids.box_flag_2.ids.img_flag.source = (DIR_FLAGS + "flag_uk.png")
        self.ids.box_flag_2.ids.lab_flag.text = let_uppercase_first(self.app.base_txt["english"])

        # Bottom box definitions
        self.ids.b_box_settings.ids.but_1.text = let_uppercase_first(
            self.app.base_txt["back"]
        )
        self.ids.b_box_settings.ids.but_2.text = let_uppercase_first(
            self.app.base_txt["exit"]
        )


