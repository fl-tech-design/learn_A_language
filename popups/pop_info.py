from kivy.uix.popup import Popup
from kivy.lang import Builder
from constants import DIR_POPS
from contr_str import let_uppercase_first

Builder.load_file(DIR_POPS + "pop_info.kv")


class Pop_Info(Popup):
    def __init__(self, app, info_msg: str, **kwargs):
        super(Pop_Info, self).__init__(**kwargs)
        self.app = app
        self.title = f'{self.app.base_txt["information"]}'

        # Set the message for the label
        self.ids.text_label.text = info_msg

        # Set close button text
        self.ids.but_close_popup.text = let_uppercase_first(
            self.app.base_txt["close"]
        )

    def close_Popup(self):
        self.dismiss()
