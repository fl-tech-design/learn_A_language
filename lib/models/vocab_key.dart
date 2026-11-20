// Key-Hilfsfunktionen für Vocab-Keys.
//
// Vocab-Keys haben das Format '<verb>_<zeitform>_<person>' (z. B.
// 'to_be_present_0' oder 'to_be_allowed_to_present_0'). Die folgenden
// Funktionen extrahieren die einzelnen Segmente robust, auch wenn der
// Verb-Schlüssel Unterstriche enthält.

/// Liefert den Verb-Schlüssel (z. B. 'to_be_allowed_to') eines Vocab-Keys.
String vocabVerbKey(String entryKey) {
  final parts = entryKey.split('_');
  return parts.length <= 2
      ? entryKey
      : parts.sublist(0, parts.length - 2).join('_');
}

/// Liefert das Zeitform-Segment ('past' | 'present' | 'future').
String vocabTenseKey(String entryKey) {
  final parts = entryKey.split('_');
  return parts.length >= 2 ? parts[parts.length - 2] : '';
}

/// Liefert den Personen-Index (letztes Segment) eines Vocab-Keys.
int vocabPersonIndex(String entryKey) =>
    int.tryParse(entryKey.split('_').last) ?? 0;

/// Sortierreihenfolge der Zeitformen (past -> present -> future).
int vocabTenseOrder(String tense) =>
    switch (tense) { 'past' => 0, 'present' => 1, _ => 2 };
