/// Zentrale Alphabete für die Buchstaben-Spiele (Wortsuche, Kreuzworträtsel,
/// Hangman).
///
/// Die Engines normalisieren Zielwörter auf das Alphabet der **Kurssprache**
/// und füllen Grids/Tastaturen daraus. Lateinische Sprachen nutzen A–Z
/// (inkl. Umlaut-Ersetzung wie bisher), Griechisch das 24-Buchstaben-Alphabet,
/// Russisch das 33-Buchstaben-Alphabet.
library;

/// Lateinisches Alphabet A–Z (Standard/Fallback).
const List<String> _latinAlphabet = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// Griechisches Alphabet (24 Großbuchstaben, ohne finales Sigma).
const List<String> _greekAlphabet = [
  'Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ', 'Λ', 'Μ', //
  'Ν', 'Ξ', 'Ο', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ', 'Φ', 'Χ', 'Ψ', 'Ω',
];

/// Russisches Alphabet (33 Großbuchstaben, inkl. Ё).
const List<String> _russianAlphabet = [
  'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ё', 'Ж', 'З', 'И', 'Й', 'К', 'Л', 'М', //
  'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ', 'Ъ',
  'Ы', 'Ь', 'Э', 'Ю', 'Я',
];

/// Großbuchstaben-Alphabet der Kurssprache [langCode].
///
/// `el` → Griechisch, `ru` → Russisch, sonst lateinisch (A–Z).
List<String> alphabetFor(String langCode) => switch (langCode) {
      'el' => _greekAlphabet,
      'ru' => _russianAlphabet,
      _ => _latinAlphabet,
    };

/// Diakritika-/Akzent-Normalisierung für Griechisch und Russisch
/// (Kleinbuchstaben → Basisbuchstabe).
const Map<String, String> _diacritics = {
  // Griechisch: Tonos, Trema, finales Sigma.
  'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
  'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ', 'ς': 'σ',
  // Russisch: Ё/ё → Е/е (für Spiele gleichwertig).
  'ё': 'е',
};

/// Set der zulässigen Kleinbuchstaben des Alphabets (nach Diakritika-Strip).
Set<String> _allowedLower(String langCode) {
  switch (langCode) {
    case 'el':
      return const {
        'α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ', 'ι', 'κ', 'λ', 'μ', //
        'ν', 'ξ', 'ο', 'π', 'ρ', 'σ', 'τ', 'υ', 'φ', 'χ', 'ψ', 'ω',
      };
    case 'ru':
      return const {
        'а', 'б', 'в', 'г', 'д', 'е', 'ё', 'ж', 'з', 'и', 'й', 'к', 'л', //
        'м', 'н', 'о', 'п', 'р', 'с', 'т', 'у', 'ф', 'х', 'ц', 'ч', 'ш',
        'щ', 'ъ', 'ы', 'ь', 'э', 'ю', 'я',
      };
    default:
      return const {};
  }
}

/// Normalisiert [raw] auf das Alphabet der Kurssprache [langCode]:
///
/// - **Lateinisch** (`de`, `en`, …): wie bisher – `ä→AE`, `ö→OE`, `ü→UE`,
///   `ß→SS`, `a–z → A–Z`, alle anderen Zeichen werden verworfen.
/// - **Griechisch/Russisch**: Diakritika entfernen (z. B. `ά→Α`, `ё→Е`,
///   `ς→Σ`), nur Zeichen des Zielalphabets behalten, Großbuchstaben.
String normalizeForGrid(String raw, String langCode) {
  final lowered = raw.toLowerCase();
  final out = StringBuffer();
  if (langCode == 'el' || langCode == 'ru') {
    final allowed = _allowedLower(langCode);
    for (var i = 0; i < lowered.length; i++) {
      final ch = _diacritics[lowered[i]] ?? lowered[i];
      if (allowed.contains(ch)) out.write(ch.toUpperCase());
    }
    return out.toString();
  }
  // Latein: bisheriges Verhalten (Umlaute → AE/OE/UE, ß → SS, nur a–z).
  for (var i = 0; i < lowered.length; i++) {
    final ch = lowered[i];
    if (ch == 'ä') {
      out.write('AE');
    } else if (ch == 'ö') {
      out.write('OE');
    } else if (ch == 'ü') {
      out.write('UE');
    } else if (ch == 'ß') {
      out.write('SS');
    } else if (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122) {
      out.write(ch.toUpperCase());
    }
  }
  return out.toString();
}
