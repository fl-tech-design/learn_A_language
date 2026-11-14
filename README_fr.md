# Learn A Language

Une application puissante d'apprentissage des langues **hors ligne** et **sans publicité**.
Ce projet est une migration complète d'une application précédemment développée en Python/Kivy vers **Flutter (Dart)**, optimisée pour Android et Linux Desktop.

**[English](README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Русский](README_ru.md)**

## Fonctionnalités principales

- **100% Hors ligne et sans publicité**: Toutes les données sont stockées localement sur l'appareil. Aucun traqueur, aucune publicité, aucune dépendance externe pour les fonctionnalités de base.
- **Système de répétition espacée**: Rythme d'apprentissage scientifiquement fondé avec 9 niveaux (0–8) pour une rétention optimale de la mémoire.
- **Logique de série quotidienne**: Suivi motivationnel et affichage des jours d'apprentissage consécutifs.
- **Modes d'apprentissage et de jeu**: Comprend un jeu "Turbo" qui interroge spécifiquement le vocabulaire déjà appris pour renforcer les connaissances.
- **Gestion locale des utilisateurs**: Inscription simple, connexion et gestion de plusieurs profils utilisateur directement sur l'appareil.
- **Multiplateforme**: Fonctionne de manière native et stable sur Android et Linux Desktop.

## Technologies utilisées

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **Gestion d'état**: Provider (ChangeNotifier)
- **Navigation**: go_router (routage déclaratif)
- **Persistance des données**: Stockage local en JSON via path_provider (avec copie automatique des assets au premier lancement)
- **UI/Design**: google_fonts (Jura, Boycott, LiberationSerif) et un AppTheme personnalisé pour une apparence cohérente.

## Structure du projet

Le projet suit une architecture propre et modulaire au sein du répertoire `lib/`, garantissant la maintenabilité et l'évolutivité :

lib/
├── main.dart            # Point d'entrée de l'application
├── managers/            # Logique métier (AppState, User, Vocab, Language)
├── screens/             # Vues de l'interface (Loading, Start, Learning, Settings, etc.)
├── services/            # Services (p. ex. FileService pour la persistance JSON)
├── models/              # Modèles de données
├── widgets/             # Composants d'interface réutilisables
├── dialogs/             # Fenêtres contextuelles et dialogues (Info, Login, GameOver, etc.)
└── theme/               # Palette de couleurs centrale et ThemeData

## Premiers pas

### Prérequis
- Flutter SDK (>= 3.1.0) installé
- Un éditeur de votre choix (p. ex. VS Code ou Android Studio)

### Installation et démarrage

1. Cloner le dépôt :
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Installer les dépendances :
   flutter pub get

3. Lancer l'application (p. ex. sur Linux Desktop ou un appareil/émulateur Android connecté) :
   flutter run

## Migration de Kivy à Flutter

L'application a été migrée avec succès de Python/Kivy vers Flutter. Une attention particulière a été portée aux points suivants :
- **100% compatibilité des données**: La structure de données JSON reste entièrement rétrocompatible avec les données utilisateur existantes de la version Kivy.
- **Portage complet**: Les 8 écrans, 6 dialogues et 5 classes de gestion ont été transférés 1:1 en Dart.
- **Stabilité**: Corrections exhaustives des bogues pour Linux Desktop et Android, y compris des fonctions sûres pour la plateforme (p. ex. closeApp).

## Licence

Ce projet est développé en tant qu'application sans publicité et offline-first, axée sur un apprentissage efficace et sans distraction.