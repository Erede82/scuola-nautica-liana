import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ScuolaNauticaLianaApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Scuola Nautica Liana'),
      findsWidgets,
    );
    expect(find.text('Accedi'), findsOneWidget);
  });
}
