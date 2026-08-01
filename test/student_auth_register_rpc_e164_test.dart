import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository Supabase invoca register_student_app_e164', () {
    final src = File(
      'lib/repositories/student_auth_repository_supabase.dart',
    ).readAsStringSync();
    expect(src.contains("register_student_app_e164"), isTrue);
    expect(src.contains("'p_phone_e164'"), isTrue);
    expect(src.contains("'p_phone_country_iso2'"), isTrue);
    expect(
      RegExp(r"rpc\(\s*'register_student_app'\s*,").hasMatch(src),
      isFalse,
      reason: 'non deve più invocare la RPC legacy nel flusso aggiornato',
    );
  });
}
