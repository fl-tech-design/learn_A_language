import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:provider/provider.dart';
import '../managers/data_state.dart';
import '../managers/navigation_state.dart';
import '../managers/session_manager.dart';
import '../managers/user_state.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/version_label.dart';

/// Splash/loading screen – 1:1 from loadingpage.py.
///
/// Übernimmt ab Ticket 3 die schwere Initialisierung asynchron im Hintergrund
/// (FileSystem-/App-Daten-Initialisierung, Auto-Login inkl. genau eines
/// Vocab-Init- + Migrationslaufs), damit `runApp` sofort sichtbar ist und die
/// Startzeit nicht mit dem Wortschatz wächst. Erst nach Abschluss wird nach
/// `/start` navigiert.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final dataState = context.read<DataState>();
    final userState = context.read<UserState>();
    final sessionManager = context.read<SessionManager>();

    // Schritt 1: Dateisystem + App-Daten (Asset-Kopien, App/Player-Daten).
    // Unvollständige Kopien (Ticket #42) sind KEIN Abbruchgrund – die App
    // startet, aber die SnackBar kommt über den StorageErrorBus (von
    // FileService.initialize gesetzt) und das Log zeigt die betroffenen Pfade.
    final failedCopies = await dataState.initialize();
    if (failedCopies.isNotEmpty) {
      log('LoadingScreen: ${failedCopies.length} Asset-Kopien fehlgeschlagen: '
          '$failedCopies');
    }
    if (!mounted) return;
    setState(() => _progress = 40);

    // Schritt 2: Auto-Login inkl. genau einem Vocab-Init- + Migrationslauf
    // (login übernimmt das); bei Fehler nur loggen – die SnackBar kommt über
    // den [StorageErrorBus], den login bei einer korrupten Datei intern setzt
    // (Ticket-2-Sichtbarkeit, ohne Doppelt-Melden).
    final uname = dataState.appData.loggedUName;
    if (uname.isNotEmpty) {
      final loginError = await userState.login(uname);
      if (!mounted) return;
      if (loginError != null) {
        log('LoadingScreen: Auto-Login für $uname fehlgeschlagen: $loginError');
      }
      await dataState.loadAppData();
      if (!mounted) return;
    }

    // Schritt 3: Gespeicherte Session laden (zuletzt geöffnete Seite), damit
    // die App nach einem Android-Prozess-Kill dort weitermacht. Fehler sind
    // unkritisch: ohne gültige Session geht es normal auf das Start-Menü.
    SessionSnapshot? snapshot;
    try {
      snapshot = await sessionManager.loadSnapshotForUser(
          dataState.appData.loggedUName);
    } catch (e) {
      log('LoadingScreen: Session-Wiederherstellung fehlgeschlagen ($e)');
      snapshot = null;
    }
    if (!mounted) return;

    setState(() => _progress = 100);

    // Kurz den abgeschlossenen Splash zeigen, dann zur zuletzt geöffneten
    // Seite (oder ohne Session zum Start-Menü).
    final navState = context.read<NavigationState>();
    final routes = snapshot?.routes ?? const <SessionRoute>[];
    unawaited(Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pushReplacementNamed('/start');
      if (snapshot != null && routes.isNotEmpty) {
        // Word-Modus + gewählte Kategorie für /word und /dueword übernehmen.
        navState.setWordMode(snapshot.wordMode);
        navState.setSelectedCategoryId(snapshot.selectedCategoryId);
        // Kurs-Kontext wiederherstellen (bestimmt die Kurssprache).
        final courseId = snapshot.activeCourseId;
        final course =
            courseId != null ? availableCourses[courseId] : null;
        if (course != null) {
          navState.setActiveCourse(course);
        } else {
          navState.clearActiveCourse();
        }
        try {
          for (final r in routes) {
            nav.pushNamed(r.name, arguments: r.arguments);
          }
        } catch (e) {
          log('LoadingScreen: Wiederhergestellte Routen nicht navigierbar ($e)');
          unawaited(sessionManager.clear());
        }
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loadingText = l10n.loading;
    final loadingComplete = l10n.loadingComplete;

    return Scaffold(
      backgroundColor: AppTheme.splashBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Bild füllt nur die Breite des Screens (Höhe bleibt proportional),
          // damit es im Portrait-Format nicht mehr auf die Höhe gezoomt wird.
          Image.asset('assets/images/spl_start.png',
              fit: BoxFit.fitWidth),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18,
            left: 0,
            right: 0,
            child: Text(
              _progress >= 100
                  ? '${toBeginningOfSentenceCase(loadingComplete)}!'
                  : '${toBeginningOfSentenceCase(loadingText)}...  ${_progress.toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                color: Colors.white,
                fontFamily: 'Jura',
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.06,
            left: MediaQuery.of(context).size.width * 0.125,
            right: MediaQuery.of(context).size.width * 0.125,
            child: LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: AppTheme.grey3,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.colorPrimary),
              minHeight: 20,
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.02,
            left: 0,
            right: 0,
            child: const VersionLabel(),
          ),
        ],
      ),
    );
  }
}
