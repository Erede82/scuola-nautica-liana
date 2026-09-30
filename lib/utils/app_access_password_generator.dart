import 'dart:math';

/// Genera una password iniziale leggibile per accesso app allievo.
///
/// Lunghezza tipica 14 (≥ 8). Usa [Random.secure] (non PRNG non crittografico).
/// Alfabeto senza caratteri ambigui (0/O, 1/l/I) per leggibilità in segreteria.
String generateReadableAppAccessPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(14, (_) => chars[r.nextInt(chars.length)]).join();
}
