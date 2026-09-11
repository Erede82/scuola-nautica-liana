import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/auth_gate_bootstrap.dart';

void main() {
  group('FRONT.8 auth gate ready policy', () {
    test('auth complete + hero pending → not ready', () {
      expect(
        isAuthGateReady(authComplete: true, heroWarmupComplete: false),
        isFalse,
      );
    });

    test('auth pending + hero complete → not ready', () {
      expect(
        isAuthGateReady(authComplete: false, heroWarmupComplete: true),
        isFalse,
      );
    });

    test('auth complete + hero complete → ready', () {
      expect(
        isAuthGateReady(authComplete: true, heroWarmupComplete: true),
        isTrue,
      );
    });
  });

  group('FRONT.8 waitAuthGateBootstrap parallel', () {
    test('attende entrambi i future', () async {
      final auth = Completer<void>();
      final hero = Completer<void>();
      var done = false;

      final wait = waitAuthGateBootstrap(
        authBootstrap: auth.future,
        heroWarmup: hero.future,
      ).then((_) => done = true);

      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      auth.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      hero.complete();
      await wait;
      expect(done, isTrue);
    });

    test('ordine inverso: hero prima di auth', () async {
      final auth = Completer<void>();
      final hero = Completer<void>();
      var done = false;

      final wait = waitAuthGateBootstrap(
        authBootstrap: auth.future,
        heroWarmup: hero.future,
      ).then((_) => done = true);

      hero.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      auth.complete();
      await wait;
      expect(done, isTrue);
    });
  });
}
