# Learn A Language

Uma aplicação poderosa de aprendizagem de idiomas, **offline** e **sem anúncios**.
Este projeto é a migração completa de uma aplicação anteriormente desenvolvida em Python/Kivy para **Flutter (Dart)**, otimizada para Android e Linux Desktop.

**[English](README.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Español](README_es.md) | [Русский](README_ru.md) | [Ελληνικά](README_el.md) | [Italiano](README_it.md)**

## Estado atual

| Componente | Valor |
|---|---|
| Hash do commit | `95308f9ccc5121eb2e4a8e6172053e98b599018e` (`95308f9`) |
| Ramo | `main` |
| Data | 26.11.2026 |

> Esta secção é atualizada a cada alteração relevante (por exemplo, antes de relatórios de análise) para que o estado documentado do código permaneça reproduzível (Ticket #57).

## Funcionalidades principais

- **100% Offline e sem anúncios**: Todos os dados são armazenados localmente no dispositivo. Sem rastreadores, sem anúncios, sem dependências externas para o funcionamento principal.
- **Sistema de repetição espaçada**: Ritmo de aprendizagem com base científica e 9 níveis (0–8) para uma retenção ótima na memória.
- **Lógica de sequência diária**: Acompanhamento motivacional e exibição de dias de aprendizagem consecutivos.
- **Modos de aprendizagem e jogos**: Inclui um jogo "Turbo" que questiona especificamente o vocabulário já aprendido para reforçar a memória.
- **Gestão local de utilizadores**: Registo, início de sessão e gestão de vários perfis de utilizador diretamente no dispositivo.
- **Visão geral do progresso**: Uma tabela de palavras só de leitura por categoria de verbos, mostrando o nível atual de cada palavra com etiquetas coloridas (cinzento = novo, verde = aprendido).
- **Multiplataforma**: Funciona de forma nativa e estável em Android e Linux Desktop.

## Stack tecnológica

- **Framework**: Flutter (Dart, SDK >= 3.1.0)
- **Gestão de estado**: Provider (ChangeNotifier)
- **Navegação**: Tabela de rotas `MaterialApp.routes` com `Navigator.pushNamed` (roteamento declarativo)
- **Persistência de dados**: Armazenamento JSON local via path_provider (com cópia automática de assets no primeiro arranque)
- **UI/Design**: Fontes incluídas (Jura, Boycott, LiberationSerif) e um AppTheme personalizado para uma aparência consistente.

## Estrutura do projeto

O projeto segue uma arquitetura limpa e modular dentro do diretório `lib/`, garantindo manutenibilidade e escalabilidade:

lib/
├── main.dart            # Ponto de entrada da aplicação
├── managers/            # Lógica de negócio (AppState, User, Vocab, Language)
├── screens/             # Vistas da interface (Loading, Start, Learning, Settings, etc.)
│   ├── loading_screen.dart            # Ecrã de carregamento com inicialização assíncrona e início de sessão automático
│   ├── start_screen.dart              # Menu principal / página inicial
│   ├── category_screen.dart           # Subcategoria com modos de aprendizagem (Novas/Pendentes/Aprendidas)
│   ├── collection_screen.dart         # Coleção que lista as suas subcategorias
│   ├── learning_screen.dart           # Seleção de categorias de aprendizagem
│   ├── word_screen.dart               # Cartões de palavras (visualização e verificação da resposta)
│   ├── due_word_screen.dart           # Revisão de palavras pendentes (repetição espaçada)
│   ├── progress_screen.dart           # Visão geral do progresso (coleções só de leitura)
│   ├── progress_group_screen.dart     # Tabela só de leitura por categoria com etiquetas de nível
│   ├── settings_screen.dart           # Definições (início de sessão automático, palavras por sessão, utilizadores)
│   ├── game_choose_screen.dart        # Hub «Escolher jogo»
│   ├── game_screen.dart               # Jogo de perguntas Turbo (vidas, pontos, cronómetro)
│   ├── turbo_lv_select_screen.dart    # Seleção de dificuldade Turbo
│   ├── grammar_screen.dart            # Lista de tópicos de gramática (filtro opcional por nível)
│   ├── grammar_detail_screen.dart     # Detalhe de um tópico de gramática
│   ├── crossword_screen.dart          # Ecrã do jogo de palavras cruzadas
│   ├── crossword_lv_select_screen.dart# Seleção de dificuldade das palavras cruzadas
│   ├── fill_in_screen.dart            # Jogo de preenchimento (frases com lacunas)
│   ├── fill_in_lv_select_screen.dart  # Seleção de dificuldade do preenchimento
│   ├── hangman_screen.dart            # Jogo da forca
│   ├── hangman_lv_select_screen.dart  # Seleção de dificuldade da forca
│   ├── word_search_screen.dart        # Jogo de sopa de letras
│   ├── crossword_engine.dart          # Lógica das palavras cruzadas (Dart puro, sem Flutter)
│   ├── fill_in_engine.dart            # Lógica de preenchimento (Dart puro, sem Flutter)
│   ├── hangman_engine.dart            # Lógica da forca (Dart puro, sem Flutter)
│   └── word_search_engine.dart        # Lógica da grelha de sopa de letras (Dart puro, sem Flutter)
├── services/            # Serviços (p. ex. FileService para persistência JSON)
├── models/              # Modelos de dados
├── widgets/             # Componentes reutilizáveis da interface
├── dialogs/             # Janelas e diálogos (Info, Login, GameOver, etc.)
└── test/                # Testes unitários e de widgets (flutter test)
├── theme/               # Paleta de cores central e ThemeData

## Introdução

### Pré-requisitos
- Flutter SDK (>= 3.1.0) instalado
- Um editor à sua escolha (p. ex. VS Code ou Android Studio)

### Instalação e execução

1. Clone o repositório:
   git clone https://github.com/fl-tech-design/learn_A_language.git
   cd learn_A_language

2. Instale as dependências:
   flutter pub get

3. Execute a aplicação (p. ex. no Linux Desktop ou num dispositivo Android/emulador ligado):
   flutter run

### Instalação por depuração sem fios (Android 11+, mantém os dados do utilizador)

> Instalar sobre uma aplicação existente **nunca apaga** os seus dados. Os dados só se
> perdem quando a aplicação é **desinstalada**. Atualizar uma compilação com
> `install -r` mantém todos os dados locais (palavras, níveis, sequências).

Funciona em Android 11+ com **depuração sem fios** ativada. A porta de emparelhamento é
**dinâmica** — use sempre o IP/porta indicados no telemóvel.

1. No telemóvel ative **Opções de programador → Depuração sem fios** e toque em
   **Emparelhar dispositivo com código**. O telemóvel mostra agora um IP, uma porta e um
   código de emparelhamento de 6 dígitos.
2. No computador, efetue o emparelhamento e a ligação:
   adb pair IP:PORTA <código-de-6-dígitos>
   adb connect IP:PORTA              # use a porta indicada no telemóvel
3. Confirme que o dispositivo está ligado (deve aparecer na lista):
   adb devices
4. Compile o APK de depuração e instale-o sobre a aplicação atual (mantém todos os dados):
   flutter build apk --debug
   adb -s IP:PORTA install -r build/app/outputs/flutter-apk/app-debug.apk

> `-r` substitui a aplicação mantendo os dados. Um erro de "assinatura incompatível"
> significa que a aplicação instalada tem uma assinatura diferente (p. ex. uma
> compilação de distribuição) — seria necessária a desinstalação, por isso instale sempre
> o tipo de compilação correspondente (debug → debug).

## Migração de Kivy para Flutter

A aplicação foi migrada com sucesso de Python/Kivy para Flutter. Foi dada atenção especial aos seguintes pontos:
- **Compatibilidade de dados a 100%**: A estrutura JSON dos dados permanece totalmente compatível com os dados de utilizador existentes da versão Kivy.
- **Portabilidade completa**: Todos os 8 ecrãs, 6 diálogos e 5 classes de gestão foram transferidos 1:1 para Dart.
- **Estabilidade**: Correções abrangentes para Linux Desktop e Android, incluindo funções seguras por plataforma (p. ex. closeApp).

## Licença

Este projeto é desenvolvido como uma aplicação sem anúncios, offline-primeiro, focada numa aprendizagem eficaz e sem interrupções.
