import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/services/html_splash_lifecycle.dart';
import 'package:scuola_nautica_liana/utils/startup_intro_policy.dart';

void main() {
  setUp(() {
    HtmlSplashLifecycle.resetForTest();
  });

  group('STARTUP.DECISIVE intro policy', () {
    test('ready a 500ms equiv → no remove', () {
      expect(
        shouldRemoveStartupIntro(
          welcomeOrSurfaceReady: true,
          minimumIntroElapsed: false,
        ),
        isFalse,
      );
    });

    test('ready + min elapsed → remove', () {
      expect(
        shouldRemoveStartupIntro(
          welcomeOrSurfaceReady: true,
          minimumIntroElapsed: true,
        ),
        isTrue,
      );
    });

    test('min elapsed senza ready → no remove', () {
      expect(
        shouldRemoveStartupIntro(
          welcomeOrSurfaceReady: false,
          minimumIntroElapsed: true,
        ),
        isFalse,
      );
    });

    test('startupIntroMinMs == 1500', () {
      expect(startupIntroMinMs, 1500);
      expect(
        HtmlSplashLifecycle.minimumIntro,
        const Duration(milliseconds: 1500),
      );
    });
  });

  group('STARTUP.DECISIVE HtmlSplashLifecycle gate', () {
    test('Welcome ready prima del min → splash NON rimossa', () {
      HtmlSplashLifecycle.ensureIntroStarted();
      HtmlSplashLifecycle.markWelcomeVisualReady();
      expect(HtmlSplashLifecycle.welcomeVisualReadyDispatchedForTest, isTrue);
      expect(HtmlSplashLifecycle.introRemovedForTest, isFalse);
    });

    test('Welcome ready + min elapsed → splash rimossa', () {
      HtmlSplashLifecycle.ensureIntroStarted();
      HtmlSplashLifecycle.markWelcomeVisualReady();
      HtmlSplashLifecycle.debugForceMinimumElapsed();
      expect(HtmlSplashLifecycle.minimumIntroElapsedForTest, isTrue);
      expect(HtmlSplashLifecycle.introRemovedForTest, isTrue);
    });

    test('min elapsed ma Welcome non ready → splash presente', () {
      HtmlSplashLifecycle.ensureIntroStarted();
      HtmlSplashLifecycle.debugForceMinimumElapsed();
      expect(HtmlSplashLifecycle.minimumIntroElapsedForTest, isTrue);
      expect(HtmlSplashLifecycle.introRemovedForTest, isFalse);
    });

    test('Welcome ready dopo min → splash rimossa a readiness', () {
      HtmlSplashLifecycle.ensureIntroStarted();
      HtmlSplashLifecycle.debugForceMinimumElapsed();
      expect(HtmlSplashLifecycle.introRemovedForTest, isFalse);
      HtmlSplashLifecycle.markWelcomeVisualReady();
      expect(HtmlSplashLifecycle.introRemovedForTest, isTrue);
    });

    test('markWelcomeVisualReady one-shot', () {
      HtmlSplashLifecycle.ensureIntroStarted();
      HtmlSplashLifecycle.markWelcomeVisualReady();
      expect(HtmlSplashLifecycle.welcomeVisualReadyDispatchedForTest, isTrue);
      HtmlSplashLifecycle.markWelcomeVisualReady();
      expect(HtmlSplashLifecycle.welcomeVisualReadyDispatchedForTest, isTrue);
    });
  });

  testWidgets(
    'STARTUP.DECISIVE Welcome first frame → visual ready (attende min)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
      await tester.pump();
      expect(HtmlSplashLifecycle.welcomeVisualReadyDispatchedForTest, isTrue);
      expect(HtmlSplashLifecycle.introRemovedForTest, isFalse);
    },
  );

  test('STARTUP.DECISIVE index.html: no first-frame removal; title present', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('liana-splash'));
    expect(html, contains('liana-splash-title'));
    expect(html, contains('background-color: #00BFFF'));
    expect(html, contains('theme-color" content="#005E83"'));
    // Root Navy (status bar), Capri solo overlay.
    expect(
      RegExp(r'html,\s*body\s*\{[^}]*background-color:\s*#005E83', multiLine: true)
          .hasMatch(html),
      isTrue,
    );
    // Titolo nello splash (oltre al <title> head).
    expect(html, contains('class="liana-splash-title"'));
    expect(
      html,
      isNot(contains("addEventListener('flutter-first-frame'")),
    );
    // Rimozione non più via custom event JS.
    expect(html, isNot(contains("addEventListener('liana-welcome-visual-ready'")));
  });
}
