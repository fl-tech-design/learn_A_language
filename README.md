# learn A language v1.0

## Overview
Language learning app for German and English (offline-capable).

## Features
- Learn vocabulary with translation
- Create and login user
- Language switch (DE/EN)
- Audio pronunciation (locally generated)

## Technical Details
- Interface: Kivy
- TTS: Local ONNX models (no external API needed)
- Data: JSON files for vocabulary and user data

## Goal: Audio Generation
Audio files will be generated from the vocabulary texts in `language_dict/`
and saved in `de_audio/` (German) or `en_audio/` (English)
so the app works offline without API limits.