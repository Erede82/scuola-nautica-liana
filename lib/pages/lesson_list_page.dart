import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../models/license_models.dart';
import 'lesson_quiz_list_page.dart';
import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

class LessonListPage extends StatefulWidget {
  const LessonListPage({super.key, this.categoryId = LicenseCategoryId.motore});

  final LicenseCategoryId categoryId;

  @override
  State<LessonListPage> createState() => _LessonListPageState();
}

class _LessonListPageState extends State<LessonListPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _secondaryColor = Color(0xFF44BBCA);
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  void initState() {
    super.initState();
    qfLog('route: LessonListPage init categoryId=${widget.categoryId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = LicenseCatalog.byId(widget.categoryId);
    final lessons = category.lessons;
    final hasActiveLessons = category.isAvailable && lessons.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Lezioni'),
        centerTitle: true,
      ),
      body: hasActiveLessons
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  widget.categoryId == LicenseCategoryId.d1
                      ? 'Percorso D1 attivo: seleziona una lezione per aprire le schede quiz '
                          '(${category.name}). Le schede seguono le abilitazioni della scuola.'
                      : 'Seleziona una lezione per visualizzare le relative schede quiz '
                          '(${category.name}).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(lessons.length, (index) {
                  final lesson = lessons[index];

                  return Card(
                    color: _cardColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(lesson.icon, color: _primaryColor),
                      ),
                      title: Text(
                        lesson.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        '${lesson.quizSheets} schede',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _textPrimaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: _secondaryColor,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LessonQuizListPage(
                            lessonNumber: lesson.number,
                            categoryId: category.id,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            )
          : _LessonsEmptyState(
              categoryId: category.id,
              categoryName: category.name,
              isAvailable: category.isAvailable,
              onChooseAnotherCategory: () => Navigator.maybePop(context),
            ),
    );
  }
}

class _LessonsEmptyState extends StatelessWidget {
  const _LessonsEmptyState({
    required this.categoryId,
    required this.categoryName,
    required this.isAvailable,
    required this.onChooseAnotherCategory,
  });

  final LicenseCategoryId categoryId;
  final String categoryName;
  final bool isAvailable;
  final VoidCallback onChooseAnotherCategory;

  @override
  Widget build(BuildContext context) {
    final tagLabel =
        isAvailable ? 'Nessun contenuto' : 'Disponibile prossimamente';
    final message = isAvailable
        ? 'Nessuna lezione disponibile per questa categoria.'
        : (categoryId == LicenseCategoryId.vela
            ? 'Contenuti vela in preparazione. Le lezioni e le schede saranno disponibili '
                'non appena completati i materiali didattici.'
            : 'Contenuti lezioni in arrivo. Questa categoria sarà disponibile presto.');

    return AppEmptyState(
      title: categoryName,
      message: message,
      icon: _iconForCategory(categoryId),
      tagLabel: tagLabel,
      primaryActionLabel: 'Scegli un altra categoria',
      primaryActionIcon: Icons.arrow_back_rounded,
      onPrimaryActionPressed: onChooseAnotherCategory,
    );
  }

  static IconData _iconForCategory(LicenseCategoryId id) {
    switch (id) {
      case LicenseCategoryId.motore:
        return Icons.directions_boat_rounded;
      case LicenseCategoryId.vela:
        return Icons.sailing_rounded;
      case LicenseCategoryId.d1:
        return Icons.badge_rounded;
    }
  }
}
