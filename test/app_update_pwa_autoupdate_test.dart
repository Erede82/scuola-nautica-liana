import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/app_update/anti_loop_storage.dart';
import 'package:scuola_nautica_liana/services/app_update/app_build_info.dart';
import 'package:scuola_nautica_liana/services/app_update/app_update_coordinator.dart';
import 'package:scuola_nautica_liana/services/app_update/remote_app_version.dart';
import 'package:scuola_nautica_liana/services/app_update/stripe_checkout_guard.dart';
import 'package:scuola_nautica_liana/services/app_update/update_protected_dialog.dart';
import 'package:scuola_nautica_liana/services/app_update/update_protected_mutation.dart';
import 'package:scuola_nautica_liana/services/app_update/version_fetcher.dart';
import 'package:scuola_nautica_liana/widgets/app_update/app_version_info.dart';
import 'package:scuola_nautica_liana/widgets/app_update/update_available_banner.dart';

void main() {
  group('RemoteAppVersion', () {
    test('parse remote version', () {
      final remote = RemoteAppVersion.tryParse('''
        {"app_version":"2026.09.15.2","commit":"a708a58","built_at":"2026-09-15T10:00:00Z","version":"1.0.0"}
      ''');
      expect(remote, isNotNull);
      expect(remote!.appVersion, '2026.09.15.2');
      expect(remote.commit, 'a708a58');
      expect(remote.builtAt, '2026-09-15T10:00:00Z');
      expect(remote.raw['version'], '1.0.0');
    });

    test('invalid JSON ignored', () {
      expect(RemoteAppVersion.tryParse('{not json'), isNull);
    });

    test('missing app_version ignored', () {
      expect(RemoteAppVersion.tryParse('{"commit":"abc"}'), isNull);
    });
  });

  group('AppBuildInfo', () {
    test('production pattern accepts YYYY.MM.DD.N', () {
      expect(
        AppBuildInfo.productionVersionPattern.hasMatch('2026.09.15.1'),
        isTrue,
      );
    });

    test('local dev disables checker semantics', () {
      expect(AppBuildInfo.isDev, isTrue);
      expect(AppBuildInfo.isUpdateCheckerEnabled, isFalse);
    });
  });

  group('version comparison via fetch', () {
    test('same version → no update', () async {
      final coordinator = _freshCoordinator();
      coordinator.versionJsonFetcher = (_) async => jsonEncode({
        'app_version': AppBuildInfo.version,
      });
      await coordinator.checkForUpdate(force: true);
      expect(coordinator.updateAvailable, isFalse);
    });

    test('different version → update available', () async {
      final coordinator = _freshCoordinator();
      coordinator.versionJsonFetcher = (_) async => jsonEncode({
        'app_version': '2099.01.01.1',
      });
      await coordinator.checkForUpdate(force: true);
      expect(coordinator.updateAvailable, isTrue);
      expect(coordinator.remoteAppVersion, '2099.01.01.1');
    });

    test('offline/fetch exception → silent', () async {
      final coordinator = _freshCoordinator();
      coordinator.versionJsonFetcher = (_) async => throw Exception('offline');
      await expectLater(
        coordinator.checkForUpdate(force: true),
        completes,
      );
      expect(coordinator.updateAvailable, isFalse);
    });

    test('server error → silent', () async {
      final coordinator = _freshCoordinator();
      coordinator.versionJsonFetcher = (_) async => null;
      await coordinator.checkForUpdate(force: true);
      expect(coordinator.updateAvailable, isFalse);
    });

    test('malformed response → silent', () async {
      final coordinator = _freshCoordinator();
      coordinator.versionJsonFetcher = (_) async => 'not-json';
      await coordinator.checkForUpdate(force: true);
      expect(coordinator.updateAvailable, isFalse);
    });
  });

  group('AppUpdateCoordinator safety', () {
    test('safe + update → auto reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 1);
    });

    test('unsafe dialog + update → no reload/banner', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..beginUnsafeWork()
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 0);
      expect(coordinator.bannerVisible, isTrue);
    });

    test('mutation + update → no reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..beginMutation()
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 0);
    });

    test('unsafe closes → auto reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..unsafeCloseDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..beginUnsafeWork();
      coordinator.endUnsafeWork();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reloads, 1);
    });

    test('mutation completes → auto reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..unsafeCloseDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..beginMutation();
      coordinator.endMutation();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reloads, 1);
    });

    test('update now safe → reload', () {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator.setRemoteForTest('2099.01.01.1');
      coordinator.updateNow();
      expect(reloads, 1);
    });

    test('update now unsafe → no reload', () {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..setRemoteForTest('2099.01.01.1')
        ..beginUnsafeWork()
        ..updateNow();
      expect(reloads, 0);
      expect(coordinator.bannerVisible, isTrue);
    });

    test('Più tardi → no reload per defer window', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..deferUpdate()
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 0);
      expect(coordinator.bannerVisible, isFalse);
    });

    test('Stripe checkout defers reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      StripeCheckoutGuard.beginCheckout();
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 0);
      StripeCheckoutGuard.endCheckout();
    });

    test('Extra return unknown releases Stripe guard', () {
      StripeCheckoutGuard.resetForTest();
      final kind = protectExtraCheckoutReturn('weird-value');
      expect(kind, ExtraCheckoutReturnKind.unknown);
      expect(StripeCheckoutGuard.isCheckoutPending, isFalse);
    });

    test('Extra return cancel releases Stripe guard', () {
      StripeCheckoutGuard.resetForTest();
      final kind = protectExtraCheckoutReturn('cancel');
      expect(kind, ExtraCheckoutReturnKind.cancel);
      expect(StripeCheckoutGuard.isCheckoutPending, isFalse);
    });

    test('Extra return success keeps guard until endCheckout', () {
      StripeCheckoutGuard.resetForTest();
      final kind = protectExtraCheckoutReturn('success');
      expect(kind, ExtraCheckoutReturnKind.success);
      expect(StripeCheckoutGuard.isCheckoutPending, isTrue);
      StripeCheckoutGuard.endCheckout();
      expect(StripeCheckoutGuard.isCheckoutPending, isFalse);
    });

    test('Studio write mutation blocks then releases reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () {
        reloads++;
      };
      coordinator
        ..unsafeCloseDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1');

      await runUpdateProtectedMutation(() async {
        expect(coordinator.activeMutationCount, greaterThan(0));
        coordinator.scheduleAutoApplyForTest();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(reloads, 0);
      });

      expect(coordinator.activeMutationCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reloads, 1);
    });
  });

  group('anti-loop', () {
    test('same remote attempted recently → no second auto reload', () async {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      AntiLoopStorage.writeLastAttemptedRemoteVersion('2099.01.01.1');
      AntiLoopStorage.writeLastReloadTimestamp(DateTime.now().toUtc());
      coordinator
        ..safeApplyDebounceDuration = Duration.zero
        ..setRemoteForTest('2099.01.01.1')
        ..scheduleAutoApplyForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloads, 0);
      expect(coordinator.bannerVisible, isTrue);
    });

    test('CDN stale scenario → no loop', () {
      final coordinator = _freshCoordinator();
      var reloads = 0;
      coordinator.reloadAdapter = () => reloads++;
      coordinator.setRemoteForTest('2099.01.01.1');
      coordinator.updateNow();
      expect(reloads, 1);

      coordinator.resetForTest();
      coordinator
        ..debugForceCheckerEnabled = true
        ..reloadAdapter = () => reloads++;
      coordinator.setRemoteForTest('2099.01.01.1');
      AntiLoopStorage.writeLastAttemptedRemoteVersion('2099.01.01.1');
      AntiLoopStorage.writeLastReloadTimestamp(DateTime.now().toUtc());
      coordinator.updateNow();
      expect(reloads, 1);
    });
  });

  group('lifecycle scheduling', () {
    test('startup schedules check', () async {
      final coordinator = _freshCoordinator();
      var checks = 0;
      coordinator.versionJsonFetcher = (_) async {
        checks++;
        return jsonEncode({'app_version': AppBuildInfo.version});
      };
      coordinator.installLifecycle(startupDelayOverride: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(checks, greaterThanOrEqualTo(1));
      coordinator.disposeLifecycle();
    });

    test('resume triggers check', () async {
      final coordinator = _freshCoordinator();
      var checks = 0;
      coordinator.versionJsonFetcher = (_) async {
        checks++;
        return null;
      };
      coordinator.onAppResumed();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(checks, 1);
    });

    test('visibility visible triggers check', () async {
      final coordinator = _freshCoordinator();
      var checks = 0;
      coordinator.versionJsonFetcher = (_) async {
        checks++;
        return null;
      };
      coordinator.onVisibilityVisible();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(checks, 1);
    });

    test('15-min timer triggers check', () async {
      final coordinator = _freshCoordinator();
      var checks = 0;
      coordinator
        ..periodicIntervalDuration = const Duration(milliseconds: 40)
        ..minCheckIntervalDuration = Duration.zero
        ..versionJsonFetcher = (_) async {
          checks++;
          return null;
        };
      coordinator.installLifecycle(startupDelayOverride: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(checks, greaterThanOrEqualTo(2));
      coordinator.disposeLifecycle();
    });

    test('duplicate lifecycle events debounced', () async {
      final coordinator = _freshCoordinator();
      var checks = 0;
      coordinator.versionJsonFetcher = (_) async {
        checks++;
        return null;
      };
      coordinator
        ..onAppResumed()
        ..onVisibilityVisible();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(checks, 1);
    });
  });

  group('protected helpers', () {
    testWidgets('protected dialog increments unsafe refcount', (tester) async {
      final coordinator = AppUpdateCoordinator.instance..resetForTest();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showUpdateProtectedDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Test dialog'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Chiudi'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(coordinator.unsavedWorkCount, 1);
      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      expect(coordinator.unsavedWorkCount, 0);
    });

    test('runUpdateProtectedMutation refcount', () async {
      final coordinator = AppUpdateCoordinator.instance..resetForTest();
      final future = runUpdateProtectedMutation(() async {
        expect(coordinator.activeMutationCount, 1);
        return 42;
      });
      expect(coordinator.activeMutationCount, 1);
      expect(await future, 42);
      expect(coordinator.activeMutationCount, 0);
    });
  });

  group('Update banner UI', () {
    testWidgets('banner text and buttons', (tester) async {
      final coordinator = AppUpdateCoordinator.instance..resetForTest();
      coordinator
        ..setRemoteForTest('2099.01.01.1')
        ..beginUnsafeWork();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                UpdateAvailableBanner(coordinator: coordinator),
              ],
            ),
          ),
        ),
      );
      expect(find.text(UpdateAvailableBanner.message), findsOneWidget);
      expect(find.text(UpdateAvailableBanner.updateNowLabel), findsOneWidget);
      expect(find.text(UpdateAvailableBanner.laterLabel), findsOneWidget);
      expect(find.text(UpdateAvailableBanner.unsafeHint), findsOneWidget);
    });

    testWidgets('responsive ~390px', (tester) async {
      final coordinator = AppUpdateCoordinator.instance..resetForTest();
      coordinator
        ..setRemoteForTest('2099.01.01.1')
        ..beginUnsafeWork();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: Stack(
                children: [
                  UpdateAvailableBanner(coordinator: coordinator),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text(UpdateAvailableBanner.message), findsOneWidget);
    });

    testWidgets('version UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppVersionInfo())),
      );
      expect(find.textContaining('Versione'), findsOneWidget);
      expect(find.textContaining('Build'), findsOneWidget);
    });
  });

  group('fetchRemoteAppVersion', () {
    test('uses cache bust query param', () async {
      String? captured;
      await fetchRemoteAppVersion(
        fetcher: (url) async {
          captured = url;
          return '{"app_version":"1.2.3"}';
        },
        cacheBustEpochMs: 123456789,
      );
      expect(captured, '/version.json?t=123456789');
    });
  });
}

AppUpdateCoordinator _freshCoordinator() {
  final coordinator = AppUpdateCoordinator.instance
    ..resetForTest()
    ..debugForceCheckerEnabled = true;
  return coordinator;
}
