import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
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
      bt['u_login']?.toString() ?? 'Login',
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
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.contentPadding),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _UserInfoBox(),
                const SizedBox(height: AppTheme.contentSpacing),
                SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: () {
                          appState.setWordMode('new');
                          Navigator.of(context).pushNamed('/learning');
                        },
                        child: Text(at['btn_learn'] ?? 'Lernen',
                            style: const TextStyle(
                                fontSize: AppTheme.btnFontSize)))),
                const SizedBox(height: AppTheme.contentSpacing),
                SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/gameselect'),
                        child: Text(at['btn_game'] ?? 'Spiele',
                            style: const TextStyle(
                                fontSize: AppTheme.btnFontSize)))),
                const Spacer(),
              ]),
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
                    Text(at['welcome_message'] ?? 'Willkommen',
                        style: const TextStyle(
                            fontSize: AppTheme.smallFontSize,
                            color: Colors.white)),
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
