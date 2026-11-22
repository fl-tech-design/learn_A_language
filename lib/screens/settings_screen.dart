import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:provider/provider.dart';
import '../services/storage_error_bus.dart';
import '../theme/app_theme.dart';
import '../managers/user_state.dart';
import '../managers/data_state.dart';
import '../managers/user_manager.dart';
import '../widgets/app_widgets.dart';
import '../dialogs/create_user_dialog.dart';
import '../dialogs/delete_user_dialog.dart';
import '../l10n/app_localizations.dart';
import '../services/file_service.dart';
import '../widgets/version_label.dart';

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
    await _updateAppDataKeySafe('stay_logged_in', v);
    await dataState.loadAppData();
  }

  Future<void> _setWordsPerSession(int count) async {
    setState(() => _wordsPerSession = count);
    final dataState = context.read<DataState>();
    await _updateAppDataKeySafe('words_per_session', count);
    await dataState.loadAppData();
  }

  /// Schützt den direkten `updateJsonKey`-Aufruf auf `app_data.json` (dieser
  /// Aufrufpfad läuft NICHT über `DataState.loadAppData`) – Fehler werden
  /// geloggt und einmalig über den StorageErrorBus angezeigt, nie gecrasht.
  Future<void> _updateAppDataKeySafe(String key, Object? value) async {
    try {
      await context
          .read<FileService>()
          .updateJsonKey('data_app/app_data.json', key, value);
    } on PersistenceException catch (e) {
      log('settings: $key konnte nicht gespeichert werden ($e)');
      StorageErrorBus.instance.report(StorageErrorKind.saveFailed);
    }
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
        l10n.french,
        toBeginningOfSentenceCase(l10n.confirm),
        toBeginningOfSentenceCase(l10n.chancel));
    if (result == null) return;
    final error =
        await userState.registerUser(result['username']!, result['m_lang']!);
    if (!mounted || error != null) return;
    await dataState.loadAppData();
    if (!mounted) return;
    setState(() {});
  }

  /// Abschnitt „Muttersprache / Übersetzungsrichtung“: Der Nutzer kann seine
  /// Muttersprache ändern. Das steuert, in welcher Sprache die Übersetzung und
  /// Beispielsätze zu den (in der Kurssprache) gelernten Wörtern angezeigt
  /// werden. Über [UserState.changeMotherTongue] wird der Wortschatz aller
  /// Kurs-Sprachen neu aufgebaut (Fortschritt bleibt erhalten).
  Widget _motherTongueSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userState = context.watch<UserState>();
    final current = userState.userData?.mLang ?? 'de';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.mLang,
            style: const TextStyle(fontSize: AppTheme.lblFontSize)),
        const SizedBox(height: AppTheme.contentSpacing / 2),
        Wrap(
          spacing: 8,
          children: [
            _motherLangChip('de', l10n.german, current, userState),
            _motherLangChip('en', l10n.english, current, userState),
            _motherLangChip('fr', l10n.french, current, userState),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.motherTongueHint,
            style: const TextStyle(
                fontSize: AppTheme.infFontSize, color: AppTheme.grey4)),
      ],
    );
  }

  Widget _motherLangChip(
      String code, String label, String current, UserState userState) {
    return ChoiceChip(
      label: Text(toBeginningOfSentenceCase(label)),
      selected: current == code,
      onSelected: current == code
          ? null
          : (_) => userState.changeMotherTongue(code),
    );
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
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_spa.png',
                          label: l10n.spanish,
                          onTap: () => context.read<DataState>().changeLanguage('spanisch')),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_fra.png',
                          label: l10n.french,
                          onTap: () => context.read<DataState>().changeLanguage('französisch')),
                      const SizedBox(height: AppTheme.contentSpacing),
                      FlagBox(
                          flagAsset: 'assets/images/flag_rus.png',
                          label: l10n.russian,
                          onTap: () => context.read<DataState>().changeLanguage('russisch')),
                      const SizedBox(height: 20),
                      _motherTongueSection(context),
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
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: VersionLabel(),
        ),
        BoxBottom(
            settingsText: l10n.back,
            exitText: l10n.exit,
            onSettings: () => Navigator.of(context).pop(),
            onExit: AppTheme.closeApp),
      ]),
    );
  }
}
