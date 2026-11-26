import '../routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/language_registry.dart';
import '../managers/user_state.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../services/pack_manager.dart';
import '../dialogs/login_dialog.dart';
import '../dialogs/create_user_dialog.dart';
import '../dialogs/info_dialog.dart';
import '../dialogs/confirm_dialog.dart';
import '../l10n/app_localizations.dart';

/// Main menu screen – 1:1 from startpage.py / startpage.kv.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _checked = false;
  String? _selectedCourseId;
  final Set<String> _expandedMyLanguages = {};
  final Set<String> _expandedNewLanguages = {};

  /// Installierte Sprachpakete (Marker-basiert, über den PackManager).
  Set<String> _installedPacks = {};
  bool _packsLoaded = false;

  /// Sprache, deren Paket gerade installiert/deinstalliert wird (Spinner).
  String? _busyPackCode;

  /// Aktuelle Installations-Phase pro Sprachcode (für die Fortschrittsanzeige).
  /// Wird vom `onProgress`-Callback von [PackManager.install] befüllt.
  final Map<String, PackInstallStep> _packInstallSteps = {};

  /// Zuletzt behandelte Muttersprache (Skip-Guard): jede Muttersprache wird pro
  /// Sitzung bzw. pro User-Wechsel GENAU EINMAL geprüft/installiert – verhindert
  /// Doppel-Downloads bei Rebuilds/Mehrfach-Triggers.
  String? _autoInstallHandledLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUser();
    if (!_packsLoaded) {
      _packsLoaded = true;
      _loadInstalledPacks();
    }
    // Muttersprache des eingeloggten Users (falls vorhanden) automatisch
    // installieren – nur wenn deren Sprachpaket noch fehlt, im Hintergrund.
    _autoInstallMotherTongue();
  }

  /// Lädt die installierten Sprachpakete (Marker-basiert, ohne Netzwerk).
  Future<void> _loadInstalledPacks() async {
    final packs = await context.read<PackManager>().installedPacks();
    if (!mounted) return;
    setState(() => _installedPacks = packs);
  }

  /// Installiert die Muttersprache des eingeloggten Users automatisch, wenn ihr
  /// Sprachpaket noch NICHT installiert ist. Läuft im Hintergrund und blockiert
  /// den Start-/Login-Flow nicht.
  ///
  /// Wichtige Regeln (Ticket #68, nächste Runde):
  /// - Ohne eingeloggten User bzw. ohne bekannte Muttersprache passiert NICHTS
  ///   (kein Download vor der Registrierung).
  /// - bereits installierte Pakete bleiben unangetastet (auch nach App-Update:
  ///   installierte Packs liegen im App-Speicher und werden beim Update nie
  ///   erneut heruntergeladen).
  /// - pro Muttersprache genau einmal prüfen (Skip-Guard [_autoInstallHandledLang]).
  Future<void> _autoInstallMotherTongue() async {
    if (_busyPackCode != null) return;
    final userState = context.read<UserState>();
    final mLang = userState.userData?.mLang;
    if (mLang == null || mLang.isEmpty) return;
    if (_autoInstallHandledLang == mLang) return; // schon behandelt
    _autoInstallHandledLang = mLang;

    final installed = await context.read<PackManager>().installedPacks();
    if (!mounted) return;
    setState(() => _installedPacks = installed);
    if (installed.contains(mLang)) return; // schon installiert → nichts tun

    // Muttersprache fehlt → einmalig im Hintergrund installieren.
    await _installPack(mLang);
  }

  void _checkUser() {
    if (_checked) return;
    final dataState = context.read<DataState>();
    final users = dataState.appData.registeredUser;
    if (users.isEmpty || !dataState.appData.stayLoggedIn) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (users.isEmpty) {
          _showCreateUser();
        } else {
          _showLogin();
        }
      });
    } else {
      _checked = true;
    }
  }

  /// Installiert das Sprachpaket für [code]: Download → SHA-256-Prüfung →
  /// Entpacken (PackManager). Danach werden Kurs-Katalog und Muttersprachen
  /// neu erkannt.
  Future<void> _installPack(String code) async {
    if (_busyPackCode != null) return;
    setState(() => _busyPackCode = code);
    final l10n = AppLocalizations.of(context);
    final packManager = context.read<PackManager>();
    final dataState = context.read<DataState>();
    final message = '${l10n.packInstall}: ${courseLanguageName(code)}';
    try {
      await packManager.install(code, onProgress: (step) {
        if (mounted) setState(() => _packInstallSteps[code] = step);
      });
      await _loadInstalledPacks();
      await dataState.refreshLanguages();
      if (mounted) _showSnack(message);
    } on PackException catch (e) {
      final String errorText;
      if (e.kind == PackErrorKind.sizeMismatch) {
        // Unvollständiger Download: erwartete/erhaltene Größe aus dem
        // `cause`-Record anzeigen (schneller Fehlerfall vor der SHA-Prüfung).
        final size = e.cause;
        if (size is ({int expected, int actual})) {
          errorText = l10n.packInstallSizeMismatch(size.expected, size.actual);
        } else {
          errorText = l10n.packInstallFailed(e.toString());
        }
      } else if (e.kind == PackErrorKind.appVersionTooLow) {
        // App zu alt: erforderliche min_app_version aus dem Manifest anzeigen.
        errorText = l10n.packInstallVersionTooLow(e.cause?.toString() ?? '');
      } else {
        errorText = l10n.packInstallFailed(e.toString());
      }
      if (mounted) _showSnack(errorText);
    } finally {
      if (mounted) {
        setState(() {
          _busyPackCode = null;
          _packInstallSteps.remove(code);
        });
      }
    }
  }

  /// Deinstalliert das Sprachpaket für [code] nach Bestätigung.
  Future<void> _uninstallPack(String code) async {
    if (_busyPackCode != null) return;
    final l10n = AppLocalizations.of(context);
    final packManager = context.read<PackManager>();
    final dataState = context.read<DataState>();
    final message = '${l10n.packUninstall}: ${courseLanguageName(code)}';
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.packUninstallTitle,
      message: l10n.packUninstallMsg(courseLanguageName(code)),
      confirmText: l10n.confirm,
      cancelText: l10n.chancel,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyPackCode = code);
    try {
      await packManager.uninstall(code);
      await _loadInstalledPacks();
      await dataState.refreshLanguages();
      if (mounted) _showSnack(message);
    } on PackException catch (e) {
      final errorText = l10n.packUninstallFailed(e.toString());
      if (mounted) _showSnack(errorText);
    } finally {
      if (mounted) setState(() => _busyPackCode = null);
    }
  }

  /// Hinweis-Banner für den Erststart: noch kein Sprachpaket installiert.
  Widget _packHintBanner() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.colorPrimary),
        borderRadius: BorderRadius.circular(6),
        color: AppTheme.colorPrimary.withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          const Icon(Icons.download, color: AppTheme.colorPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.packInstallHint,
              style: const TextStyle(
                  fontSize: AppTheme.smallFontSize, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogin() async {
    final dataState = context.read<DataState>();
    final l10n = AppLocalizations.of(context);
    final userState = context.read<UserState>();
    final result = await showLoginDialog(
      context,
      dataState.appData.registeredUser,
      l10n.btnChangeUser,
      l10n.btnAddUser,
      l10n.chancel,
    );
    if (result == null) return;
    if (result == '__add__') {
      await _showCreateUser();
    } else {
      final error = await userState.login(result);
      if (!mounted) return;
      if (error != null) {
        _showSnack(error);
        return;
      }
      await dataState.loadAppData();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _showCreateUser() async {
    final dataState = context.read<DataState>();
    final l10n = AppLocalizations.of(context);
    final userState = context.read<UserState>();
    // Muttersprachen-Auswahl: ALLE nachinstallierbaren Sprach-Kandidaten (nicht
    // nur bereits installierte Dicts) – damit sich der allererste User VOR dem
    // ersten Pack-Download registrieren kann; danach installiert die App dessen
    // Muttersprache automatisch (siehe _autoInstallMotherTongue).
    final motherTongueCodes = List<String>.of(courseCandidateCodes)
      ..sort((a, b) => courseLanguageName(a).compareTo(courseLanguageName(b)));
    final motherTongueLabels = [
      for (final code in motherTongueCodes) courseLanguageName(code),
    ];
    final result = await showCreateUserDialog(
      context,
      l10n.uRegistration,
      l10n.infUserReg,
      l10n.mLang,
      motherTongueCodes,
      motherTongueLabels,
      l10n.confirm,
      l10n.chancel,
    );
    if (result == null) return;
    final error =
        await userState.registerUser(result['username']!, result['m_lang']!);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
      return;
    }
    await dataState.loadAppData();
    if (!mounted) return;
    setState(() {});
  }

  /// Einmalige, dezente Hinweis-Anzeige nach einer Nutzeraktion (kein Dialog,
  /// kein Dauer-Spam – nur ein SnackBar pro Aktion).
  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRemoveCourse(String courseId) async {
    final userState = context.read<UserState>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.titRemoveCourse,
      message: l10n.msgRemoveCourse,
      confirmText: l10n.confirm,
      cancelText: l10n.chancel,
    );
    if (confirmed != true || !mounted) return;
    await userState.removeCourse(courseId);
    if (!mounted) return;
    setState(() {
      if (_selectedCourseId == courseId) _selectedCourseId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataState = context.watch<DataState>();
    final userState = context.watch<UserState>();
    final l10n = AppLocalizations.of(context);
    final courses = userState.selectedCourses;
    final newCourses = userState.availableNewCourses;
    final selectedCourse =
        _selectedCourseId != null ? availableCourses[_selectedCourseId] : null;
    // Alle potenziellen Kurssprachen (inkl. noch nicht installierter Packs).
    final allLangCodes = List<String>.of(courseCandidateCodes)
      ..sort((a, b) => courseLanguageName(a).compareTo(courseLanguageName(b)));

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: l10n.titPageStart,
            onInfo: () =>
                showInfoDialog(context, l10n.infStart, l10n.information),
          ),
          Expanded(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isPortrait = orientation == Orientation.portrait;
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.contentPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── UserInfoBox (top, full width) – nur Portrait.
                        // Im Landscape ist sie Teil der 3-Spalten-Gruppe.
                        if (isPortrait &&
                            dataState.appData.loggedUName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.contentSpacing),
                            child: _UserInfoBox(),
                          ),
                        const SizedBox(height: 16),
                        // ── Erststart-Hinweis: noch kein Sprachpaket ──
                        if (_packsLoaded && _installedPacks.isEmpty) ...[
                          _packHintBanner(),
                          const SizedBox(height: AppTheme.contentSpacing),
                        ],
                        // ── Course detail or Meine Kurse + Neue Kurse ──
                        if (selectedCourse != null)
                          _CourseDetailView(
                            course: selectedCourse,
                            onBack: () =>
                                setState(() => _selectedCourseId = null),
                            hasContent:
                                userState.courseHasContent(selectedCourse),
                          )
                        else ...[
                          if (isPortrait) ...[
                            // ── Meine Kurse ──
                            _MyCoursesSection(
                              courses: courses,
                              selectedId: _selectedCourseId,
                              expandedLanguages: _expandedMyLanguages,
                              onTap: (id) => setState(() {
                                _selectedCourseId =
                                    _selectedCourseId == id ? null : id;
                              }),
                              onRemove: _confirmRemoveCourse,
                              onToggleLanguage: (code) => setState(() {
                                if (!_expandedMyLanguages.add(code)) {
                                  _expandedMyLanguages.remove(code);
                                }
                              }),
                            ),
                            const SizedBox(height: AppTheme.contentSpacing),
                            // ── Neue Kurse ──
                            _NewLanguagesSection(
                              courses: newCourses,
                              allLangCodes: allLangCodes,
                              installedCodes: _installedPacks,
                              busyCode: _busyPackCode,
                              installSteps: _packInstallSteps,
                              expandedLanguages: _expandedNewLanguages,
                              onAdd: (id) async {
                                await userState.addCourse(id);
                                if (mounted) setState(() {});
                              },
                              onToggleLanguage: (code) => setState(() {
                                if (!_expandedNewLanguages.add(code)) {
                                  _expandedNewLanguages.remove(code);
                                }
                              }),
                              onInstall: _installPack,
                              onUninstall: _uninstallPack,
                            ),
                          ] else ...[
                            // Landscape: UserInfoBox + Meine Kurse + Neue
                            // Kurse nebeneinander (3 Spalten).
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dataState
                                    .appData.loggedUName.isNotEmpty) ...[
                                  Expanded(
                                    flex: 3,
                                    child: _UserInfoBox(),
                                  ),
                                  const SizedBox(
                                      width: AppTheme.contentSpacing),
                                ],
                                Expanded(
                                  flex: 4,
                                  child: _MyCoursesSection(
                                    courses: courses,
                                    selectedId: _selectedCourseId,
                                    expandedLanguages: _expandedMyLanguages,
                                    onTap: (id) => setState(() {
                                      _selectedCourseId =
                                          _selectedCourseId == id ? null : id;
                                    }),
                                    onRemove: _confirmRemoveCourse,
                                    onToggleLanguage: (code) => setState(() {
                                      if (!_expandedMyLanguages.add(code)) {
                                        _expandedMyLanguages.remove(code);
                                      }
                                    }),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.contentSpacing),
                                Expanded(
                                  flex: 5,
                                  child: _NewLanguagesSection(
                                    courses: newCourses,
                                    allLangCodes: allLangCodes,
                                    installedCodes: _installedPacks,
                                    busyCode: _busyPackCode,
                                    installSteps: _packInstallSteps,
                                    expandedLanguages: _expandedNewLanguages,
                                    onAdd: (id) async {
                                      await userState.addCourse(id);
                                      if (mounted) setState(() {});
                                    },
                                    onToggleLanguage: (code) => setState(() {
                                      if (!_expandedNewLanguages.add(code)) {
                                        _expandedNewLanguages.remove(code);
                                      }
                                    }),
                                    onInstall: _installPack,
                                    onUninstall: _uninstallPack,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          BoxBottom(
            onSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onExit: AppTheme.closeApp,
          ),
        ],
      ),
    );
  }
}

/// User info box with stats – extracted as separate widget for efficiency.
/// Subscribes to the global [routeObserver] and refreshes the stats via
/// [RouteAware.didPopNext] whenever a route on top is popped back to it.
class _UserInfoBox extends StatefulWidget {
  @override
  State<_UserInfoBox> createState() => _UserInfoBoxState();
}

class _UserInfoBoxState extends State<_UserInfoBox> with RouteAware {
  bool _subscribed = false;

  /// Gecachte Stats-Future: wird NUR neu erzeugt, wenn sich der Benutzer
  /// oder [NavigationState.statsVersion] aendert. Ein Rebuild ohne solche
  /// Aenderung (Orientierung, Locale, Parent-setState) laedt nicht neu.
  Future<UserStats>? _statsFuture;
  String? _statsUser;
  int? _statsVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_subscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route);
        _subscribed = true;
      }
    }
  }

  @override
  void didPopNext() {
    context.read<NavigationState>().notifyStatsChanged();
  }

  @override
  void dispose() {
    if (_subscribed) routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataState = context.watch<DataState>();
    final navState = context.watch<NavigationState>();
    final l10n = AppLocalizations.of(context);
    final username = dataState.appData.loggedUName;

    if (username.isEmpty) {
      _statsFuture = null;
      _statsUser = null;
      _statsVersion = null;
      return const SizedBox.shrink();
    }
    final version = navState.statsVersion;
    if (_statsFuture == null ||
        _statsUser != username ||
        _statsVersion != version) {
      _statsFuture = context.read<VocabQueries>().getUserStats(username);
      _statsUser = username;
      _statsVersion = version;
    }

    return FutureBuilder<UserStats>(
        future: _statsFuture,
        builder: (ctx, snapshot) {
          final stats = snapshot.data;
          if (stats == null) {
            return const SizedBox.shrink();
          }
          return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(border: Border.all(color: AppTheme.grey3)),
              child: _buildBoxBody(l10n, stats, username));
        });
  }

  Widget _buildBoxBody(
      AppLocalizations l10n, UserStats stats, String username) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final statsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(username,
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: Color(0xFFFFB31A))),
        Text('${l10n.catNewWords}: ${stats.newCount}',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: Colors.white70)),
        Text('${l10n.catDueWords}: ${stats.dueCount}',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: Colors.white70)),
        Text('${l10n.catReadWords}: ${stats.readCount}',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: Colors.white70)),
        Text('${l10n.catLearnedWords}: ${stats.learnedCount}',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: Colors.white70)),
        if (stats.streak.current > 0)
          Text(l10n.streakAndRecord(stats.streak.current, stats.streak.longest),
              style: const TextStyle(
                  fontSize: AppTheme.smallFontSize, color: Color(0xFFFFB31A))),
      ],
    );
    final buttonsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionOutlined(l10n.btnProgress, () {
          Navigator.of(context).pushNamed(AppRoutes.progress);
        }),
        const SizedBox(height: 8),
        _actionOutlined(l10n.btnChangeUser, () {
          final st = context.findAncestorStateOfType<_StartScreenState>();
          st?._showLogin();
        }),
      ],
    );
    if (isPortrait) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: statsCol),
          const SizedBox(width: 10),
          SizedBox(width: 170, child: buttonsCol),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        statsCol,
        const SizedBox(height: 6),
        buttonsCol,
      ],
    );
  }

  Widget _actionOutlined(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
        foregroundColor: AppTheme.grey5,
        side: const BorderSide(color: AppTheme.grey3),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child:
          Text(label, style: const TextStyle(fontSize: AppTheme.smallFontSize)),
    );
  }
}

/// Vertical list of the user's courses, grouped by language with foldable levels.
class _MyCoursesSection extends StatelessWidget {
  final List<LanguageCourse> courses;
  final String? selectedId;
  final Set<String> expandedLanguages;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onToggleLanguage;

  const _MyCoursesSection({
    required this.courses,
    required this.selectedId,
    required this.expandedLanguages,
    required this.onTap,
    required this.onRemove,
    required this.onToggleLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.grey3)),
        child: Text(l10n.noCourses,
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      );
    }
    final grouped = _groupByLanguage(courses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.myCourses,
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize, color: AppTheme.colorPrimary)),
        const SizedBox(height: 8),
        ...grouped.entries.map((entry) {
          final code = entry.key;
          final langCourses = entry.value;
          final expanded = expandedLanguages.contains(code);
          final first = langCourses.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: [
              // ── Language header ──
              GestureDetector(
                onTap: () => onToggleLanguage(code),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.grey3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Image.asset(first.flagAsset, width: 32, height: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        first.languageName,
                        style: const TextStyle(
                            fontSize: AppTheme.infFontSize,
                            color: Colors.white),
                      ),
                    ),
                    if (expanded)
                      const Icon(Icons.expand_more,
                          color: AppTheme.grey4, size: 20),
                    if (!expanded)
                      const Icon(Icons.chevron_right,
                          color: AppTheme.grey4, size: 20),
                  ]),
                ),
              ),
              // ── Sub-levels (only when expanded) ──
              if (expanded) ...[
                const SizedBox(height: 4),
                ...langCourses.map((c) {
                  final selected = c.id == selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 6),
                    child: GestureDetector(
                      onTap: () => onTap(c.id),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? AppTheme.colorPrimary
                                : AppTheme.grey3,
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: Row(children: [
                          Text(
                            c.level,
                            style: const TextStyle(
                                fontSize: AppTheme.infFontSize,
                                color: Colors.white),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                color: AppTheme.colorPrimary, size: 18),
                          const Expanded(child: SizedBox.shrink()),
                          IconButton(
                            onPressed: () => onRemove(c.id),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppTheme.grey4, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                            tooltip: l10n.titRemoveCourse,
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ],
            ]),
          );
        }),
      ],
    );
  }

  /// Groups courses by their language code.
  static Map<String, List<LanguageCourse>> _groupByLanguage(
      List<LanguageCourse> courses) {
    final map = <String, List<LanguageCourse>>{};
    for (final c in courses) {
      (map[c.languageCode] ??= []).add(c);
    }
    return map;
  }
}

/// Course detail view with Lern/Spiele/Grammatik buttons.
/// Buttons are disabled when [hasContent] is false (no words/grammar for this level yet).
class _CourseDetailView extends StatelessWidget {
  final LanguageCourse course;
  final VoidCallback onBack;
  final bool hasContent;

  const _CourseDetailView({
    required this.course,
    required this.onBack,
    required this.hasContent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.colorPrimary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.asset(course.flagAsset, width: 32, height: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${course.languageName} ${course.level}',
                  style: const TextStyle(
                      fontSize: AppTheme.lblFontSize,
                      color: AppTheme.colorPrimary)),
            ),
            TextButton(
              onPressed: onBack,
              child: Text(l10n.back,
                  style: const TextStyle(
                      fontSize: AppTheme.smallFontSize,
                      color: AppTheme.colorPrimary)),
            ),
          ]),
          const SizedBox(height: 12),
          if (!hasContent)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.grey2.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.noContentYet,
                style: const TextStyle(
                    fontSize: AppTheme.smallFontSize, color: AppTheme.grey4),
              ),
            ),
          if (!hasContent) const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasContent
                  ? () {
                      context.read<NavigationState>().setActiveCourse(course);
                      context.read<NavigationState>().setWordMode('new');
                      Navigator.of(context).pushNamed(AppRoutes.learning);
                    }
                  : null,
              child: Text(l10n.btnLearn,
                  style: const TextStyle(fontSize: AppTheme.btnFontSize)),
            ),
          ),
          const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasContent
                  ? () {
                      context.read<NavigationState>().setActiveCourse(course);
                      Navigator.of(context).pushNamed(AppRoutes.gamechoose);
                    }
                  : null,
              child: Text(l10n.btnGame,
                  style: const TextStyle(fontSize: AppTheme.btnFontSize)),
            ),
          ),
          const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasContent
                  ? () {
                      context.read<NavigationState>().setActiveCourse(course);
                      Navigator.of(context).pushNamed(
                        AppRoutes.grammar,
                        arguments: course.level,
                      );
                    }
                  : null,
              child: Text(l10n.btnGrammar,
                  style: const TextStyle(fontSize: AppTheme.btnFontSize)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing available new language courses, grouped by language with foldable levels.
class _NewLanguagesSection extends StatelessWidget {
  final List<LanguageCourse> courses;
  final List<String> allLangCodes;
  final Set<String> installedCodes;
  final String? busyCode;

  /// Aktuelle Installations-Phase pro Sprachcode (für die Schritt-Anzeige).
  final Map<String, PackInstallStep> installSteps;

  final Set<String> expandedLanguages;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onToggleLanguage;
  final ValueChanged<String> onInstall;
  final ValueChanged<String> onUninstall;

  const _NewLanguagesSection({
    required this.courses,
    required this.allLangCodes,
    required this.installedCodes,
    this.busyCode,
    required this.installSteps,
    required this.expandedLanguages,
    required this.onAdd,
    required this.onToggleLanguage,
    required this.onInstall,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = _groupByLanguage(courses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.catNewLang,
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize, color: AppTheme.colorPrimary)),
        const SizedBox(height: 8),
        // Pro Kurssprache: nicht installiert → Install-Zeile, installiert →
        // aufklappbare Kurs-Gruppe.
        for (final code in allLangCodes)
          if (!installedCodes.contains(code))
            _notInstalledRow(context, code)
          else if (grouped.containsKey(code))
            _languageGroup(context, code, grouped[code]!),
      ],
    );
  }

  /// Lokalisierte Bezeichnung der aktuellen Installations-Phase. Fallback auf
  /// den Download, solange der `onProgress`-Callback noch nicht gefeuert hat
  /// (dieser läuft in `install()` synchron vor dem ersten `await`, der
  /// Übergang von „busy“ zu „Schritt sichtbar“ ist also praktisch sofort).
  String _stepLabel(AppLocalizations l10n, PackInstallStep? step) {
    switch (step ?? PackInstallStep.downloading) {
      case PackInstallStep.downloading:
        return l10n.packStepDownloading;
      case PackInstallStep.verifying:
        return l10n.packStepVerifying;
      case PackInstallStep.extracting:
        return l10n.packStepExtracting;
    }
  }

  /// Zeile für eine Sprache ohne installiertes Sprachpaket (Install-Button).
  Widget _notInstalledRow(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    final busy = busyCode == code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey3),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Image.asset(courseFlagAsset(code), width: 32, height: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(courseLanguageName(code),
                style: const TextStyle(
                    fontSize: AppTheme.infFontSize, color: Colors.white)),
          ),
          if (busy) ...[
            // Aktueller Installations-Schritt links neben dem Spinner.
            Text(
              _stepLabel(l10n, installSteps[code]),
              style: const TextStyle(
                  fontSize: AppTheme.smallFontSize, color: AppTheme.grey4),
            ),
            const SizedBox(width: 8),
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
          ] else
            OutlinedButton(
              onPressed: () => onInstall(code),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 30),
                side: const BorderSide(color: AppTheme.colorPrimary),
                foregroundColor: AppTheme.colorPrimary,
              ),
              child: Text(l10n.packInstall,
                  style: const TextStyle(fontSize: AppTheme.smallFontSize)),
            ),
        ]),
      ),
    );
  }

  /// Sprachgruppe einer installierten Sprache: Header mit Deinstall-Icon und
  /// aufklappbare Kurs-Levels.
  Widget _languageGroup(BuildContext context, String code,
      List<LanguageCourse> langCourses) {
    final l10n = AppLocalizations.of(context);
    final expanded = expandedLanguages.contains(code);
    final first = langCourses.first;
    final busy = busyCode == code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        // ── Language header ──
        GestureDetector(
          onTap: () => onToggleLanguage(code),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.grey3),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Image.asset(first.flagAsset, width: 32, height: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  first.languageName,
                  style: const TextStyle(
                      fontSize: AppTheme.infFontSize, color: Colors.white),
                ),
              ),
              if (busy) ...[
                // Aktueller Installations-Schritt links neben dem Spinner.
                Text(
                  _stepLabel(l10n, installSteps[code]),
                  style: const TextStyle(
                      fontSize: AppTheme.smallFontSize,
                      color: AppTheme.grey4),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
              ] else
                IconButton(
                  onPressed: () => onUninstall(code),
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.grey4, size: 20),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: l10n.packUninstall,
                ),
              if (expanded)
                const Icon(Icons.expand_more, color: AppTheme.grey4, size: 20),
              if (!expanded)
                const Icon(Icons.chevron_right,
                    color: AppTheme.grey4, size: 20),
            ]),
          ),
        ),
        // ── Sub-levels (only when expanded) ──
        if (expanded) ...[
          const SizedBox(height: 4),
          ...langCourses.map((c) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: GestureDetector(
                onTap: () => onAdd(c.id),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.grey3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(children: [
                    Text(
                      c.level,
                      style: const TextStyle(
                          fontSize: AppTheme.infFontSize, color: Colors.white),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    const Icon(Icons.add_circle_outline,
                        color: AppTheme.colorPrimary, size: 18),
                  ]),
                ),
              ),
            );
          }),
        ],
      ]),
    );
  }

  /// Groups courses by their language code.
  static Map<String, List<LanguageCourse>> _groupByLanguage(
      List<LanguageCourse> courses) {
    final map = <String, List<LanguageCourse>>{};
    for (final c in courses) {
      (map[c.languageCode] ??= []).add(c);
    }
    return map;
  }
}
