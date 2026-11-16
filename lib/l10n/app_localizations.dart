import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @all_due_done.
  ///
  /// In en, this message translates to:
  /// **'All due words completed!'**
  String get all_due_done;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get back;

  /// No description provided for @base_title.
  ///
  /// In en, this message translates to:
  /// **'New App'**
  String get base_title;

  /// No description provided for @btn_add_user.
  ///
  /// In en, this message translates to:
  /// **'+ New User'**
  String get btn_add_user;

  /// No description provided for @btn_change_user.
  ///
  /// In en, this message translates to:
  /// **'Change user'**
  String get btn_change_user;

  /// No description provided for @btn_check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get btn_check;

  /// No description provided for @btn_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btn_continue;

  /// No description provided for @btn_delete_user.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get btn_delete_user;

  /// No description provided for @btn_end_session.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get btn_end_session;

  /// No description provided for @btn_game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get btn_game;

  /// No description provided for @btn_grammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get btn_grammar;

  /// No description provided for @btn_learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get btn_learn;

  /// No description provided for @btn_new_words.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get btn_new_words;

  /// No description provided for @btn_next.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get btn_next;

  /// No description provided for @btn_next_word.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get btn_next_word;

  /// No description provided for @btn_prev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get btn_prev;

  /// No description provided for @btn_read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get btn_read;

  /// No description provided for @btn_review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get btn_review;

  /// No description provided for @btn_turbo.
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get btn_turbo;

  /// No description provided for @cat_due_words.
  ///
  /// In en, this message translates to:
  /// **'Due words'**
  String get cat_due_words;

  /// No description provided for @cat_learned_words.
  ///
  /// In en, this message translates to:
  /// **'Learned words'**
  String get cat_learned_words;

  /// No description provided for @cat_new_lang.
  ///
  /// In en, this message translates to:
  /// **'Discover new languages'**
  String get cat_new_lang;

  /// No description provided for @cat_new_words.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get cat_new_words;

  /// No description provided for @cat_select.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get cat_select;

  /// No description provided for @chancel.
  ///
  /// In en, this message translates to:
  /// **'chancel'**
  String get chancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'confirm'**
  String get confirm;

  /// No description provided for @difficulty_easy.
  ///
  /// In en, this message translates to:
  /// **'Easy (20s / +3s)'**
  String get difficulty_easy;

  /// No description provided for @difficulty_easy_short.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficulty_easy_short;

  /// No description provided for @difficulty_hard.
  ///
  /// In en, this message translates to:
  /// **'Hard (10s / +1s)'**
  String get difficulty_hard;

  /// No description provided for @difficulty_hard_short.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficulty_hard_short;

  /// No description provided for @difficulty_medium.
  ///
  /// In en, this message translates to:
  /// **'Medium (15s / +2s)'**
  String get difficulty_medium;

  /// No description provided for @difficulty_medium_short.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficulty_medium_short;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'english'**
  String get english;

  /// No description provided for @examples_title.
  ///
  /// In en, this message translates to:
  /// **'Examples:'**
  String get examples_title;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @feedback_correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get feedback_correct;

  /// No description provided for @feedback_correct_would_be.
  ///
  /// In en, this message translates to:
  /// **'Correct would be:'**
  String get feedback_correct_would_be;

  /// No description provided for @feedback_wrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong!'**
  String get feedback_wrong;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @game_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get game_back;

  /// No description provided for @game_lives.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get game_lives;

  /// No description provided for @game_over.
  ///
  /// In en, this message translates to:
  /// **'Game Over!'**
  String get game_over;

  /// No description provided for @game_record_prefix.
  ///
  /// In en, this message translates to:
  /// **'R: '**
  String get game_record_prefix;

  /// No description provided for @game_restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get game_restart;

  /// No description provided for @game_score.
  ///
  /// In en, this message translates to:
  /// **'Pts'**
  String get game_score;

  /// No description provided for @game_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get game_time;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'german'**
  String get german;

  /// No description provided for @inf_delete_user.
  ///
  /// In en, this message translates to:
  /// **'Enter the username to delete.'**
  String get inf_delete_user;

  /// No description provided for @inf_learning.
  ///
  /// In en, this message translates to:
  /// **'Choose here which word group you want to learn.'**
  String get inf_learning;

  /// No description provided for @inf_settings.
  ///
  /// In en, this message translates to:
  /// **'Here you can make various basic settings for the app, such as language and so on.'**
  String get inf_settings;

  /// No description provided for @inf_start.
  ///
  /// In en, this message translates to:
  /// **'You are on the home page. From here, you can start exploring the entire app.'**
  String get inf_start;

  /// No description provided for @inf_user_reg.
  ///
  /// In en, this message translates to:
  /// **'Please enter \na username.'**
  String get inf_user_reg;

  /// No description provided for @inf_username.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 1 character.'**
  String get inf_username;

  /// No description provided for @inf_word.
  ///
  /// In en, this message translates to:
  /// **'Read the word and translation, then click \"Read\".'**
  String get inf_word;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @input_hint.
  ///
  /// In en, this message translates to:
  /// **'Read the word and click \"Read\"'**
  String get input_hint;

  /// No description provided for @input_hint_due.
  ///
  /// In en, this message translates to:
  /// **'Type the translation'**
  String get input_hint_due;

  /// No description provided for @lab_level.
  ///
  /// In en, this message translates to:
  /// **'Level: {level}'**
  String lab_level(int level);

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @limit_reached.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached!'**
  String get limit_reached;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get loading;

  /// No description provided for @loading_complete.
  ///
  /// In en, this message translates to:
  /// **'loading complete'**
  String get loading_complete;

  /// No description provided for @m_lang.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue'**
  String get m_lang;

  /// No description provided for @msg_word_learned.
  ///
  /// In en, this message translates to:
  /// **'Word learned! (Level 8 reached)'**
  String get msg_word_learned;

  /// No description provided for @my_courses.
  ///
  /// In en, this message translates to:
  /// **'My Languages'**
  String get my_courses;

  /// No description provided for @no_courses.
  ///
  /// In en, this message translates to:
  /// **'No courses'**
  String get no_courses;

  /// No description provided for @no_due_words.
  ///
  /// In en, this message translates to:
  /// **'No due words!'**
  String get no_due_words;

  /// No description provided for @no_learned_words.
  ///
  /// In en, this message translates to:
  /// **'No learned words to play.\nLearn new words first!'**
  String get no_learned_words;

  /// No description provided for @no_new_lang.
  ///
  /// In en, this message translates to:
  /// **'No new languages available'**
  String get no_new_lang;

  /// No description provided for @no_u_reg.
  ///
  /// In en, this message translates to:
  /// **'No user registered'**
  String get no_u_reg;

  /// No description provided for @no_words.
  ///
  /// In en, this message translates to:
  /// **'No words available'**
  String get no_words;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'register'**
  String get register;

  /// No description provided for @select_difficulty.
  ///
  /// In en, this message translates to:
  /// **'Select a difficulty:'**
  String get select_difficulty;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @stay_logged_in.
  ///
  /// In en, this message translates to:
  /// **'Stay logged in'**
  String get stay_logged_in;

  /// No description provided for @tit_page_learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get tit_page_learning;

  /// No description provided for @tit_page_sett.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tit_page_sett;

  /// No description provided for @tit_page_start.
  ///
  /// In en, this message translates to:
  /// **'Startpage'**
  String get tit_page_start;

  /// No description provided for @translation_label.
  ///
  /// In en, this message translates to:
  /// **'Translation:'**
  String get translation_label;

  /// No description provided for @u_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get u_login;

  /// No description provided for @u_name.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get u_name;

  /// No description provided for @u_registration.
  ///
  /// In en, this message translates to:
  /// **'User Registration'**
  String get u_registration;

  /// No description provided for @user_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get user_delete;

  /// No description provided for @welcome_message.
  ///
  /// In en, this message translates to:
  /// **'Welcome to our app!'**
  String get welcome_message;

  /// No description provided for @words_10.
  ///
  /// In en, this message translates to:
  /// **'10 words'**
  String get words_10;

  /// No description provided for @words_3.
  ///
  /// In en, this message translates to:
  /// **'3 words'**
  String get words_3;

  /// No description provided for @words_5.
  ///
  /// In en, this message translates to:
  /// **'5 words'**
  String get words_5;

  /// No description provided for @words_per_session.
  ///
  /// In en, this message translates to:
  /// **'Words per session'**
  String get words_per_session;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
