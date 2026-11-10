import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/app_state.dart';
import '../managers/user_manager.dart';
import '../managers/language_manager.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/create_user_dialog.dart';
import '../dialogs/delete_user_dialog.dart';
import '../services/file_service.dart';

/// Settings screen – 1:1 from settingpage.py/kv.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _stayLoggedIn = false;
  int _wordsPerSession = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    _stayLoggedIn = appState.appData.stayLoggedIn;
    _wordsPerSession = appState.appData.wordsPerSession;
  }

  Future<void> _toggleStayLoggedIn(bool? v) async {
    if (v == null) return;
    setState(() => _stayLoggedIn = v);
    final appState = context.read<AppState>();
    await FileService.updateJsonKey(
        'data_app/app_data.json', 'stay_logged_in', v);
    await appState.loadAppData();
  }

  Future<void> _setWordsPerSession(int count) async {
    setState(() => _wordsPerSession = count);
    final appState = context.read<AppState>();
    await FileService.updateJsonKey(
        'data_app/app_data.json', 'words_per_session', count);
    await appState.loadAppData();
  }

  Future<void> _requestDeleteUser() async {
    final appState = context.read<AppState>();
    final bt = appState.baseTxt;
    final name = await showDeleteUserDialog(
        context,
        bt['user_delete'] ?? 'Benutzer löschen',
        bt['inf_delete_user'] ?? 'Benutzername eingeben',
        letUppercaseFirst(bt['confirm'] ?? 'bestätigen'),
        letUppercaseFirst(bt['chancel'] ?? 'abbrechen'));
    if (name == null || name.isEmpty) return;
    await UserManager.deleteUser(name);
    await appState.loadAppData();
    setState(() {});
  }

  Future<void> _requestCreateUser() async {
    final appState = context.read<AppState>();
    final bt = appState.baseTxt;
    final at = appState.appTxt;
    final result = await showCreateUserDialog(
        context,
        bt['u_registration'] ?? 'Benutzer registrieren',
        bt['inf_user_reg'] ?? 'Bitte einen Benutzername eingeben.',
        at['m_lang'] ?? 'Muttersprache',
        bt['german'] ?? 'Deutsch',
        bt['english'] ?? 'English',
        letUppercaseFirst(bt['confirm'] ?? 'bestätigen'),
        letUppercaseFirst(bt['chancel'] ?? 'abbrechen'));
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
      body: Column(children: [
        BoxTitle(title: at['tit_page_sett']?.toString() ?? 'Einstellungen'),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bt['languages'] ?? 'Sprachen',
                          style:
                              const TextStyle(fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_germany.png',
                          label: bt['german']?.toString() ?? 'deutsch',
                          onTap: () => appState.changeLanguage('deutsch')),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_uk.png',
                          label: bt['english']?.toString() ?? 'english',
                          onTap: () => appState.changeLanguage('englisch')),
                      const SizedBox(height: 20),
                      Row(children: [
                        SizedBox(
                            width: 40,
                            child: Checkbox(
                                value: _stayLoggedIn,
                                onChanged: _toggleStayLoggedIn,
                                activeColor: AppTheme.colorPrimary)),
                        const SizedBox(width: AppTheme.contentSpacing),
                        Text(at['stay_logged_in'] ?? 'Eingeloggt bleiben',
                            style: const TextStyle(
                                fontSize: AppTheme.lblFontSize)),
                      ]),
                      const SizedBox(height: 16),
                      Text(at['words_per_session'] ?? 'Wörter pro Sitzung',
                          style:
                              const TextStyle(fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: 8),
                      Row(
                          children: [3, 5, 10].map((n) {
                        final selected = _wordsPerSession == n;
                        return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label:
                                    Text('$n ${at['words_$n'] ?? '$n Wörter'}'),
                                selected: selected,
                                onSelected: (_) => _setWordsPerSession(n)));
                      }).toList()),
                      const SizedBox(height: 20),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: _requestDeleteUser,
                              child: Text(
                                  letUppercaseFirst(bt['btn_delete_user'] ??
                                      'Benutzer löschen'),
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: _requestCreateUser,
                              child: Text(
                                  letUppercaseFirst(bt['btn_add_user'] ??
                                      'Benutzer erstellen'),
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      Row(children: [
                        Expanded(
                            child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                    letUppercaseFirst(bt['back'] ?? 'zurück'),
                                    style: const TextStyle(
                                        fontSize: AppTheme.btnFontSize,
                                        color: AppTheme.colorPrimary)))),
                        Expanded(
                            child: TextButton(
                                onPressed: AppTheme.closeApp,
                                child: Text(bt['exit'] ?? 'Beenden',
                                    style: const TextStyle(
                                        fontSize: AppTheme.btnFontSize,
                                        color: AppTheme.colorPrimary)))),
                      ]),
                    ]))),
      ]),
    );
  }
}
