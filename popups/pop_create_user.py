from kivy.uix.popup import Popup
from kivy.lang import Builder
from constants import DIR_POPS, DIR_FLAGS
from contr_str import let_uppercase_first
from contr_data import create_user_file

Builder.load_file(DIR_POPS + "pop_create_user.kv")


class Pop_Create_User(Popup):
    def __init__(self, app, **kwargs):
        super().__init__(**kwargs)
        self.app = app
        self.title = app.app_txt["u_registration"]
        
        self.ids.lab_inf_user_reg.text = self.app.base_txt["inf_user_reg"]
        
        self.ids.lab_m_lang.text = self.app.app_txt["m_lang"]
        
        self.ids.toggle_de.text = let_uppercase_first(self.app.base_txt["german"])
        self.ids.toggle_en.text = let_uppercase_first(self.app.base_txt["english"])

        self.ids.but_confirm.text = let_uppercase_first(self.app.base_txt["confirm"])
        self.ids.but_chancel.text = let_uppercase_first(self.app.base_txt["chancel"])

    def _save_new_user(self, instance):
        """
        Verarbeitet die Erstellung eines neuen Benutzers.
        """
        username = self.ids.inp_username.text
        
        if self.ids.toggle_de.state == "down":
            m_lang = "de"
        else:
            m_lang = "en"
        language_dict = {}  # Beispieldaten oder tatsächliches Wörterbuch laden

        # Benutzerdatei erstellen
        result = create_user_file(username, m_lang, language_dict)
        print("result: ", result)
        self.ids.inp_username.hint_text = result
        
        self._close_popup()

    def _close_popup(self):
        self.dismiss()
