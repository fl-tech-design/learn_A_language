from kivy.uix.popup import Popup
from kivy.uix.button import Button
from kivy.lang import Builder
from kivy.clock import Clock

import constants
from constants import DIR_POPS
from contr_str import let_uppercase_first
from user_manager import load_userdata, change_login_state, set_logged_uname, init_vocab_for_user
from popups.pop_create_user import Pop_Create_User

# Farben aus colors.kv (fs22_n, fs22_d)
FS22_N = (28/255, 185/255, 236/255, 0.8)
FS22_D = (22/255, 117/255, 149/255, 1)

Builder.load_file(DIR_POPS + "pop_u_login.kv")


class Pop_Login(Popup):
    def __init__(self, app, **kwargs):
        super().__init__(**kwargs)
        self.app = app

        self.title = app.base_txt.get("u_login", "Login")

        # User-Liste aus app_data laden
        self.user_list = self.app.app_data.get("registered_user", [])

        print("registered users:", self.user_list)

        # Bestehende User-Buttons erstellen (vertikal untereinander)
        user_box = self.ids.user_box
        for username in self.user_list:
            btn = Button(
                text=username,
                size_hint_y=None,
                height="56dp",
                font_name=constants.DIR_FONTS + "Jura-Medium.otf",
                font_size="20dp",
                color=FS22_N,
                background_color=(0, 0, 0, 0),
                background_normal="",
                background_down="",
            )
            # Hover-Effekt + Login-Action beim Drücken
            def on_press(instance, btn=btn):
                instance.color = FS22_D
            def on_release(instance, btn=btn, u=username):
                instance.color = FS22_N
                self._userbut_release(u)
            btn.bind(on_press=on_press, on_release=on_release)
            user_box.add_widget(btn)

        # Quit-Button Text setzen
        self.ids.but_quit.text = self.app.base_txt.get("exit", "Exit")
        self.ids.but_add.text = self.app.base_txt.get("btn_add_user", "+ Neuer User")

    def _add_user(self):
        """Öffnet das Registrierungspopup für einen neuen Benutzer."""
        popup = Pop_Create_User(self.app)
        popup.open()
        self._close_Popup()

    def _userbut_release(self, username: str):
        """Meldet einen bestehenden Benutzer an und wechselt zur Startseite."""
        try:
            change_login_state(True)
            set_logged_uname(username)
            self._load_account(username)

            # Vokabel-Dict initialisieren (Level 0 für alle Wörter bei erstem Login)
            language_dict = self.app.user_data.get("language", {})
            init_vocab_for_user(username, language_dict)

            # App-Daten neu laden, damit app_data["logged_u_name"] aktuell ist
            self.app.load_app_data()

            # Zur Startseite wechseln (ändert auch upd_page auf der StartPage)
            self.app.change_screen('left', 'page_start')
        except Exception as e:
            print(f"Error during login for user '{username}': {e}")

        self._close_Popup()

    def _load_account(self, username: str):
        self.app.user_data = load_userdata(username)
        print("userdata:", self.app.user_data)

    def _close_Popup(self):
        self.dismiss()
