import 'package:flutter/material.dart';

class LessonQuizListPage extends StatelessWidget {
  const LessonQuizListPage({
    super.key,
    required this.lessonNumber,
  });

  final int lessonNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schede Lezione $lessonNumber'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Qui verranno mostrate le schede quiz della lezione $lessonNumber',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
