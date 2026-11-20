import 'package:flutter_test/flutter_test.dart';
import 'package:learn_a_language/services/storage_error_bus.dart';

void main() {
  final bus = StorageErrorBus.instance;

  setUp(bus.clear);

  test('report/takeLast: Meldung wird einmalig konsumiert', () {
    expect(bus.hasPending, isFalse);

    bus.report(StorageErrorKind.saveFailed);

    expect(bus.hasPending, isTrue);
    expect(bus.takeLast(), StorageErrorKind.saveFailed);
    // Einmalig konsumiert → keine Doppel-/Daueranzeige.
    expect(bus.takeLast(), isNull);
    expect(bus.hasPending, isFalse);
  });

  test('nur die letzte Meldung bleibt erhalten', () {
    bus.report(StorageErrorKind.userDataUnloadable);
    bus.report(StorageErrorKind.progressNotSaved);

    expect(bus.takeLast(), StorageErrorKind.progressNotSaved);
    expect(bus.takeLast(), isNull);
  });

  test('clear setzt pending zurück', () {
    bus.report(StorageErrorKind.appDataRecovered);
    bus.clear();
    expect(bus.takeLast(), isNull);
  });
}