import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ScuolaNauticaLianaApp());
    await tester.pump();

    // FRONT.8: AppAuthGate attende hero precache (async asset decode).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Accedi').evaluate().isNotEmpty) break;
    }

    expect(
      find.textContaining('Scuola Nautica Liana'),
      findsWidgets,
    );
    expect(find.text('Accedi'), findsOneWidget);
  });
}
