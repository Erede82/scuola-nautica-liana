import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/html_splash_lifecycle.dart';
import 'package:scuola_nautica_liana/services/html_splash_lifecycle_stub.dart'
    as stub;
import 'package:scuola_nautica_liana/theme/app_visual_tokens.dart';

void main() {
  setUp(HtmlSplashLifecycle.resetForTest);

  test('STARTUP.DECISIVE / RELEASE.FINAL theme handoff → navy #005E83', () {
    expect(AppVisual.logoBlue, const Color(0xFF005E83));

    HtmlSplashLifecycle.ensureIntroStarted();
    expect(stub.stubThemeNavyApplied, isFalse);

    HtmlSplashLifecycle.markWelcomeVisualReady();
    HtmlSplashLifecycle.debugForceMinimumElapsed();

    expect(HtmlSplashLifecycle.introRemovedForTest, isTrue);
    expect(stub.stubThemeNavyApplied, isTrue);
    expect(stub.stubSplashRemoved, isTrue);
  });
}
