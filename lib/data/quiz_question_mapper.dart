import '../models/quiz_question.dart';
import 'supabase/dto/question_row.dart';

abstract final class QuizQuestionMapper {
  static QuizQuestion? fromRow(QuestionRow row) {
    if (row.id.isEmpty || row.prompt.trim().isEmpty) return null;
    final correct = QuizAnswerOptionX.tryParse(row.correctOption);
    if (correct == null) return null;

    return QuizQuestion(
      id: row.id,
      prompt: row.prompt.trim(),
      optionA: row.optionA.trim(),
      optionB: row.optionB.trim(),
      optionC: row.optionC.trim(),
      correctOption: correct,
      imagePath: _trimOrNull(row.imagePath),
      explanation: _trimOrNull(row.explanation),
      lessonNumber: row.lessonNumber,
      licenseCategory: row.licenseCategory.trim(),
    );
  }

  static String? _trimOrNull(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}
