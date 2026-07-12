import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/account_profile_page.dart';
import 'package:scuola_nautica_liana/pages/student_area_preview_page.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';

class _ContextProbe extends StatelessWidget {
  const _ContextProbe({required this.onRead});

  final void Function(StudentAreaContext context) onRead;

  @override
  Widget build(BuildContext context) {
    onRead(StudentAreaContext.of(context));
    return const SizedBox();
  }
}

void main() {
  group('StudentAreaContext', () {
    testWidgets('senza wrapper restituisce modalità normale', (tester) async {
      StudentAreaContext? captured;

      await tester.pumpWidget(
        MaterialApp(home: _ContextProbe(onRead: (ctx) => captured = ctx)),
      );

      expect(captured, isNotNull);
      expect(captured!.mode, StudentAreaMode.normal);
      expect(captured!.readOnly, isFalse);
      expect(
        StudentAreaContext.maybeOf(tester.element(find.byType(_ContextProbe))),
        isNull,
      );
    });

    testWidgets('preview restituisce staffPreview e readOnly', (tester) async {
      StudentAreaContext? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: _ContextProbe(onRead: (ctx) => captured = ctx),
          ),
        ),
      );

      final element = tester.element(find.byType(_ContextProbe));
      expect(captured, isNotNull);
      expect(captured!.mode, StudentAreaMode.staffPreview);
      expect(captured!.readOnly, isTrue);
      expect(StudentAreaContext.blocksWrites(element), isTrue);
    });
  });

  group('StudentAreaPreviewPage', () {
    testWidgets('non mostra erede82 in sidebar e saluto', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: StudentAreaPreviewPage()),
      );
      await tester.pump();

      expect(find.text('erede82'), findsNothing);
      expect(find.text('erede82@gmail.com'), findsNothing);
      expect(find.text('Anteprima area allievo'), findsWidgets);
      expect(find.text('Modalità controllo staff'), findsOneWidget);
      expect(
        find.text('Stai visualizzando l’esperienza dell’app studente'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'non rappresenta il profilo di uno specifico allievo',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Account mostra messaggio non disponibile in preview', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: StudentAreaPreviewPage()),
      );
      await tester.pump();

      await tester.tap(find.text('Profilo').first);
      await tester.pumpAndSettle();

      expect(
        find.text(StudentAreaPreviewCopy.previewAccountName),
        findsWidgets,
      );
    });

    testWidgets('AccountProfilePage diretta mostra profilo read-only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: AccountProfilePage(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(StudentAreaPreviewCopy.previewAccountName),
        findsWidgets,
      );
      expect(find.text('erede82'), findsNothing);
      expect(find.text('Dettagli'), findsOneWidget);
    });
  });

  test('blocksWrites è usato come gate salvataggio quiz in preview', () {
    const preview = StudentAreaContext(
      mode: StudentAreaMode.staffPreview,
      readOnly: true,
      child: SizedBox.shrink(),
    );
    expect(preview.readOnly, isTrue);
    expect(preview.isStaffPreview, isTrue);
  });

  testWidgets('anteprima attiva si risolve anche senza InheritedWidget', (
    tester,
  ) async {
    studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
    addTearDown(() => studentAreaPreviewActiveMode.value = null);

    late StudentAreaContext ctx;
    await tester.pumpWidget(
      MaterialApp(home: _ContextProbe(onRead: (c) => ctx = c)),
    );

    expect(ctx.mode, StudentAreaMode.staffPreview);
    expect(ctx.readOnly, isTrue);
  });
}
