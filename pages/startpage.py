#startpage.py
from kivy.uix.screenmanager import Screen
from managers.vocab_manager import get_words_due_count, get_new_words_count


class StartPage(Screen):
    def __init__(self, app, **kwargs):
        super(StartPage, self).__init__(**kwargs)
        self.app = app

    def upd_page(self, *args):
        self.ids.t_box_startpage.ids.lab_tit_page.text = self.app.base_txt["tit_page_start"]

        self.ids.lab_u_name.text = self.app.base_txt["u_name"]
        self.ids.lab_logged_user.text = self.app.app_data["logged_u_name"]
        self.ids.but_change_user.text = self.app.base_txt.get("btn_change_user", "User")

        self.ids.b_box_startpage.ids.but_1.text = self.app.base_txt["settings"]
        self.ids.b_box_startpage.ids.but_2.text = self.app.base_txt["exit"]

        username = self.app.app_data.get("logged_u_name", "")
        if username:
            new_count = get_new_words_count(username)
            due_count = get_words_due_count(username)
            self.ids.lab_new_count.text = f"{self.app.app_txt.get('cat_new_words', 'Neue Wörter')}: {new_count}"
            self.ids.lab_due_count.text = f"{self.app.app_txt.get('cat_due_words', 'Fällige Wörter')}: {due_count}"
        else:
            self.ids.lab_new_count.text = ""
            self.ids.lab_due_count.text = ""
