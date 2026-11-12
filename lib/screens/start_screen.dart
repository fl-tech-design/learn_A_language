import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../managers/app_state.dart';
import '../managers/vocab_queries.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/login_dialog.dart';
import '../dialogs/create_user_dialog.dart';
import '../dialogs/info_dialog.dart';

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
    final appState = context.read<AppState>();
    if (appState.needsUserCheck) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final users = appState.appData.registeredUser;
        if (users.isEmpty) {
          _showCreateUser();
        } else if (!appState.appData.stayLoggedIn) {
          _showLogin();
        }
      });
    }
  }

  Future<void> _showLogin() async {
    final appState = context.read<AppState>();
    final bt = appState.baseTxt;
    final result = await showLoginDialog(
      context,
      appState.appData.registeredUser,
      bt['btn_change_user']?.toString() ?? 'Benutzer wechseln',
      bt['btn_add_user']?.toString() ?? '+ Neuer User',
      bt['chancel']?.toString() ?? 'abbrechen',
    );
    if (result == null) return;
    if (result == '__add__') {
      _showCreateUser();
    } else {
      await appState.login(result);
      setState(() {});
    }
  }

  Future<void> _showCreateUser() async {
    final appState = context.read<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final result = await showCreateUserDialog(
      context,
      bt['u_registration']?.toString() ?? 'Benutzer registrieren',
      bt['inf_user_reg']?.toString() ?? 'Bitte einen Benutzername eingeben.',
      at['m_lang']?.toString() ?? 'Muttersprache',
      bt['german']?.toString() ?? 'Deutsch',
      bt['english']?.toString() ?? 'English',
      bt['confirm']?.toString() ?? 'bestätigen',
      bt['chancel']?.toString() ?? 'abbrechen',
    );
    if (result == null) return;
    await appState.registerUser(result['username']!, result['m_lang']!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final courses = appState.selectedCourses;
    final newCourses = appState.availableNewCourses;
    final selectedCourse = _selectedCourseId != null
        ? availableCourses[_selectedCourseId]
        : null;

    return Scaffold(
      body: Column(
        children: [
          BoxTitle(
            title: bt['tit_page_start']?.toString() ?? 'Startseite',
            onInfo: () => showInfoDialog(
                context,
                bt['inf_start']?.toString() ?? '',
                bt['information']?.toString() ?? 'Information'),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: UserInfo + Meine Kurse ──
                      if (appState.loggedUName.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                at['my_courses']?.toString() ??
                                    'Meine Sprachen',
                                style: const TextStyle(
                                    fontSize: AppTheme.lblFontSize,
                                    color: AppTheme.colorPrimary)),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 2,
                                    child: _UserInfoBox()),
                                const SizedBox(
                                    width: AppTheme.contentSpacing),
                                Expanded(
                                  flex: 3,
                                  child: _MyCoursesSection(
                                    courses: courses,
                                    selectedId: _selectedCourseId,
                                    onTap: (id) => setState(() {
                                      _selectedCourseId =
                                          _selectedCourseId == id
                                              ? null
                                              : id;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // ── Bottom section: Course detail or New languages ──
                      if (selectedCourse != null)
                        _CourseDetailView(
                          course: selectedCourse,
                          at: at,
                          bt: bt,
                          onBack: () =>
                              setState(() => _selectedCourseId = null),
                        )
                      else
                        _NewLanguagesSection(
                          courses: newCourses,
                          at: at,
                          bt: bt,
                          onAdd: (id) async {
                            await appState.addCourse(id);
                            if (mounted) setState(() {});
                          },
                        ),
                    ]),
              ),
            ),
          ),
          BoxBottom(
            settingsText: bt['settings']?.toString() ?? 'Einstellungen',
            exitText: bt['exit']?.toString() ?? 'Beenden',
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
            onExit: AppTheme.closeApp,
          ),
        ],
      ),
    );
  }
}

/// User info box with stats – extracted as separate widget for efficiency.
class _UserInfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final username = appState.loggedUName;

    if (username.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
        key: ValueKey('userinfo_${username}_${appState.statsVersion}'),
        future: _loadStats(username),
        builder: (ctx, snapshot) {
          final stats = snapshot.data ?? {};
          final s = stats['streak'] as Map<String, dynamic>? ?? {};
          return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey3, width: 1)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Color(0xFFFFB31A))),
                    Text(
                        '${at['cat_new_words'] ?? 'Neue Wörter'}: ${stats['new'] ?? 0}',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white70)),
                    Text(
                        '${at['cat_due_words'] ?? 'Fällige Wörter'}: ${stats['due'] ?? 0}',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white70)),
                    if ((s['current'] ?? 0) > 0)
                      Text('Tag ${s['current']}  |  Rekord: ${s['longest']}',
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
                                bt['btn_change_user'] ?? 'User wechseln',
                                style: const TextStyle(
                                    fontSize: AppTheme.smallFontSize)))),
                  ]));
        });
  }

  Future<Map<String, dynamic>> _loadStats(String username) async {
    final nc = await VocabQueries.getNewWordsCount(username);
    final dc = await VocabQueries.getWordsDueCount(username);
    final st = await VocabQueries.getDayStreak(username);
    return {'new': nc, 'due': dc, 'streak': st};
  }
}

/// Horizontal scrollable list of the user's courses.
class _MyCoursesSection extends StatelessWidget {
  final List<LanguageCourse> courses;
  final String? selectedId;
  final ValueChanged<String> onTap;

  const _MyCoursesSection({
    required this.courses,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final at = context.read<AppState>().appTxt;
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration:
            BoxDecoration(border: Border.all(color: AppTheme.grey3, width: 1)),
        child: Text(at['no_courses']?.toString() ?? 'Keine Kurse',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final c = courses[i];
          final selected = c.id == selectedId;
          return GestureDetector(
            onTap: () => onTap(c.id),
            child: Container(
              width: 110,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppTheme.colorPrimary : AppTheme.grey3,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(c.flagAsset, width: 36, height: 24),
                  const SizedBox(height: 4),
                  Text(c.languageName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: AppTheme.smallFontSize,
                          color: Colors.white)),
                  Text('${c.level} - ${c.category}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.grey4)),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.arrow_drop_down,
                          color: AppTheme.colorPrimary, size: 16),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
/// Course detail view with Lern/Spiele/Grammatik buttons.
class _CourseDetailView extends StatelessWidget {
  final LanguageCourse course;
  final Map<String, dynamic> at;
  final Map<String, dynamic> bt;
  final VoidCallback onBack;

  const _CourseDetailView({
    required this.course,
    required this.at,
    required this.bt,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
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
                  '${course.languageName} ${course.level} - ${course.category}',
                  style: const TextStyle(
                      fontSize: AppTheme.lblFontSize,
                      color: AppTheme.colorPrimary)),
            ),
            TextButton(
              onPressed: onBack,
              child: Text(bt['back'] ?? 'zurück',
                  style: const TextStyle(
                      fontSize: AppTheme.smallFontSize,
                      color: AppTheme.colorPrimary)),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.read<AppState>().setWordMode('new');
                Navigator.of(context).pushNamed('/learning');
              },
              child: Text(at['btn_learn'] ?? 'Lernen',
                  style: const TextStyle(fontSize: AppTheme.btnFontSize)),
            ),
          ),
          const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/gameselect'),
              child: Text(at['btn_game'] ?? 'Spiele',
                  style: const TextStyle(fontSize: AppTheme.btnFontSize)),
            ),
          ),
          const SizedBox(height: AppTheme.contentSpacing),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              child: Text(
                  at['btn_grammar']?.toString() ?? 'Grammatik',
                  style: const TextStyle(
                      fontSize: AppTheme.btnFontSize,
                      color: AppTheme.grey4)),
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
  final Map<String, dynamic> at;
  final Map<String, dynamic> bt;
  final ValueChanged<String> onAdd;

  const _NewLanguagesSection({
    required this.courses,
    required this.at,
    required this.bt,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey3, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(at['no_new_lang']?.toString() ?? 'Keine neuen Sprachen verfügbar',
            style: const TextStyle(
                fontSize: AppTheme.smallFontSize, color: AppTheme.grey4)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(at['cat_new_lang']?.toString() ?? 'Neue Sprachen entdecken',
            style: const TextStyle(
                fontSize: AppTheme.lblFontSize,
                color: AppTheme.colorPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: courses.map((c) {
            return GestureDetector(
              onTap: () => onAdd(c.id),
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey3, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(c.flagAsset, width: 36, height: 24),
                    const SizedBox(height: 4),
                    Text(c.languageName,
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white)),
                    Text('${c.level} - ${c.category}',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.grey4)),
                    const SizedBox(height: 4),
                    const Icon(Icons.add_circle_outline,
                        color: AppTheme.colorPrimary, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
