import 'package:flutter/material.dart';

class QuizExamPage extends StatelessWidget {
  const QuizExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Esame'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Quiz Esame',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
