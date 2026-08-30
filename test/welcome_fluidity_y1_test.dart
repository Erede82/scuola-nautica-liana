import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_asset_hints.dart';

Widget _welcomeHarness() => const MaterialApp(home: WelcomePage());

Finder _outerScrollView() => find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.physics is ClampingScrollPhysics,
    );

Finder _outerScrollable() => find
    .descendant(
      of: _outerScrollView(),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _outerPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_outerScrollable()).position;

Finder _heroInnerScrollView() => find.byWidgetPredicate(
      (w) =>
          w is SingleChildScrollView &&
          w.physics is NeverScrollableScrollPhysics,
    );

void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_welcomeHarness());
  await tester.pumpAndSettle();
  _drainKnownOverflow(tester);
}

void main() {
  group('PWA.7-Y1 nested scroll ownership', () {
    for (final size in const [
      Size(375, 812),
      Size(390, 844),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()}: inner NeverScrollable, outer owns drag',
        (tester) async {
          await _pumpAt(tester, size);

          expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
          expect(_heroInnerScrollView(), findsOneWidget);

          final before = _outerPosition(tester).pixels;
          // Drag sull'inner hero (NeverScrollable) → deve muovere l'outer.
          final innerScrollable = find.descendant(
            of: _heroInnerScrollView(),
            matching: find.byType(Scrollable),
          );
          await tester.drag(innerScrollable, const Offset(0, -120));
          await tester.pump();
          _drainKnownOverflow(tester);
          await tester.pump(const Duration(milliseconds: 50));

          expect(_outerPosition(tester).pixels, greaterThan(before));
        },
      );
    }

    testWidgets('cramped <720: inner resta scrollabile', (tester) async {
      await _pumpAt(tester, const Size(390, 700));

      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
      expect(_heroInnerScrollView(), findsNothing);

      final compactInners = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView &&
            w.physics is! ClampingScrollPhysics &&
            w.physics is! NeverScrollableScrollPhysics,
      );
      // physics null = default (scrollabile) sull'inner cramped.
      expect(compactInners, findsOneWidget);

      expect(find.text('Accedi'), findsOneWidget);
      expect(find.text('Registrati'), findsOneWidget);
      expect(find.text('SCOPRICI'), findsOneWidget);
    });

    testWidgets('micro-drag sopra touchSlop muove outer (390×844)', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(390, 844));

      final before = _outerPosition(tester).pixels;
      final innerScrollable = find.descendant(
        of: _heroInnerScrollView(),
        matching: find.byType(Scrollable),
      );
      final start = tester.getCenter(innerScrollable);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(0, -(kTouchSlop + 24)));
      await gesture.up();
      await tester.pump();
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 16));

      expect(_outerPosition(tester).pixels, greaterThan(before));
    });
  });

  group('PWA.7-Y1 classroom cacheWidth', () {
    testWidgets('compact: classroom usa decode limitato', (tester) async {
      await _pumpAt(tester, const Size(390, 844));

      // Scorri fino alle card Discover per forzare build delle Image.
      await tester.drag(_outerScrollable(), const Offset(0, -800));
      await tester.pumpAndSettle();
      _drainKnownOverflow(tester);

      final classroomImages = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image;
        if (provider is ResizeImage) {
          final inner = provider.imageProvider;
          return inner is AssetImage &&
              inner.assetName == AppBranding.welcomeClassroomJpg;
        }
        if (provider is AssetImage) {
          return provider.assetName == AppBranding.welcomeClassroomJpg;
        }
        return false;
      });

      expect(classroomImages, findsWidgets);
      for (final element in classroomImages.evaluate()) {
        final image = element.widget as Image;
        expect(
          image.image,
          isA<ResizeImage>(),
          reason: 'classroom non deve essere full-res su compact',
        );
      }
    });

    testWidgets('desktop ≥900: classroom può restare full-res', (tester) async {
      await _pumpAt(tester, const Size(1200, 900));

      await tester.drag(_outerScrollable(), const Offset(0, -600));
      await tester.pumpAndSettle();
      _drainKnownOverflow(tester);

      final classroomImages = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image;
        if (provider is AssetImage) {
          return provider.assetName == AppBranding.welcomeClassroomJpg;
        }
        if (provider is ResizeImage) {
          final inner = provider.imageProvider;
          return inner is AssetImage &&
              inner.assetName == AppBranding.welcomeClassroomJpg;
        }
        return false;
      });

      expect(classroomImages, findsWidgets);
      for (final element in classroomImages.evaluate()) {
        final image = element.widget as Image;
        expect(image.image, isA<AssetImage>());
      }
    });
  });

  group('PWA.7-Y1 StartupVisualShell cacheWidth', () {
    testWidgets('compact: boat decode usa heroCacheWidth', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late int? expected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expected = WelcomeAssetHints.heroCacheWidth(context);
              return const StartupVisualShell();
            },
          ),
        ),
      );
      await tester.pump();

      expect(expected, isNotNull);
      final boat = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image;
        if (provider is! ResizeImage) return false;
        final inner = provider.imageProvider;
        return inner is AssetImage &&
            inner.assetName == AppBranding.welcomeBoatJpg;
      });
      expect(boat, findsOneWidget);
      final image = tester.widget<Image>(boat);
      final resize = image.image as ResizeImage;
      expect(resize.width, expected);
    });
  });

  group('WelcomeAssetHints', () {
    testWidgets('heroCacheWidth compact clamp', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 3,
          ),
          child: Builder(
            builder: (context) {
              final w = WelcomeAssetHints.heroCacheWidth(context)!;
              expect(w, inInclusiveRange(960, 1600));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('discoverCardCacheWidth compact non-null', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 3,
          ),
          child: Builder(
            builder: (context) {
              expect(
                WelcomeAssetHints.discoverCardCacheWidth(context),
                isNotNull,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
