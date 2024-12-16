from kivy.uix.popup import Popup
from kivy.lang import Builder
from constants import DIR_POPS
from contr_str import let_uppercase_first
from contr_data import load_userdata
from popups.pop_create_user import Pop_Create_User

Builder.load_file(DIR_POPS + "pop_u_login.kv")


class Pop_Login(Popup):
    def __init__(self, app, **kwargs):
        super().__init__(**kwargs)
        self.app = app

        self.userlist_index = 0
        self.user_list = self.app.app_data["registered_user"]

        print(self.user_list)
        self.title = app.app_txt["u_login"]

        for i in range(3):
            print(self.user_list[i])  # Debugging: Gibt die Einträge aus
            if self.user_list[i] == "":
                self.ids[f"but_u_{i}"].text = let_uppercase_first(app.base_txt["free"])
            else:
                self.ids[f"but_u_{i}"].text = self.user_list[i]

        self.ids.but_quit.text = let_uppercase_first(app.base_txt["exit"])

    def _load_account(self, username: str):
        self.app.user_data = load_userdata(username)
        print("userdata: ", self.app.user_data)

    def _userbut_release(self, instance):
        if instance.text == self.app.base_txt["free"]:
            print(
                "Freier Speicherplatz wurde gewählt und popup register useer wird geöffnet"
            )
            popup = Pop_Create_User(self.app)
            popup.open()

        else:
            print(
                f"User: {instance.text} wurde gewählt. Userdaten müssen geladen und in hauptbildschirm eingfügt werden"
            )
            self._load_account(instance.text)

    def _close_Popup(self):
        self.dismiss()
