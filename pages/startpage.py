#startpage.py
from kivy.uix.screenmanager import Screen

class StartPage(Screen):
    def __init__(self, app, **kwargs):
        """
        Initializes the StartPage screen.

        Args:
            app (App): The main application instance.
            **kwargs: Additional keyword arguments passed to the Screen constructor.
        """
        super(StartPage, self).__init__(**kwargs)
        self.app = app
    

    def upd_page(self, *args):
        """
        Updates the StartPage screen with new text values from the app's base_txt dictionary.

        Args:
            *args: Additional arguments that might be passed when calling this method.
        """
        self.ids.t_box_startpage.ids.lab_tit_page.text = self.app.base_txt["tit_page_start"]
        self.ids.b_box_startpage.ids.but_1.text = self.app.base_txt["settings"]
        self.ids.b_box_startpage.ids.but_2.text = self.app.base_txt["exit"]
