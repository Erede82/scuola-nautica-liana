import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locks the DB contract that legacy ambiguous phones must not block
/// non-phone UPDATEs (onboarding, notes, app-access link, etc.).
void main() {
  test(
    'migration replaces table CHECK with phone-column trigger enforcement',
    () {
      final fix = File(
        'supabase/migrations/'
        '20260802113000_fix_students_phone_e164_legacy_row_updates.sql',
      ).readAsStringSync();

      expect(
        fix.contains('DROP CONSTRAINT IF EXISTS students_phone_e164_chk'),
        isTrue,
      );
      expect(
        fix.contains('BEFORE INSERT OR UPDATE OF phone'),
        isTrue,
        reason: 'E.164 must apply only when phone is written',
      );
      expect(
        fix.contains('enforce_students_phone_e164'),
        isTrue,
      );
      expect(
        RegExp(
          r"ADD CONSTRAINT\s+students_phone_e164_chk",
          caseSensitive: false,
        ).hasMatch(fix),
        isFalse,
        reason: 'must not reintroduce a table-level CHECK that blocks legacy rows',
      );
    },
  );
}
