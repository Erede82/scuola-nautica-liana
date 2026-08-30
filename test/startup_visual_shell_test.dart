import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_auth_gate.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartupVisualShell renderizza senza crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StartupVisualShell()),
    );
    expect(find.byType(StartupVisualShell), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('AppAuthGate senza sessione arriva a Welcome senza crash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppAuthGate()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
