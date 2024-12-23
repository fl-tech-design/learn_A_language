# constants.py
import os

VERSION_NR = "0.0.1"
APP_TITLE = "learn A language"

DATA_BASE = os.path.join(os.path.dirname(__file__), "data_base/base_data.json")
TXT_BASE = os.path.join(os.path.dirname(__file__), "data_base/base_txt.json")

DATA_APP = os.path.join(os.path.dirname(__file__), "data_app/app_data.json") 
TXT_APP = os.path.join(os.path.dirname(__file__), "data_app/app_txt.json")

DIR_FONTS = os.path.join(os.path.dirname(__file__), "data_base/base_fonts/")
DIR_FLAGS = os.path.join(os.path.dirname(__file__), "data_base/base_images/")
DIR_POPS = os.path.join(os.path.dirname(__file__), "popups/")
DIR_USERFILES = os.path.join(os.path.dirname(__file__), "data_app/files_user/")
DIR_LANGUAGES = os.path.join(os.path.dirname(__file__), "language_dict/")
LIST_KV_FILES = [
    "data_base/colors.kv",
    "data_base/own_widgets.kv",
    "pages/startpage.kv",
    "pages/settingpage.kv",
]

SPL_SCREEN_START_APP = os.path.join(
    os.path.dirname(__file__), "data_base/base_images/spl_start.png"
)

PATH_TO_MAINLOGO = os.path.join(
    os.path.dirname(__file__), "data_base/base_images/logo_main.png"
)
