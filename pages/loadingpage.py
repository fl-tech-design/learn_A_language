# loading_page.py

from kivy.uix.screenmanager import Screen, SlideTransition, NoTransition
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.progressbar import ProgressBar
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.clock import Clock
import time

from contr_str import let_uppercase_first


class LoadingPage(Screen):
    def __init__(
        self,
        app: object,
        lab_txt: dict,
        scr_man: object,
        spl_scr: str,
        new_page: str,
        prog_bar_y: float = 0.16,
        stat_lab_y: float = 0.12,
        **kwargs,
    ):
        """
        Initialize the loading page.

        :param app: Reference to the main application object.
        :param lab_txt: Dictionary containing text for labels.
        :param scr_man: Screen manager to control screen transitions.
        :param spl_scr: Path to the splash screen image.
        :param new_page: Name of the screen to transition to after loading.
        :param prog_bar_y: Y-position of the progress bar as a percentage of screen height.
        :param stat_lab_y: Y-position of the status label as a percentage of screen height.
        :param kwargs: Additional arguments for the Screen class.
        """
        super(LoadingPage, self).__init__(**kwargs)
        self.app = app
        self.txt_lab = lab_txt
        self.scr_man = scr_man
        self.new_page = new_page
        layout = FloatLayout()

        # Background image
        self.background = Image(source=spl_scr, fit_mode="fill")
        layout.add_widget(self.background)

        # Status label
        self.status_label = Label(
            size_hint=(0.8, 0.1),
            text=let_uppercase_first(f'{self.txt_lab["loading"]}'),
            font_size=self.height * 0.6,
            pos_hint={"x": 0.1, "y": stat_lab_y},
        )
        layout.add_widget(self.status_label)

        # Progress bar
        self.progress_bar = ProgressBar(
            max=100, size_hint=(0.75, 0.25), pos_hint={"center_x": 0.5, "y": prog_bar_y}
        )
        layout.add_widget(self.progress_bar)

        self.add_widget(layout)

        # Start the loading process
        Clock.schedule_once(self.start_loading, 1)

    def start_loading(self, dt: float):
        """
        Start the loading process and update the progress bar.

        :param dt: Time delay before starting the loading.
        """
        Clock.schedule_interval(self.load_data, 0.01)
        self.loading_progress = 0

    def load_data(self, dt: float):
        """
        Simulate data loading, update the progress bar, and display loading status.

        :param dt: Time elapsed between the last frame and the current frame.
        """
        time.sleep(0.1)
        self.loading_progress += 10
        self.progress_bar.value = self.loading_progress
        self.status_label.text = let_uppercase_first(
            f'{self.txt_lab["loading"]}...  {self.loading_progress}%'
        )
        self.status_label.font_size = "42sp"

        if self.loading_progress >= 100:
            Clock.unschedule(self.load_data)
            self.status_label.text = let_uppercase_first(
                f'{self.txt_lab["loading_complete"]}!'
            )
            Clock.schedule_once(self.go_to_main_screen, 1)

    def go_to_main_screen(self, dt: float):
        """
        Transition to the main screen after loading is complete.

        :param dt: Time delay before transitioning to the main screen.
        """
        self.scr_man.transition = NoTransition()  # Set NoTransition
        self.scr_man.current = self.new_page
        self.scr_man.transition = SlideTransition()  # Reset to SlideTransition
