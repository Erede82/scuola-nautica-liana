import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ScuolaNauticaLianaApp());

    expect(find.text('Scuola Nautica Liana'), findsOneWidget);
    expect(
      find.text('Benvenuto nella tua app per i quiz nautici'),
      findsOneWidget,
    );
  });
}
