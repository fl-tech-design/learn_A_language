# learningpage.py
from kivy.uix.screenmanager import Screen


class LearningPage(Screen):
    def __init__(self, app, **kwargs):
        super(LearningPage, self).__init__(**kwargs)
        self.app = app

    def upd_page(self, *args):
        self.ids.t_box_learningpage.ids.lab_tit_page.text = self.app.app_txt.get("tit_page_learning", "Lernen")
        self.ids.but_new_words.text = self.app.app_txt.get("cat_new_words", "Neue Wörter")
        self.ids.but_due_words.text = self.app.app_txt.get("cat_due_words", "Fällige Wörter")
        self.ids.but_learned_words.text = self.app.app_txt.get("cat_learned_words", "Gelernte Wörter")
        self.ids.but_back_learning.text = self.app.base_txt.get("back", "zurück")

    def go_new_words(self):
        self.app.word_mode = "new"
        self.app.change_screen('left', 'page_word')

    def go_due_words(self):
        self.app.word_mode = "due"
        self.app.change_screen('left', 'page_word')

    def go_learned_words(self):
        self.app.word_mode = "learned"
        self.app.change_screen('left', 'page_word')

    def go_back(self):
        self.app.change_screen('right', 'page_start')
