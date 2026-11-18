import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../managers/user_state.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUser();
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
      await userState.login(result);
      if (!mounted) return;
      await dataState.loadAppData();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _showCreateUser() async {
    final dataState = context.read<DataState>();
    final l10n = AppLocalizations.of(context);
    final userState = context.read<UserState>();
    final result = await showCreateUserDialog(
      context,
      l10n.uRegistration,
      l10n.infUserReg,
      l10n.mLang,
      l10n.german,
      l10n.english,
      l10n.confirm,
      l10n.chancel,
    );
    if (result == null) return;
    await userState.registerUser(result['username']!, result['m_lang']!);
    if (!mounted) return;
    await dataState.loadAppData();
    if (!mounted) return;
    setState(() {});
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
    final selectedCourse = _selectedCourseId != null
        ? availableCourses[_selectedCourseId]
        : null;

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: l10n.titPageStart,
            onInfo: () => showInfoDialog(
                context,
                l10n.infStart,
                l10n.information),
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
                        if (isPortrait && dataState.appData.loggedUName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.contentSpacing),
                            child: _UserInfoBox(),
                          ),
                        const SizedBox(height: 16),
                        // ── Course detail or Meine Kurse + Neue Kurse ──
                        if (selectedCourse != null)
                          _CourseDetailView(
                            course: selectedCourse,
                            onBack: () =>
                                setState(() => _selectedCourseId = null),
                            hasContent: userState.courseHasContent(selectedCourse),
                          )
                        else ...[
                          if (isPortrait) ...[
                            // ── Meine Kurse ──
                            _MyCoursesSection(
                              courses: courses,
                              selectedId: _selectedCourseId,
                              onTap: (id) => setState(() {
                                _selectedCourseId =
                                    _selectedCourseId == id
                                        ? null
                                        : id;
                              }),
                              onRemove: _confirmRemoveCourse,
                            ),
                            const SizedBox(height: AppTheme.contentSpacing),
                            // ── Neue Kurse ──
                            _NewLanguagesSection(
                              courses: newCourses,
                              onAdd: (id) async {
                                await userState.addCourse(id);
                                if (mounted) setState(() {});
                              },
                            ),
                          ] else ...[
                            // Landscape: UserInfoBox + Meine Kurse + Neue
                            // Kurse nebeneinander (3 Spalten).
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dataState.appData.loggedUName.isNotEmpty) ...[
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
                                    onTap: (id) => setState(() {
                                      _selectedCourseId =
                                          _selectedCourseId == id
                                              ? null
                                              : id;
                                    }),
                                    onRemove: _confirmRemoveCourse,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.contentSpacing),
                                Expanded(
                                  flex: 5,
                                  child: _NewLanguagesSection(
                                    courses: newCourses,
                                    onAdd: (id) async {
                                      await userState.addCourse(id);
                                      if (mounted) setState(() {});
                                    },
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
            settingsText: l10n.settings,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
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

    if (username.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<_UserStats>(
        key: ValueKey('userinfo_${username}_${navState.statsVersion}'),
        future: _loadStats(context, username),
        builder: (ctx, snapshot) {
          final stats = snapshot.data;
          if (stats == null) {
            return const SizedBox.shrink();
          }
          return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey3)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Color(0xFFFFB31A))),
                    Text(
                        '${l10n.catNewWords}: ${stats.newCount}',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white70)),
                    Text(
                        '${l10n.catDueWords}: ${stats.dueCount}',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white70)),
                    Text(
                        '${l10n.catLearnedWords}: ${stats.learnedCount}',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white70)),
                    if (stats.streak.current > 0)
                      Text(l10n.streakAndRecord(stats.streak.current, stats.streak.longest),
                          style: const TextStyle(
                              fontSize: AppTheme.smallFontSize,
                              color: Color(0xFFFFB31A))),
                    const SizedBox(height: 4),
                    SizedBox(
                        height: 20,
                        child: TextButton(
                            onPressed: () {
                              final st = ctx
                                  .findAncestorStateOfType<_StartScreenState>();
                              st?._showLogin();
                            },
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: AppTheme.grey4),
                            child: Text(
                                l10n.btnChangeUser,
                                style: const TextStyle(
                                    fontSize: AppTheme.smallFontSize)))),
                  ]));
        });
  }

  Future<_UserStats> _loadStats(BuildContext context, String username) async {
    final vq = context.read<VocabQueries>();
    final nc = await vq.getNewWordsCount(username);
    final dc = await vq.getWordsDueCount(username);
    final mastered = await vq.getMasteredWords(username);
    final st = await vq.getDayStreak(username);
    return _UserStats(
      newCount: nc,
      dueCount: dc,
      learnedCount: mastered.length,
      streak: st,
    );
  }
}

/// Vertical list of the user's courses (portrait) or side-by-side card (landscape).
class _MyCoursesSection extends StatelessWidget {
  final List<LanguageCourse> courses;
  final String? selectedId;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;

  const _MyCoursesSection({
    required this.courses,
    required this.selectedId,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration:
            BoxDecoration(border: Border.all(color: AppTheme.grey3)),
        child: Text(l10n.noCourses,
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.myCourses,
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize,
                color: AppTheme.colorPrimary)),
        const SizedBox(height: 8),
        ...courses.map((c) {
          final selected = c.id == selectedId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onTap(c.id),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? AppTheme.colorPrimary : AppTheme.grey3,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Image.asset(c.flagAsset, width: 32, height: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.languageName} ${c.level}',
                            style: const TextStyle(
                                fontSize: AppTheme.infFontSize,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: AppTheme.colorPrimary, size: 20),
                    IconButton(
                      onPressed: () => onRemove(c.id),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.grey4, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      tooltip: l10n.titRemoveCourse,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
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
              child: Text(
                  '${course.languageName} ${course.level}',
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
                    fontSize: AppTheme.smallFontSize,
                    color: AppTheme.grey4),
              ),
            ),
          if (!hasContent) const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasContent
                  ? () {
                      context.read<NavigationState>().setWordMode('new');
                      Navigator.of(context).pushNamed('/learning');
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
                  ? () => Navigator.of(context).pushNamed('/gamechoose')
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
                  ? () => Navigator.of(context).pushNamed(
                        '/grammar',
                        arguments: course.level,
                      )
                  : null,
              child: Text(
                  l10n.btnGrammar,
                  style: const TextStyle(
                      fontSize: AppTheme.btnFontSize)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing available new language courses to discover.
class _NewLanguagesSection extends StatelessWidget {
  final List<LanguageCourse> courses;
  final ValueChanged<String> onAdd;

  const _NewLanguagesSection({
    required this.courses,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(l10n.noNewLang,
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.catNewLang,
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize,
                color: AppTheme.colorPrimary)),
        const SizedBox(height: 8),
        ...courses.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onAdd(c.id),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey3),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Image.asset(c.flagAsset, width: 32, height: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.languageName} ${c.level}',
                            style: const TextStyle(
                                fontSize: AppTheme.infFontSize,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_outline,
                        color: AppTheme.colorPrimary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Typed container for user stats used by FutureBuilder.
class _UserStats {
  final int newCount;
  final int dueCount;
  final int learnedCount;
  final DayStreak streak;
  const _UserStats({
    required this.newCount,
    required this.dueCount,
    required this.learnedCount,
    required this.streak,
  });
}
