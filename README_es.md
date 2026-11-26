# Learn A Language

Una potente aplicación de aprendizaje de idiomas **sin conexión** y **sin anuncios**.
Este proyecto es una migración completa de una aplicación previamente desarrollada en Python/Kivy a **Flutter (Dart)**, optimizada para Android y Linux Desktop.

**[English](README.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Русский](README_ru.md) | [Ελληνικά](README_el.md) | [Italiano](README_it.md) | [Português](README_pt.md)**

## Estado actual

| Componente | Valor |
|---|---|
| Hash de commit | `95308f9ccc5121eb2e4a8e6172053e98b599018e` (`95308f9`) |
| Rama | `main` |
| Fecha | 26.11.2026 |

> Esta sección se actualiza con cada cambio relevante (p. ej., antes de los informes de análisis) para que el estado documentado del código siga siendo reproducible (Ticket #57).

## Funciones principales

- **100% Offline y sin anuncios**: Todos los datos se almacenan localmente en el dispositivo. Sin rastreadores, sin anuncios, sin dependencias externas para la funcionalidad principal.
- **Sistema de repetición espaciada**: Ritmo de aprendizaje científicamente fundamentado con 9 niveles (0–8) para una retención óptima de la memoria.
- **Lógica de racha diaria**: Seguimiento motivacional y visualización de días consecutivos de aprendizaje.
- **Modos de aprendizaje y juego**: Incluye un juego "Turbo" que evalúa específicamente el vocabulario ya aprendido para reforzar el conocimiento.
- **Gestión local de usuarios**: Registro sencillo, inicio de sesión y gestión de múltiples perfiles de usuario directamente en el dispositivo.
- **Resumen de progreso**: Una tabla de palabras de solo lectura por categoría de verbos que muestra el nivel actual de cada palabra con insignias de nivel de colores (gris = nuevo, verde = dominado).
- **Multiplataforma**: Funciona de forma nativa y estable en Android y Linux Desktop.

## Tecnologías utilizadas

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **Gestión de estado**: Provider (ChangeNotifier)
- **Navegación**: tabla de rutas `MaterialApp.routes` con `Navigator.pushNamed` (enrutamiento declarativo)
- **Persistencia de datos**: Almacenamiento local en JSON mediante path_provider (con copia automática de assets en el primer inicio)
- **UI/Diseño**: Fuentes integradas (Jura, Boycott, LiberationSerif) y un AppTheme personalizado para una apariencia consistente.

## Estructura del proyecto

El proyecto sigue una arquitectura limpia y modular dentro del directorio `lib/`, garantizando mantenibilidad y escalabilidad:

lib/
├── main.dart            # Punto de entrada de la aplicación
├── managers/            # Lógica de negocio (AppState, User, Vocab, Language)
├── screens/             # Vistas de la interfaz (Loading, Start, Learning, Settings, etc.)
│   ├── loading_screen.dart            # Pantalla de carga con inicialización asíncrona y auto-login
│   ├── start_screen.dart              # Menú principal / página de inicio
│   ├── category_screen.dart           # Subcategoría con modos de aprendizaje (Nuevas/Pendientes/Aprendidas)
│   ├── collection_screen.dart         # Colección que muestra sus subcategorías
│   ├── learning_screen.dart           # Selección de categorías de aprendizaje
│   ├── word_screen.dart               # Tarjetas de palabras (visualización y comprobación)
│   ├── due_word_screen.dart           # Repaso de palabras pendientes (repetición espaciada)
│   ├── progress_screen.dart           # Resumen de progreso (colecciones de solo lectura)
│   ├── progress_group_screen.dart     # Tabla de solo lectura por categoría con insignias de nivel
│   ├── settings_screen.dart           # Ajustes (auto-login, palabras por sesión, usuarios)
│   ├── game_choose_screen.dart        # Centro «Elegir juego»
│   ├── game_screen.dart               # Juego de preguntas Turbo (vidas, puntos, temporizador)
│   ├── turbo_lv_select_screen.dart    # Selección de dificultad Turbo
│   ├── grammar_screen.dart            # Lista de temas de gramática (filtro opcional por nivel)
│   ├── grammar_detail_screen.dart     # Vista de detalle de un tema de gramática
│   ├── crossword_screen.dart          # Pantalla del juego de crucigrama
│   ├── crossword_lv_select_screen.dart# Selección de dificultad del crucigrama
│   ├── fill_in_screen.dart            # Juego de completar huecos (frases con huecos)
│   ├── fill_in_lv_select_screen.dart  # Selección de dificultad de completar huecos
│   ├── hangman_screen.dart            # Juego del ahorcado
│   ├── hangman_lv_select_screen.dart  # Selección de dificultad del ahorcado
│   ├── word_search_screen.dart        # Juego de sopa de letras
│   ├── crossword_engine.dart          # Lógica del crucigrama (Dart puro, sin Flutter)
│   ├── fill_in_engine.dart            # Lógica de completar huecos (Dart puro, sin Flutter)
│   ├── hangman_engine.dart            # Lógica del ahorcado (Dart puro, sin Flutter)
│   └── word_search_engine.dart        # Lógica de sopa de letras (Dart puro, sin Flutter)
├── services/            # Servicios (p. ej. FileService para persistencia JSON)
├── models/              # Modelos de datos
├── widgets/             # Componentes de UI reutilizables
├── dialogs/             # Ventanas emergentes y diálogos (Info, Login, GameOver, etc.)
└── test/                # Pruebas unitarias y de widgets (flutter test)
├── theme/               # Paleta de colores central y ThemeData

## Primeros pasos

### Requisitos previos
- Flutter SDK (>= 3.1.0) instalado
- Un editor de tu elección (p. ej. VS Code o Android Studio)

### Instalación y ejecución

1. Clonar el repositorio:
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Instalar dependencias:
   flutter pub get

3. Ejecutar la aplicación (p. ej. en Linux Desktop o un dispositivo/emulador Android conectado):
   flutter run

### Instalación mediante depuración Wi-Fi (Android 11+, conserva los datos)

> Instalar sobre una aplicación existente nunca elimina tus datos. Los datos
> solo se pierden cuando la aplicación se **desinstala**. Actualizar con
> `install -r` conserva todos los datos locales del usuario (palabras, niveles,
> rachas).

Funciona en Android 11+ con **Depuración inalámbrica** activada. El puerto de
emparejamiento es **dinámico** — usa siempre la IP/puerto que muestra el móvil.

1. Activa en el teléfono **Opciones de desarrollador → Depuración inalámbrica**
   y pulsa **«Emparejar dispositivo con código»**. El móvil muestra ahora una
   IP, un puerto y un código de emparejamiento de 6 dígitos.
2. En el ordenador, empareja y conecta:
   adb pair IP:PORT <código-de-6-dígitos>
   adb connect IP:PORT            # usa el puerto que muestra el móvil
3. Verifica que el dispositivo está conectado (debe aparecer en la lista):
   adb devices
4. Compila el APK debug e instálalo sobre la aplicación actual (conserva todo):
   flutter build apk --debug
   adb -s IP:PORT install -r build/app/outputs/flutter-apk/app-debug.apk

> `-r` reemplaza la aplicación conservando sus datos. Si aparece «signature
> mismatch», la aplicación instalada tiene una firma distinta (p. ej. una
> versión release) — sería necesaria la desinstalación, por eso usa siempre el
> tipo de build coincidente (debug → debug).

## Migración de Kivy a Flutter

La aplicación se migró exitosamente de Python/Kivy a Flutter. Se prestó especial atención a los siguientes puntos:
- **100% compatibilidad de datos**: La estructura de datos JSON permanece totalmente retrocompatible con los datos de usuario existentes de la versión Kivy.
- **Portado completo**: Las 8 pantallas, 6 diálogos y 5 clases de gestión se transfirieron 1:1 a Dart.
- **Estabilidad**: Correcciones exhaustivas de errores para Linux Desktop y Android, incluyendo funciones seguras para la plataforma (p. ej. closeApp).

## Licencia

Este proyecto se desarrolla como una aplicación sin anuncios y offline-first, centrada en un aprendizaje efectivo y sin distracciones.