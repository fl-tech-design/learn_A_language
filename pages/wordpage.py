# wordpage.py
from kivy.uix.screenmanager import Screen
from managers.vocab_manager import (
    get_new_words, get_due_words, get_mastered_words,
    check_word_answer, get_words_due_count, get_new_words_count
)


class WordPage(Screen):
    def __init__(self, app, **kwargs):
        super(WordPage, self).__init__(**kwargs)
        self.app = app
        self._current_words = []
        self._current_index = 0
        self._mode = "new"
        self._answer_checked = False

    def upd_page(self, *args):
        self.ids.t_box_wordpage.ids.lab_tit_page.text = self.app.app_txt.get("tit_page_learning", "Lernen")
        self.ids.but_know.text = self.app.app_txt.get("btn_know", "Ich kenne es")
        self.ids.but_next.text = self.app.app_txt.get("btn_next", "Nächstes Wort")
        self.ids.but_back_word.text = self.app.base_txt.get("back", "zurück")

        self._mode = getattr(self.app, "word_mode", "new")
        self._answer_checked = False

        username = self.app.app_data.get("logged_u_name", "")
        if self._mode == "new":
            self._current_words = get_new_words(username, limit=10)
        elif self._mode == "due":
            self._current_words = get_due_words(username)
        elif self._mode == "learned":
            self._current_words = get_mastered_words(username)

        self._current_index = 0
        self._show_word()

    def _show_word(self):
        self._answer_checked = False
        self.ids.but_know.disabled = False
        self.ids.but_next.disabled = True
        self.ids.lab_feedback.text = ""
        self.ids.lab_feedback.color = (0.2, 0.8, 0.2, 1)

        if not self._current_words:
            self.ids.lab_word.text = self.app.app_txt.get("no_words", "Keine Wörter verfügbar")
            self.ids.lab_example.text = ""
            self.ids.lab_level.text = ""
            self.ids.but_know.disabled = True
            return

        word = self._current_words[self._current_index]
        self.ids.lab_word.text = word["word"]
        self.ids.lab_example.text = word.get("example", "")
        level = word.get("level", 0)
        self.ids.lab_level.text = self.app.app_txt.get("lab_level", "Level: {level}").format(level=level)

    def _next_word(self):
        if not self._current_words:
            return
        self._current_index = (self._current_index + 1) % len(self._current_words)
        self._show_word()

    def on_know(self):
        if not self._current_words or self._answer_checked:
            return

        word = self._current_words[self._current_index]
        username = self.app.app_data.get("logged_u_name", "")

        result = check_word_answer(username, word["key"], word["translation"])

        self._answer_checked = True

        if result["correct"]:
            self.ids.lab_feedback.text = result["message"]
            self.ids.lab_feedback.color = (0.2, 0.8, 0.2, 1)
            self.ids.but_know.disabled = True
            self.ids.but_next.disabled = False
        else:
            self.ids.lab_feedback.text = result["message"]
            self.ids.lab_feedback.color = (0.9, 0.3, 0.3, 1)
            self.ids.but_know.disabled = True
            self.ids.but_next.disabled = False

    def go_back(self):
        self.app.change_screen('right', 'page_learning')
