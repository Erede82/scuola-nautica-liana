import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/utils/europe_rome_time.dart';
import 'package:scuola_nautica_liana/utils/guida_datetime_format.dart';

void main() {
  group('EuropeRomeTime', () {
    test('winter UTC → CET (UTC+1)', () {
      final utc = DateTime.utc(2026, 1, 21, 18);
      expect(EuropeRomeTime.isDaylightSaving(utc), isFalse);
      final wall = EuropeRomeTime.wallClock(utc);
      expect(wall.hour, 19);
      expect(wall.minute, 0);
      expect(wall.day, 21);
      expect(wall.month, 1);
    });

    test('summer UTC → CEST (UTC+2)', () {
      final utc = DateTime.utc(2026, 7, 21, 18);
      expect(EuropeRomeTime.isDaylightSaving(utc), isTrue);
      final wall = EuropeRomeTime.wallClock(utc);
      expect(wall.hour, 20);
      expect(wall.minute, 0);
      expect(wall.day, 21);
      expect(wall.month, 7);
    });

    test('21 Oct 2026 still CEST', () {
      final utc = DateTime.utc(2026, 10, 21, 18, 56);
      expect(EuropeRomeTime.isDaylightSaving(utc), isTrue);
      final wall = EuropeRomeTime.wallClock(utc);
      expect(wall.hour, 20);
      expect(wall.minute, 56);
      expect(
        GuidaDateTimeFormat.formatItalianDateTime(utc),
        '21 ottobre 2026 · 20:56',
      );
    });

    test('spring forward boundary 2026-03-29 01:00 UTC', () {
      final before = DateTime.utc(2026, 3, 29, 0, 59);
      final at = DateTime.utc(2026, 3, 29, 1);
      expect(EuropeRomeTime.isDaylightSaving(before), isFalse);
      expect(EuropeRomeTime.isDaylightSaving(at), isTrue);
      expect(EuropeRomeTime.wallClock(before).hour, 1);
      expect(EuropeRomeTime.wallClock(before).minute, 59);
      expect(EuropeRomeTime.wallClock(at).hour, 3);
      expect(EuropeRomeTime.wallClock(at).minute, 0);
    });

    test('fall back boundary 2026-10-25 01:00 UTC', () {
      final before = DateTime.utc(2026, 10, 25, 0, 59);
      final at = DateTime.utc(2026, 10, 25, 1);
      expect(EuropeRomeTime.isDaylightSaving(before), isTrue);
      expect(EuropeRomeTime.isDaylightSaving(at), isFalse);
      expect(EuropeRomeTime.wallClock(before).hour, 2);
      expect(EuropeRomeTime.wallClock(before).minute, 59);
      expect(EuropeRomeTime.wallClock(at).hour, 2);
      expect(EuropeRomeTime.wallClock(at).minute, 0);
    });

    test('ISO Z parse keeps instant; display is Rome not raw UTC fields', () {
      final parsed = DateTime.parse('2026-10-21T18:56:00Z');
      expect(parsed.isUtc, isTrue);
      expect(parsed.hour, 18);
      expect(
        GuidaDateTimeFormat.formatItalianDateTime(parsed),
        '21 ottobre 2026 · 20:56',
      );
    });

    test('ISO +00:00 parse', () {
      final parsed = DateTime.parse('2026-01-21T18:00:00+00:00');
      expect(
        GuidaDateTimeFormat.formatItalianDateTime(parsed),
        '21 gennaio 2026 · 19:00',
      );
    });

    test('no fixed +1/+2 — winter and summer differ by 1h for same UTC clock', () {
      final winter = EuropeRomeTime.wallClock(DateTime.utc(2026, 1, 15, 12));
      final summer = EuropeRomeTime.wallClock(DateTime.utc(2026, 7, 15, 12));
      expect(summer.hour - winter.hour, 1);
    });
  });
}
