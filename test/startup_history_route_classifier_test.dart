import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/startup_diagnostics.dart';

void main() {
  group('historyRouteLabel', () {
    test('/#/ → root', () {
      expect(StartupDiagnostics.historyRouteLabel('/', '#/'), 'root');
      expect(StartupDiagnostics.historyRouteLabel('/', '#/'), 'root');
    });

    test('/#/login → login', () {
      expect(StartupDiagnostics.historyRouteLabel('/', '#/login'), 'login');
    });

    test('/#/register → register', () {
      expect(StartupDiagnostics.historyRouteLabel('/', '#/register'), 'register');
    });

    test('/#/forgot-password → forgot', () {
      expect(
        StartupDiagnostics.historyRouteLabel('/', '#/forgot-password'),
        'forgot',
      );
    });

    test('pathname root + hash vuoto → empty-hash', () {
      expect(StartupDiagnostics.historyRouteLabel('/', ''), 'empty-hash');
      expect(StartupDiagnostics.historyRouteLabel('/', '#'), 'empty-hash');
      expect(StartupDiagnostics.historyRouteLabel('', ''), 'empty-hash');
    });

    test('auth/recovery payload → auth-redacted', () {
      expect(
        StartupDiagnostics.historyRouteLabel(
          '/',
          '#access_token=secret&type=recovery',
        ),
        'auth-redacted',
      );
      expect(
        StartupDiagnostics.historyRouteLabel('/', ''),
        isNot('auth-redacted'),
      );
      expect(
        StartupDiagnostics.historyRouteLabel(
          '/',
          '#/login?code=abc',
        ),
        'auth-redacted',
      );
    });

    test('route sconosciuta → other', () {
      expect(
        StartupDiagnostics.historyRouteLabel('/', '#/students/secret'),
        'other',
      );
      expect(
        StartupDiagnostics.historyRouteLabel('/extra', '#/login'),
        'login',
      );
    });
  });

  group('formatHistoryEvent', () {
    test('formato base HISTORY', () {
      expect(
        StartupDiagnostics.formatHistoryEvent(
          event: 'popstate',
          historyLength: 3,
          route: 'login',
          visibility: 'visible',
          statePresent: true,
        ),
        'HISTORY event=popstate len=3 route=login visibility=visible '
        'statePresent=true',
      );
    });

    test('pageshow con persisted', () {
      expect(
        StartupDiagnostics.formatHistoryEvent(
          event: 'pageshow',
          historyLength: 2,
          route: 'root',
          visibility: 'visible',
          persisted: true,
        ),
        'HISTORY event=pageshow len=2 route=root visibility=visible '
        'persisted=true',
      );
    });

    test('hashchange senza URL raw', () {
      final line = StartupDiagnostics.formatHistoryEvent(
        event: 'hashchange',
        historyLength: 3,
        route: 'root',
        visibility: 'visible',
      );
      expect(line, contains('event=hashchange'));
      expect(line, isNot(contains('oldURL')));
      expect(line, isNot(contains('newURL')));
      expect(line, isNot(contains('href')));
    });
  });

  group('historyRouteLabelFromSettingsName', () {
    test('null/empty → root', () {
      expect(StartupDiagnostics.historyRouteLabelFromSettingsName(null), 'root');
      expect(StartupDiagnostics.historyRouteLabelFromSettingsName(''), 'root');
    });

    test('/login → login', () {
      expect(
        StartupDiagnostics.historyRouteLabelFromSettingsName('/login'),
        'login',
      );
    });
  });
}
