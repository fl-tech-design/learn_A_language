import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../managers/user_state.dart';
import '../managers/data_state.dart';
import '../managers/user_manager.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/create_user_dialog.dart';
import '../dialogs/delete_user_dialog.dart';
import '../l10n/app_localizations.dart';
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
    final dataState = context.read<DataState>();
    _stayLoggedIn = dataState.appData.stayLoggedIn;
    _wordsPerSession = dataState.appData.wordsPerSession;
  }

  Future<void> _toggleStayLoggedIn(bool? v) async {
    if (v == null) return;
    setState(() => _stayLoggedIn = v);
    final dataState = context.read<DataState>();
    await context.read<FileService>().updateJsonKey(
        'data_app/app_data.json', 'stay_logged_in', v);
    await dataState.loadAppData();
  }

  Future<void> _setWordsPerSession(int count) async {
    setState(() => _wordsPerSession = count);
    final dataState = context.read<DataState>();
    await context.read<FileService>().updateJsonKey(
        'data_app/app_data.json', 'words_per_session', count);
    await dataState.loadAppData();
  }

  Future<void> _requestDeleteUser() async {
    final dataState = context.read<DataState>();
    final um = context.read<UserManager>();
    final l10n = AppLocalizations.of(context);
    final name = await showDeleteUserDialog(
        context,
        l10n.userDelete,
        l10n.infDeleteUser,
        toBeginningOfSentenceCase(l10n.confirm),
        toBeginningOfSentenceCase(l10n.chancel));
    if (name == null || name.isEmpty) return;
    await um.deleteUser(name);
    await dataState.loadAppData();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _requestCreateUser() async {
    final dataState = context.read<DataState>();
    final userState = context.read<UserState>();
    final l10n = AppLocalizations.of(context);
    final result = await showCreateUserDialog(
        context,
        l10n.uRegistration,
        l10n.infUserReg,
        l10n.mLang,
        l10n.german,
        l10n.english,
        toBeginningOfSentenceCase(l10n.confirm),
        toBeginningOfSentenceCase(l10n.chancel));
    if (result == null) return;
    await userState.registerUser(result['username']!, result['m_lang']!);
    await dataState.loadAppData();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(children: [
        BoxTitle(title: l10n.titPageSett),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.contentPadding),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.languages,
                          style:
                              const TextStyle(fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_germany.png',
                          label: l10n.german,
                          onTap: () => context.read<DataState>().changeLanguage('deutsch')),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_uk.png',
                          label: l10n.english,
                          onTap: () => context.read<DataState>().changeLanguage('englisch')),
                      const SizedBox(height: 20),
                      Row(children: [
                        SizedBox(
                            width: 40,
                            child: Checkbox(
                                value: _stayLoggedIn,
                                onChanged: _toggleStayLoggedIn,
                                activeColor: AppTheme.colorPrimary)),
                        const SizedBox(width: AppTheme.contentSpacing),
                        Text(l10n.stayLoggedIn,
                            style: const TextStyle(
                                fontSize: AppTheme.lblFontSize)),
                      ]),
                      const SizedBox(height: 16),
                      Text(l10n.wordsPerSession,
                          style:
                              const TextStyle(fontSize: AppTheme.lblFontSize)),
                      const SizedBox(height: 8),
                      Row(
                          children: [3, 5, 10].map((n) {
                        final selected = _wordsPerSession == n;
                        return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(switch (n) {
                                  3 => l10n.words3,
                                  5 => l10n.words5,
                                  10 => l10n.words10,
                                  _ => '$n',
                                }),
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
                                  toBeginningOfSentenceCase(l10n.btnDeleteUser),
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                      const SizedBox(height: AppTheme.contentSpacing),
                      SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: _requestCreateUser,
                              child: Text(
                                  toBeginningOfSentenceCase(l10n.btnAddUser),
                                  style: const TextStyle(
                                      fontSize: AppTheme.btnFontSize)))),
                    ]))),
        BoxBottom(
            settingsText: l10n.back,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pop(),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}
