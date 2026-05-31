import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/course_taxonomy.dart';
import '../domain/enrollment_content_mapping.dart';
import '../models/license_models.dart';
import '../services/demo_student_enrollment.dart';
import 'lesson_list_page.dart';
import 'quiz_exam_page.dart';
import 'statistics_page.dart';
import '../theme/app_visual_tokens.dart';

enum CategoryDestination {
  lessons,
  quizExam,
  statistics,
}

class CategorySelectionPage extends StatefulWidget {
  const CategorySelectionPage({
    super.key,
    required this.destination,
  });

  final CategoryDestination destination;

  @override
  State<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: CategorySelectionPage init dest=${widget.destination}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleForDestination(widget.destination);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(title),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<EnrollmentCoursePath>(
        valueListenable: demoStudentEnrollmentPath,
        builder: (context, enrollmentPath, _) {
          final categories = _categoriesVisibleForEnrollment(enrollmentPath);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'Percorso iscrizione (demo): ${enrollmentPath.labelIt}',
                style: textTheme.titleSmall?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vedi le aree contenuto collegate al tuo percorso. Puoi cambiare il percorso '
                'demo da Profilo per provare D1 o Entro le 12 miglia motore + Vela.',
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ...categories.map(
                (category) => _CategoryCard(
                  category: category,
                  onOpenActive: () => _handleCategoryTap(context, category),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleCategoryTap(BuildContext context, LicenseCategory category) {
    qfLog(
      'CategorySelection: open category id=${category.id} name=${category.name} dest=${widget.destination}',
    );
    switch (widget.destination) {
      case CategoryDestination.lessons:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LessonListPage(categoryId: category.id),
          ),
        );
      case CategoryDestination.quizExam:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => QuizExamPage(categoryId: category.id),
          ),
        );
      case CategoryDestination.statistics:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => StatisticsPage(categoryId: category.id),
          ),
        );
    }
  }

  static String _titleForDestination(CategoryDestination destination) {
    switch (destination) {
      case CategoryDestination.lessons:
        return 'Categoria Lezioni';
      case CategoryDestination.quizExam:
        return 'Categoria Quiz Esame';
      case CategoryDestination.statistics:
        return 'Categoria Statistiche';
    }
  }
}

List<LicenseCategory> _categoriesVisibleForEnrollment(EnrollmentCoursePath path) {
  return EnrollmentContentMapping.contentModulesForPath(path)
      .map(
        (m) => LicenseCatalog.byId(
          EnrollmentContentMapping.contentModuleToLicenseCategoryId(m),
        ),
      )
      .toList();
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onOpenActive,
  });

  final LicenseCategory category;
  final VoidCallback onOpenActive;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _secondaryColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final isEnabled = category.isAvailable;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = isEnabled ? _secondaryColor : _neutralColor;
    final iconColor = isEnabled ? _primaryColor : Colors.blueGrey;
    final trailingColor = isEnabled ? _secondaryColor : Colors.blueGrey;
    final subtitle = _subtitleFor(category, isEnabled);

    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: ListTile(
        onTap: () {
          if (!isEnabled) {
            _showBlockedCategoryDialog(context, category);
            return;
          }
          onOpenActive();
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isEnabled
                ? _primaryColor.withValues(alpha: 0.12)
                : _neutralColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForCategory(category.id),
            color: iconColor,
          ),
        ),
        title: Text(
          category.name,
          style: textTheme.titleMedium?.copyWith(
            color: _textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: isEnabled ? _primaryColor : Colors.blueGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          isEnabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
          size: 18,
          color: trailingColor,
        ),
      ),
    );
  }

  static String _subtitleFor(LicenseCategory category, bool isEnabled) {
    if (!isEnabled) {
      return category.id == LicenseCategoryId.vela
          ? 'Contenuti vela in preparazione · Disponibile prossimamente'
          : category.comingSoonLabel;
    }
    switch (category.id) {
      case LicenseCategoryId.d1:
        return 'D1 disponibile · Percorso attivo';
      case LicenseCategoryId.motore:
        return 'Entro le 12 miglia motore · Percorso attivo';
      case LicenseCategoryId.vela:
        return 'Contenuti vela in preparazione';
    }
  }

  static Future<void> _showBlockedCategoryDialog(
    BuildContext context,
    LicenseCategory category,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disponibile prossimamente'),
        content: Text(
          category.id == LicenseCategoryId.vela
              ? 'Contenuti vela in preparazione. Stiamo completando le lezioni e le schede: '
                  'ti avviseremo quando saranno pronti.'
              : 'Questa area non è ancora disponibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
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
