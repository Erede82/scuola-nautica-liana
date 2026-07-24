import 'dart:math';

/// Genera un token idempotente per una nuova simulazione esame.
///
/// Una nuova chiamata produce un valore diverso (UUID v4-like) senza dipendenze
/// esterne. Il token resta stabile per tutta la vita del player.
String generateExamClientAttemptToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');

  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}
