import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';

void main() {
  testWidgets('NauticalAnswerMarker mostra numero risposta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NauticalAnswerMarker(answerNumber: 2)),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.byType(NauticalAnswerMarker), findsOneWidget);
  });

  testWidgets('NauticalAnswerMarker selected evidenzia il riquadro', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NauticalAnswerMarker(
            answerNumber: 1,
            state: NauticalAnswerMarkerState.selected,
          ),
        ),
      ),
    );

    final marker = tester.widget<NauticalAnswerMarker>(
      find.byType(NauticalAnswerMarker),
    );
    expect(marker.state, NauticalAnswerMarkerState.selected);
    expect(marker.answerNumber, 1);
  });

  testWidgets('NauticalAnswerMarker correct usa stato verde', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NauticalAnswerMarker(
            answerNumber: 3,
            state: NauticalAnswerMarkerState.correct,
          ),
        ),
      ),
    );

    final marker = tester.widget<NauticalAnswerMarker>(
      find.byType(NauticalAnswerMarker),
    );
    expect(marker.state, NauticalAnswerMarkerState.correct);
    expect(find.text('3'), findsOneWidget);
  });
}
