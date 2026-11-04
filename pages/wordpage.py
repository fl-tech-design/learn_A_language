# wordpage.py
from kivy.uix.screenmanager import Screen
from user_manager import get_new_words, get_words_by_level, update_word_level


class WordPage(Screen):
    def __init__(self, app, **kwargs):
        """
        Initializes the WordPage screen (single word display with learning).

        Args:
            app (App): The main application instance.
            **kwargs: Additional keyword arguments passed to the Screen constructor.
        """
        super(WordPage, self).__init__(**kwargs)
        self.app = app
        self._current_words = []
        self._current_index = 0
        self._mode = "new"  # "new" oder "review"

    def upd_page(self, *args):
        """
        Updates the WordPage screen. Lädt Wörter basierend auf dem aktuellen Modus.
        """
        self.ids.t_box_wordpage.ids.lab_tit_page.text = self.app.app_txt.get("tit_page_learning", "Lernen")
        self.ids.but_know.text = self.app.app_txt.get("btn_know", "Kenne ich")
        self.ids.but_dont_know.text = self.app.app_txt.get("btn_dont_know", "Kenne ich nicht")
        self.ids.but_next.text = self.app.app_txt.get("btn_next", "Nächstes Wort")
        self.ids.but_back_word.text = self.app.base_txt.get("back", "zurück")

        # Modus bestimmen (wurde von learningpage gesetzt)
        self._mode = getattr(self.app, "word_mode", "new")

        # Wörter laden
        if self._mode == "new":
            self._current_words = get_new_words(self.app.app_data.get("logged_u_name", ""))
        else:
            # Wiederholung: alle Level > 0
            all_review = []
            for level in range(1, 9):
                all_review.extend(get_words_by_level(self.app.app_data.get("logged_u_name", ""), level))
            self._current_words = all_review

        self._current_index = 0
        self._show_word()

    def _show_word(self):
        """Zeigt das aktuelle Wort an."""
        if not self._current_words:
            self.ids.lab_word.text = self.app.app_txt.get("no_words", "Keine Wörter verfügbar")
            self.ids.lab_translation.text = ""
            self.ids.lab_level.text = ""
            self.ids.but_know.disabled = True
            self.ids.but_dont_know.disabled = True
            return

        word = self._current_words[self._current_index]
        self.ids.lab_word.text = word["word"]
        self.ids.lab_translation.text = word["translation"]
        level = word.get("level", 0)
        self.ids.lab_level.text = self.app.app_txt.get("lab_level", "Level: {level}").format(level=level)

        # Buttons aktivieren
        self.ids.but_know.disabled = False
        self.ids.but_dont_know.disabled = False

    def _next_word(self):
        """Wechselt zum nächsten Wort."""
        if not self._current_words:
            return
        self._current_index = (self._current_index + 1) % len(self._current_words)
        self._show_word()

    def on_know(self):
        """Wort als bekannt markieren: Level +1."""
        if not self._current_words:
            return
        word = self._current_words[self._current_index]
        username = self.app.app_data.get("logged_u_name", "")
        new_level = update_word_level(username, word["key"], True)

        if new_level == 8:
            # Level 8 erreicht - Erfolgsmeldung anzeigen
            self.ids.lab_word.text = self.app.app_txt.get("msg_word_learned", "Wort gelernt!")
            self.ids.lab_translation.text = ""
            self.ids.lab_level.text = ""
            self.ids.but_know.disabled = True
            self.ids.but_dont_know.disabled = True
            # Automatisch zum nächsten Wort nach kurzer Pause
            from kivy.clock import Clock
            Clock.schedule_once(lambda dt: self._next_word(), 1.5)
        else:
            self._next_word()

    def on_dont_know(self):
        """Wort als unbekannt markieren: Level auf 0."""
        if not self._current_words:
            return
        word = self._current_words[self._current_index]
        username = self.app.app_data.get("logged_u_name", "")
        update_word_level(username, word["key"], False)
        self._next_word()

    def go_back(self):
        """Wechselt zurück zur LearningPage."""
        self.app.change_screen('right', 'page_learning')
