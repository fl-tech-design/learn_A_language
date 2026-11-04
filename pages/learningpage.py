# learningpage.py
from kivy.uix.screenmanager import Screen


class LearningPage(Screen):
    def __init__(self, app, **kwargs):
        """
        Initializes the LearningPage screen (category menu).

        Args:
            app (App): The main application instance.
            **kwargs: Additional keyword arguments passed to the Screen constructor.
        """
        super(LearningPage, self).__init__(**kwargs)
        self.app = app

    def upd_page(self, *args):
        """
        Updates the LearningPage screen with new text values.
        """
        self.ids.t_box_learningpage.ids.lab_tit_page.text = self.app.app_txt.get("tit_page_learning", "Lernen")
        self.ids.but_new_words.text = self.app.app_txt.get("btn_new_words", "Neue Wörter")
        self.ids.but_review.text = self.app.app_txt.get("btn_review", "Wiederholung")
        self.ids.but_back_learning.text = self.app.base_txt.get("back", "zurück")

    def go_new_words(self):
        """Wechselt zur Wort-Anzeige für neue Wörter (Level 0)."""
        self.app.word_mode = "new"
        self.app.change_screen('left', 'page_word')

    def go_review(self):
        """Wechselt zur Wort-Anzeige für Wiederholung (alle Level > 0)."""
        self.app.word_mode = "review"
        self.app.change_screen('left', 'page_word')

    def go_back(self):
        """Wechselt zurück zur Startseite."""
        self.app.change_screen('right', 'page_start')
