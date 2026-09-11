import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Specchietto della policy JS in web/index.html (nessuna dipendenza lib/).
bool shouldShowIosStatusSentinel({
  required bool isIOS,
  required bool isStandalone,
}) =>
    isIOS && isStandalone;

void main() {
  final html = File('${Directory.current.path}/web/index.html').readAsStringSync();

  test('RELEASE.IOS-SENTINEL CSS: 16px Navy, z < splash, pointer-events none', () {
    expect(html, contains('id="liana-ios-status-sentinel"'));
    expect(
      RegExp(
        r'#liana-ios-status-sentinel\s*\{[^}]*display:\s*none',
        multiLine: true,
      ).hasMatch(html),
      isTrue,
    );
    expect(
      RegExp(
        r'#liana-ios-status-sentinel\s*\{[^}]*height:\s*16px',
        multiLine: true,
      ).hasMatch(html),
      isTrue,
    );
    expect(
      RegExp(
        r'#liana-ios-status-sentinel\s*\{[^}]*background:\s*#005E83',
        multiLine: true,
      ).hasMatch(html),
      isTrue,
    );
    expect(
      RegExp(
        r'#liana-ios-status-sentinel\s*\{[^}]*pointer-events:\s*none',
        multiLine: true,
      ).hasMatch(html),
      isTrue,
    );
    expect(
      RegExp(
        r'#liana-ios-status-sentinel\s*\{[^}]*z-index:\s*9500',
        multiLine: true,
      ).hasMatch(html),
      isTrue,
    );
    expect(
      RegExp(r'#liana-splash\s*\{[^}]*z-index:\s*9999', multiLine: true)
          .hasMatch(html),
      isTrue,
    );
    // Nessun magic height diverso da 16px sul sentinel.
    expect(html, isNot(contains('liana-status-area')));
    expect(html, isNot(contains('viewport-fit=cover')));
  });

  test('RELEASE.IOS-SENTINEL JS attiva solo iOS + standalone', () {
    expect(html, contains("getElementById('liana-ios-status-sentinel')"));
    expect(html, contains('/iPad|iPhone|iPod/'));
    expect(html, contains("(display-mode: standalone)"));
    expect(html, contains('navigator.standalone'));
    expect(html, contains("setProperty('display', 'block')"));
    expect(html, contains('isIOS && isStandalone'));
  });

  test('RELEASE.IOS-SENTINEL policy matrix', () {
    expect(
      shouldShowIosStatusSentinel(isIOS: true, isStandalone: true),
      isTrue,
    );
    expect(
      shouldShowIosStatusSentinel(isIOS: true, isStandalone: false),
      isFalse,
      reason: 'iOS Safari normale = OFF',
    );
    expect(
      shouldShowIosStatusSentinel(isIOS: false, isStandalone: true),
      isFalse,
      reason: 'Android / desktop standalone = OFF',
    );
    expect(
      shouldShowIosStatusSentinel(isIOS: false, isStandalone: false),
      isFalse,
      reason: 'desktop browser = OFF',
    );
  });
}
