import 'package:flutter/material.dart';

class LessonListPage extends StatelessWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lezioni'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Lezioni',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
