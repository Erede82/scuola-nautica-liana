import 'package:flutter/material.dart';

enum LicenseCategoryId {
  motore,
  vela,
  d1,
}

enum QuizSheetProgress {
  todo,
  completed,
  review,
}

extension QuizSheetProgressX on QuizSheetProgress {
  bool get isDone => this == QuizSheetProgress.completed || this == QuizSheetProgress.review;
}

class QuizSheetItem {
  const QuizSheetItem({
    required this.sheetNumber,
    required this.progress,
    this.errorCount,
  });

  final int sheetNumber;
  final QuizSheetProgress progress;
  final int? errorCount;
}

class LessonItem {
  const LessonItem({
    required this.number,
    required this.title,
    required this.quizSheets,
    required this.icon,
  });

  final int number;
  final String title;
  final int quizSheets;
  final IconData icon;
}

class LicenseCategory {
  const LicenseCategory({
    required this.id,
    required this.name,
    required this.lessons,
    this.isAvailable = false,
    this.comingSoonLabel = 'Disponibile prossimamente',
  });

  final LicenseCategoryId id;
  final String name;
  final List<LessonItem> lessons;
  final bool isAvailable;
  final String comingSoonLabel;
}
