import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

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
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @allDueDone.
  ///
  /// In en, this message translates to:
  /// **'All due words completed!'**
  String get allDueDone;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @baseTitle.
  ///
  /// In en, this message translates to:
  /// **'New App'**
  String get baseTitle;

  /// No description provided for @btnAddUser.
  ///
  /// In en, this message translates to:
  /// **'+ New User'**
  String get btnAddUser;

  /// No description provided for @btnChangeUser.
  ///
  /// In en, this message translates to:
  /// **'Change user'**
  String get btnChangeUser;

  /// No description provided for @btnCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get btnCheck;

  /// No description provided for @btnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btnContinue;

  /// No description provided for @btnCrossword.
  ///
  /// In en, this message translates to:
  /// **'Crossword'**
  String get btnCrossword;

  /// No description provided for @btnDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get btnDeleteUser;

  /// No description provided for @btnEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get btnEndSession;

  /// No description provided for @btnGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get btnGame;

  /// No description provided for @btnGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get btnGrammar;

  /// No description provided for @btnLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get btnLearn;

  /// No description provided for @btnNewWords.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get btnNewWords;

  /// No description provided for @btnNext.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get btnNext;

  /// No description provided for @btnNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get btnNextWord;

  /// No description provided for @btnPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get btnPrev;

  /// No description provided for @btnRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get btnRead;

  /// No description provided for @btnReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get btnReview;

  /// No description provided for @btnTurbo.
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get btnTurbo;

  /// No description provided for @btnWordSearch.
  ///
  /// In en, this message translates to:
  /// **'Word Search'**
  String get btnWordSearch;

  /// No description provided for @catDueWords.
  ///
  /// In en, this message translates to:
  /// **'Due words'**
  String get catDueWords;

  /// No description provided for @catInProgressWords.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get catInProgressWords;

  /// No description provided for @catVerbs.
  ///
  /// In en, this message translates to:
  /// **'Verbs'**
  String get catVerbs;

  /// No description provided for @catLearnedWords.
  ///
  /// In en, this message translates to:
  /// **'Learned words'**
  String get catLearnedWords;

  /// No description provided for @catMoreVerbs.
  ///
  /// In en, this message translates to:
  /// **'More Verbs'**
  String get catMoreVerbs;

  /// No description provided for @catNewLang.
  ///
  /// In en, this message translates to:
  /// **'Discover new languages'**
  String get catNewLang;

  /// No description provided for @catNewWords.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get catNewWords;

  /// No description provided for @catReadWords.
  ///
  /// In en, this message translates to:
  /// **'Read words'**
  String get catReadWords;

  /// No description provided for @catSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get catSelect;

  /// No description provided for @catSelectSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Select a subcategory'**
  String get catSelectSubcategory;

  /// No description provided for @chancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy (20s / +3s)'**
  String get difficultyEasy;

  /// No description provided for @difficultyEasyShort.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasyShort;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard (10s / +1s)'**
  String get difficultyHard;

  /// No description provided for @difficultyHardShort.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHardShort;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (15s / +2s)'**
  String get difficultyMedium;

  /// No description provided for @difficultyMediumShort.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMediumShort;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @examplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Examples:'**
  String get examplesTitle;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @feedbackCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get feedbackCorrect;

  /// No description provided for @feedbackCorrectWouldBe.
  ///
  /// In en, this message translates to:
  /// **'Correct would be:'**
  String get feedbackCorrectWouldBe;

  /// No description provided for @feedbackWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong!'**
  String get feedbackWrong;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @grammarContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get grammarContrast;

  /// No description provided for @grammarExamFocus.
  ///
  /// In en, this message translates to:
  /// **'Exam tip'**
  String get grammarExamFocus;

  /// No description provided for @grammarExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get grammarExamples;

  /// No description provided for @grammarExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get grammarExplanation;

  /// No description provided for @grammarNoTopics.
  ///
  /// In en, this message translates to:
  /// **'No grammar topics available.'**
  String get grammarNoTopics;

  /// No description provided for @grammarPitfall.
  ///
  /// In en, this message translates to:
  /// **'Common mistake'**
  String get grammarPitfall;

  /// No description provided for @grammarQuickCheck.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get grammarQuickCheck;

  /// No description provided for @grammarSolution.
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get grammarSolution;

  /// No description provided for @infGrammar.
  ///
  /// In en, this message translates to:
  /// **'Choose a grammar topic to read its explanation in your mother tongue.'**
  String get infGrammar;

  /// No description provided for @titPageGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get titPageGrammar;

  /// No description provided for @gameBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get gameBack;

  /// No description provided for @gameLives.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get gameLives;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game Over!'**
  String get gameOver;

  /// No description provided for @gameRecordPrefix.
  ///
  /// In en, this message translates to:
  /// **'R: '**
  String get gameRecordPrefix;

  /// No description provided for @gameRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get gameRestart;

  /// No description provided for @gameScore.
  ///
  /// In en, this message translates to:
  /// **'Pts'**
  String get gameScore;

  /// No description provided for @gameTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get gameTime;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @infDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Enter the username to delete.'**
  String get infDeleteUser;

  /// No description provided for @infLearning.
  ///
  /// In en, this message translates to:
  /// **'Choose here which word group you want to learn.'**
  String get infLearning;

  /// No description provided for @infSettings.
  ///
  /// In en, this message translates to:
  /// **'Here you can make various basic settings for the app, such as language and so on.'**
  String get infSettings;

  /// No description provided for @infStart.
  ///
  /// In en, this message translates to:
  /// **'You are on the home page. From here, you can start exploring the entire app.'**
  String get infStart;

  /// No description provided for @infUserReg.
  ///
  /// In en, this message translates to:
  /// **'Please enter \na username.'**
  String get infUserReg;

  /// No description provided for @infUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 1 character.'**
  String get infUsername;

  /// No description provided for @infWord.
  ///
  /// In en, this message translates to:
  /// **'Read the word and translation, then click \"Read\".'**
  String get infWord;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @inputHint.
  ///
  /// In en, this message translates to:
  /// **'Read the word and click \"Read\"'**
  String get inputHint;

  /// No description provided for @inputHintDue.
  ///
  /// In en, this message translates to:
  /// **'Type the translation'**
  String get inputHintDue;

  /// No description provided for @labLevel.
  ///
  /// In en, this message translates to:
  /// **'Level: {level}'**
  String labLevel(int level);

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached!'**
  String get limitReached;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @loadingComplete.
  ///
  /// In en, this message translates to:
  /// **'Loading complete'**
  String get loadingComplete;

  /// No description provided for @mLang.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue'**
  String get mLang;

  /// No description provided for @msgRemoveCourse.
  ///
  /// In en, this message translates to:
  /// **'If you remove this course, all related learning progress will be deleted.\n\nContinue?'**
  String get msgRemoveCourse;

  /// No description provided for @myCourses.
  ///
  /// In en, this message translates to:
  /// **'My Languages'**
  String get myCourses;

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'New record!'**
  String get newRecord;

  /// No description provided for @noContentYet.
  ///
  /// In en, this message translates to:
  /// **'No content available yet.'**
  String get noContentYet;

  /// No description provided for @noCourses.
  ///
  /// In en, this message translates to:
  /// **'No courses'**
  String get noCourses;

  /// No description provided for @noDueWords.
  ///
  /// In en, this message translates to:
  /// **'No due words!'**
  String get noDueWords;

  /// No description provided for @dueWordsDone.
  ///
  /// In en, this message translates to:
  /// **'Great! You made it for today.'**
  String get dueWordsDone;

  /// No description provided for @noLearnedWords.
  ///
  /// In en, this message translates to:
  /// **'No words to play yet.\nLearn new words first!'**
  String get noLearnedWords;

  /// No description provided for @noNewLang.
  ///
  /// In en, this message translates to:
  /// **'No new languages available'**
  String get noNewLang;

  /// No description provided for @noUReg.
  ///
  /// In en, this message translates to:
  /// **'No user registered'**
  String get noUReg;

  /// No description provided for @noWords.
  ///
  /// In en, this message translates to:
  /// **'No words available'**
  String get noWords;

  /// No description provided for @recordWithHighscore.
  ///
  /// In en, this message translates to:
  /// **'Record: {highscore} {label}'**
  String recordWithHighscore(int highscore, String label);

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @selectDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Select a difficulty:'**
  String get selectDifficulty;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @stayLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Stay logged in'**
  String get stayLoggedIn;

  /// No description provided for @streakAndRecord.
  ///
  /// In en, this message translates to:
  /// **'Streak {current}  |  Record: {longest}'**
  String streakAndRecord(int current, int longest);

  /// No description provided for @titChooseGame.
  ///
  /// In en, this message translates to:
  /// **'Choose Game'**
  String get titChooseGame;

  /// No description provided for @titPageLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get titPageLearning;

  /// No description provided for @titPageSett.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get titPageSett;

  /// No description provided for @titPageStart.
  ///
  /// In en, this message translates to:
  /// **'Startpage'**
  String get titPageStart;

  /// No description provided for @titRemoveCourse.
  ///
  /// In en, this message translates to:
  /// **'Remove course'**
  String get titRemoveCourse;

  /// No description provided for @translationLabel.
  ///
  /// In en, this message translates to:
  /// **'Translation:'**
  String get translationLabel;

  /// No description provided for @uLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get uLogin;

  /// No description provided for @uName.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get uName;

  /// No description provided for @uRegistration.
  ///
  /// In en, this message translates to:
  /// **'User Registration'**
  String get uRegistration;

  /// No description provided for @userDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get userDelete;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to our app!'**
  String get welcomeMessage;

  /// No description provided for @words10.
  ///
  /// In en, this message translates to:
  /// **'10 words'**
  String get words10;

  /// No description provided for @words3.
  ///
  /// In en, this message translates to:
  /// **'3 words'**
  String get words3;

  /// No description provided for @words5.
  ///
  /// In en, this message translates to:
  /// **'5 words'**
  String get words5;

  /// No description provided for @wordsPerSession.
  ///
  /// In en, this message translates to:
  /// **'Words per session'**
  String get wordsPerSession;

  /// No description provided for @wsHint.
  ///
  /// In en, this message translates to:
  /// **'Find these words:'**
  String get wsHint;

  /// No description provided for @wsSolution.
  ///
  /// In en, this message translates to:
  /// **'Show solution'**
  String get wsSolution;

  /// No description provided for @wsAllFound.
  ///
  /// In en, this message translates to:
  /// **'All words found!'**
  String get wsAllFound;

  /// No description provided for @crosswordBestTime.
  ///
  /// In en, this message translates to:
  /// **'Best time'**
  String get crosswordBestTime;

  /// No description provided for @crosswordEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy (8 words)'**
  String get crosswordEasy;

  /// No description provided for @crosswordHard.
  ///
  /// In en, this message translates to:
  /// **'Hard (16 words)'**
  String get crosswordHard;

  /// No description provided for @crosswordMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (12 words)'**
  String get crosswordMedium;

  /// No description provided for @crosswordTime.
  ///
  /// In en, this message translates to:
  /// **'Time (s)'**
  String get crosswordTime;

  /// No description provided for @btnProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get btnProgress;

  /// No description provided for @titPageProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get titPageProgress;

  /// No description provided for @infProgress.
  ///
  /// In en, this message translates to:
  /// **'Choose a category to view the progress of its words.'**
  String get infProgress;

  /// No description provided for @catFirstVerbs.
  ///
  /// In en, this message translates to:
  /// **'First Verbs'**
  String get catFirstVerbs;

  /// No description provided for @catGrpAlltag.
  ///
  /// In en, this message translates to:
  /// **'Everyday & Needs'**
  String get catGrpAlltag;

  /// No description provided for @catGrpMovement.
  ///
  /// In en, this message translates to:
  /// **'Movement & Stay'**
  String get catGrpMovement;

  /// No description provided for @catGrpLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning & Communication'**
  String get catGrpLearning;

  /// No description provided for @catGrpWork.
  ///
  /// In en, this message translates to:
  /// **'Action & Work'**
  String get catGrpWork;

  /// No description provided for @catGrpEnjoy.
  ///
  /// In en, this message translates to:
  /// **'Enjoyment & Help'**
  String get catGrpEnjoy;

  /// No description provided for @tensePast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tensePast;

  /// No description provided for @tensePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get tensePresent;

  /// No description provided for @tenseFuture.
  ///
  /// In en, this message translates to:
  /// **'Future'**
  String get tenseFuture;

  /// No description provided for @colWord.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get colWord;

  /// No description provided for @colLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get colLevel;

  /// No description provided for @labNewShort.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get labNewShort;

  /// No description provided for @labDueShort.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get labDueShort;

  /// No description provided for @labLearnedShort.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get labLearnedShort;

  /// No description provided for @msgSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed. The last progress could not be saved.'**
  String get msgSaveFailed;

  /// No description provided for @msgUserDataRecovered.
  ///
  /// In en, this message translates to:
  /// **'Your user data was damaged and has been restored from a backup.'**
  String get msgUserDataRecovered;

  /// No description provided for @msgUserDataUnloadable.
  ///
  /// In en, this message translates to:
  /// **'Your user data could not be loaded.'**
  String get msgUserDataUnloadable;

  /// No description provided for @msgAppDataRecovered.
  ///
  /// In en, this message translates to:
  /// **'App data was damaged. The user list was rebuilt from existing files.'**
  String get msgAppDataRecovered;

  /// No description provided for @msgAssetsCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Not all dictionaries could be copied on startup. The app may be incomplete.'**
  String get msgAssetsCopyFailed;

  /// No description provided for @btnHangman.
  ///
  /// In en, this message translates to:
  /// **'Hangman'**
  String get btnHangman;

  /// No description provided for @hangmanEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy — Translation'**
  String get hangmanEasy;

  /// No description provided for @hangmanMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium — Example (native)'**
  String get hangmanMedium;

  /// No description provided for @hangmanHard.
  ///
  /// In en, this message translates to:
  /// **'Hard — Example (target language)'**
  String get hangmanHard;

  /// No description provided for @hangmanLives.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get hangmanLives;

  /// No description provided for @hangmanWrongLetters.
  ///
  /// In en, this message translates to:
  /// **'Wrong letters:'**
  String get hangmanWrongLetters;

  /// No description provided for @hangmanRoundLost.
  ///
  /// In en, this message translates to:
  /// **'Round lost!'**
  String get hangmanRoundLost;

  /// No description provided for @hangmanRoundWon.
  ///
  /// In en, this message translates to:
  /// **'Round won!'**
  String get hangmanRoundWon;

  /// No description provided for @btnFillIn.
  ///
  /// In en, this message translates to:
  /// **'Fill In'**
  String get btnFillIn;

  /// No description provided for @fillInEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy (25 sentences)'**
  String get fillInEasy;

  /// No description provided for @fillInHard.
  ///
  /// In en, this message translates to:
  /// **'Hard (100 sentences)'**
  String get fillInHard;

  /// No description provided for @fillInMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (50 sentences)'**
  String get fillInMedium;

  /// No description provided for @fillInTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fillInTime;

  /// No description provided for @fillInBestTime.
  ///
  /// In en, this message translates to:
  /// **'Best time'**
  String get fillInBestTime;

  /// No description provided for @fillInPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get fillInPoints;

  /// No description provided for @fillInSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get fillInSkip;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @greek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get greek;

  /// No description provided for @motherTongueHint.
  ///
  /// In en, this message translates to:
  /// **'Sets the translation direction (word and translation) for all selected course languages.'**
  String get motherTongueHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'el',
        'en',
        'es',
        'fr',
        'it',
        'pt',
        'ru'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
