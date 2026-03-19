import 'package:flutter/material.dart';

import 'lesson_quiz_list_page.dart';

class LessonListPage extends StatelessWidget {
  const LessonListPage({super.key});

  static const int _lessonCount = 14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lezioni'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lessonCount,
        itemBuilder: (context, index) {
          final lessonNumber = index + 1;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text('Lezione $lessonNumber'),
              subtitle: Text('Argomento $lessonNumber'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LessonQuizListPage(lessonNumber: lessonNumber),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
