import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/grammar_models.dart';
import '../services/file_service.dart';
import 'data_state.dart';
import 'grammar_manager.dart';
import 'navigation_state.dart';

/// Eine wiederherstellbare Route: Routenname + typisierte Argumente, wie sie
/// beim `Navigator.pushNamed` übergeben werden.
class SessionRoute {
  final String name;
  final Object? arguments;

  const SessionRoute({required this.name, this.arguments});
}

/// Wiederhergestellte Sitzung (Snapshots von Navigation + Word-Modus).
class SessionSnapshot {
  final String user;
  final String wordMode;
  final String? selectedCategoryId;
  final List<SessionRoute> routes;

  const SessionSnapshot({
    required this.user,
    required this.wordMode,
    this.selectedCategoryId,
    required this.routes,
  });
}

/// Persistiert die zuletzt geöffnete Seite (inkl. Argumenten und Word-Modus)
/// nach `data_app/last_session.json`.
///
/// Android beendet Hintergrund-Prozesse regelmässig (Speicherdruck) – auch
/// beim „Alle Apps schliessen" aus den Recents. Beim erneuten Start würde die
/// App sonst immer auf dem Start-Menü landen statt auf der zuletzt geöffneten
/// Seite. Dieser Manager hält den Zustand fest und stellt ihn beim App-Start
/// wieder her.
class SessionManager {
  static const String sessionPath = 'data_app/last_session.json';
  static const int _version = 1;

  /// Routen, die beim Neustart sicher wiederhergestellt werden können.
  static const Set<String> restorableRoutes = {
    '/learning',
    '/category',
    '/collection',
    '/word',
    '/dueword',
    '/gameselect',
    '/gamechoose',
    '/grammar',
    '/grammardetail',
    '/progress',
    '/progress_group',
    '/settings',
  };

  /// Routen, deren Argument ein einfacher String ist (z. B. Kategorie-Id).
  static const Set<String> stringArgRoutes = {
    '/category',
    '/grammar',
    '/progress_group',
  };

  /// Routen, deren Argument eine [CollectionScreenArgs]-Instanz ist.
  static const Set<String> collectionArgRoutes = {'/collection'};

  /// Routen, deren Argument ein [GrammarBlock] ist.
  static const Set<String> grammarBlockArgRoutes = {'/grammardetail'};

  final FileService _fileService;
  final GrammarManager _grammarManager;

  SessionManager(this._fileService, this._grammarManager);

  /// Liest die gespeicherte Session für [user] und liefert den wiederherstell-
  /// baren Snapshot oder `null`, wenn keine gültige Session existiert.
  ///
  /// Argumente werden hierbei aufgelöst (z. B. [GrammarBlock] per Id aus dem
  /// Grammatik-Katalog). Nicht mehr gültige Routen werden verworfen. Gehört
  /// die Session einem anderen Benutzer, wird sie gelöscht.
  Future<SessionSnapshot?> loadSnapshotForUser(String user) async {
    if (user.isEmpty) return null;

    final Map<String, dynamic> raw;
    try {
      raw = await _fileService.loadJson(sessionPath);
    } on PersistenceException catch (e) {
      log('SessionManager: Session unlesbar ($e)');
      return null;
    }
    if (raw.isEmpty) return null;
    if (raw['version'] != _version) return null;
    if (raw['user']?.toString() != user) {
      // Session gehört einem anderen Benutzer → verwerfen, damit niemand auf
      // einer fremden Seite landet.
      unawaited(clear());
      return null;
    }

    final rawRoutes = raw['routes'];
    if (rawRoutes is! List) return null;

    final routes = <SessionRoute>[];
    for (final entry in rawRoutes) {
      final decoded = await _decodeRoute(entry);
      if (decoded == null) continue; // ungültige Route verwerfen
      routes.add(decoded);
    }
    if (routes.isEmpty) return null;

    return SessionSnapshot(
      user: user,
      wordMode: raw['wordMode']?.toString() ?? 'new',
      selectedCategoryId: raw['selectedCategoryId']?.toString(),
      routes: routes,
    );
  }

  /// Serialisiert [routes] zusammen mit dem Word-Modus und dem aktuellen
  /// Benutzer nach `data_app/last_session.json`. Fehler werden nur geloggt
  /// (Best-Effort – die Session ist kein kritischer Datenbestand).
  Future<void> save({
    required String user,
    required NavigationState navigationState,
    required List<SessionRoute> routes,
  }) async {
    if (user.isEmpty) return;
    final data = <String, dynamic>{
      'version': _version,
      'user': user,
      'wordMode': navigationState.wordMode,
      'selectedCategoryId': navigationState.selectedCategoryId,
      'routes': [for (final r in routes) _encodeRoute(r)],
    };
    try {
      await _fileService.saveJson(sessionPath, data);
    } on PersistenceException catch (e) {
      log('SessionManager: Session konnte nicht gespeichert werden ($e)');
    }
  }

  /// Löscht die gespeicherte Session.
  Future<void> clear() async {
    try {
      await _fileService.deleteFile(sessionPath);
    } on PersistenceException catch (e) {
      log('SessionManager: Session konnte nicht gelöscht werden ($e)');
    }
  }

  // ── Serialisierung ────────────────────────────────────────────

  Map<String, dynamic> _encodeRoute(SessionRoute route) {
    final args = _encodeArgs(route.arguments);
    return {
      'name': route.name,
      if (args != null) 'args': args,
    };
  }

  Map<String, dynamic>? _encodeArgs(Object? args) {
    if (args == null) return null;
    if (args is String) {
      return {'type': 'string', 'value': args};
    }
    if (args is CollectionScreenArgs) {
      return {
        'type': 'collection_args',
        'collectionId': args.collectionId,
        'mode': args.mode,
      };
    }
    if (args is GrammarBlock) {
      return {'type': 'grammar_block', 'id': args.id};
    }
    return null;
  }

  /// Prüft, ob [args] für die Route [name] wiederherstellbar ist (Argument
  /// vorhanden und serialisierbar bzw. erwartungsgemäss `null`).
  static bool argsSupported(String name, Object? args) {
    if (stringArgRoutes.contains(name)) {
      return args is String && args.isNotEmpty;
    }
    if (collectionArgRoutes.contains(name)) {
      return args is CollectionScreenArgs;
    }
    if (grammarBlockArgRoutes.contains(name)) {
      return args is GrammarBlock;
    }
    return args == null;
  }

  Future<SessionRoute?> _decodeRoute(dynamic entry) async {
    if (entry is! Map) return null;
    final name = entry['name']?.toString();
    if (name == null || !restorableRoutes.contains(name)) return null;

    final argsRaw = entry['args'];
    Object? args;
    if (argsRaw is Map) {
      switch (argsRaw['type']?.toString()) {
        case 'string':
          final value = argsRaw['value']?.toString();
          if (value == null || value.isEmpty) return null;
          args = value;
          break;
        case 'collection_args':
          final id = argsRaw['collectionId']?.toString();
          final mode = argsRaw['mode']?.toString() ?? 'learn';
          if (id == null || wordCollectionById(id) == null) return null;
          args = CollectionScreenArgs(collectionId: id, mode: mode);
          break;
        case 'grammar_block':
          final id = argsRaw['id']?.toString();
          if (id == null || id.isEmpty) return null;
          final block = await _grammarBlockById(id);
          if (block == null) return null;
          args = block;
          break;
        default:
          return null;
      }
    }
    // Routen mit Pflicht-Argumenten ohne gültiges Argument verwerfen.
    if (!argsSupported(name, args)) return null;
    return SessionRoute(name: name, arguments: args);
  }

  Future<GrammarBlock?> _grammarBlockById(String id) async {
    try {
      final doc = await _grammarManager.load();
      for (final block in doc.blocks) {
        if (block.id == id) return block;
      }
    } catch (e) {
      log('SessionManager: GrammarBlock "$id" nicht auflösbar ($e)');
    }
    return null;
  }
}

/// Verfolgt den Routen-Stack des [Navigator] und persistiert die zuletzt
/// geöffnete Seite über den [SessionManager].
///
/// Zusätzlich als [WidgetsBindingObserver] registriert, damit beim Verlassen
/// der App (Home-/Vierkant-Taste) sofort gespeichert wird – ein direkt darauf
/// folgender Prozess-Kill verliert so keine Navigation.
class SessionObserver extends NavigatorObserver with WidgetsBindingObserver {
  final SessionManager _sessionManager;
  final NavigationState _navigationState;
  final DataState _dataState;

  /// Vom Beobachter nachgezogener Routen-Stack (der initiale `'/'`-Eintrag
  /// wird automatisch via [didPush] erfasst).
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

  /// Serialisiert Schreibvorgänge, damit parallele Navigationen nicht
  /// durcheinanderlaufen.
  Future<void> _saveChain = Future<void>.value();

  SessionObserver(this._sessionManager, this._navigationState, this._dataState);

  /// Registriert die Lifecycle-Beobachtung am [WidgetsBinding].
  void attach() => WidgetsBinding.instance.addObserver(this);

  /// Hebt die Lifecycle-Beobachtung auf.
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _persist();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _persist();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _persist();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = _stack.indexOf(oldRoute);
      if (index >= 0) {
        if (newRoute != null) {
          _stack[index] = newRoute;
        } else {
          _stack.removeAt(index);
        }
      } else if (newRoute != null) {
        _stack.add(newRoute);
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Beim Verlassen der App sofort persistieren, damit ein anschliessender
    // Prozess-Kill die zuletzt geöffnete Seite sichert.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persist();
    }
  }

  void _persist() {
    final user = _dataState.appData.loggedUName;
    if (user.isEmpty) return;
    final routes = _collectRoutes();
    final navState = _navigationState;
    final manager = _sessionManager;
    _saveChain = _saveChain.then((_) async {
      await manager.save(user: user, navigationState: navState, routes: routes);
    });
  }

  /// Sammelt die wiederherstellbaren Routen oberhalb von `/` und `/start`.
  /// Unbenannte Routen (Dialoge, `/game`) werden übersprungen; `/game` wird
  /// damit auf die Seite davor (`/gameselect`) zurückgesetzt – ein laufendes
  /// Quiz lässt sich ohne aufwendige Zustandsserialisierung nicht mittendrin
  /// wiederherstellen.
  List<SessionRoute> _collectRoutes() {
    final result = <SessionRoute>[];
    for (final route in _stack) {
      final name = route.settings.name;
      if (name == null) continue;
      if (name == '/' || name == '/start') continue;
      if (!SessionManager.restorableRoutes.contains(name)) continue;
      final args = route.settings.arguments;
      if (!SessionManager.argsSupported(name, args)) continue;
      result.add(SessionRoute(name: name, arguments: args));
    }
    return result;
  }
}
