import 'package:flutter/material.dart';

import '../../data/license_catalog.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';
import '../../theme/app_visual_tokens.dart';

/// Stato visivo di accesso a una lezione (tutte le schede quiz del catalogo).
enum LessonSheetAccessVisualStatus { unlocked, blocked, partial }

class LessonStudyAccessStatus {
  const LessonStudyAccessStatus({
    required this.status,
    required this.badgeLabel,
    required this.subtitle,
  });

  final LessonSheetAccessVisualStatus status;
  final String badgeLabel;
  final String subtitle;

  Color get backgroundColor {
    switch (status) {
      case LessonSheetAccessVisualStatus.unlocked:
        return const Color(0xFFE8F5EC);
      case LessonSheetAccessVisualStatus.blocked:
        return const Color(0xFFFCEEEF);
      case LessonSheetAccessVisualStatus.partial:
        return const Color(0xFFFFF4E5);
    }
  }

  Color get borderColor {
    switch (status) {
      case LessonSheetAccessVisualStatus.unlocked:
        return const Color(0xFF2E9E5B).withValues(alpha: 0.38);
      case LessonSheetAccessVisualStatus.blocked:
        return const Color(0xFFC62828).withValues(alpha: 0.28);
      case LessonSheetAccessVisualStatus.partial:
        return const Color(0xFFC27C1C).withValues(alpha: 0.38);
    }
  }

  Color get badgeColor {
    switch (status) {
      case LessonSheetAccessVisualStatus.unlocked:
        return const Color(0xFF2E9E5B);
      case LessonSheetAccessVisualStatus.blocked:
        return const Color(0xFFC62828);
      case LessonSheetAccessVisualStatus.partial:
        return const Color(0xFFC27C1C);
    }
  }

  IconData get badgeIcon {
    switch (status) {
      case LessonSheetAccessVisualStatus.unlocked:
        return Icons.lock_open_rounded;
      case LessonSheetAccessVisualStatus.blocked:
        return Icons.lock_rounded;
      case LessonSheetAccessVisualStatus.partial:
        return Icons.warning_amber_rounded;
    }
  }

  bool get isUnlockedForAction =>
      status == LessonSheetAccessVisualStatus.unlocked;

  String get primaryActionLabel =>
      isUnlockedForAction ? 'Blocca lezione' : 'Sblocca lezione';
}

LessonStudyAccessStatus resolveLessonSheetAccessStatus({
  required Iterable<LessonQuizSheetUnlock> sheetUnlocks,
  required LicenseCategoryId categoryId,
  required int lessonNumber,
  required int quizSheets,
  bool? optimisticUnlocked,
}) {
  if (optimisticUnlocked != null) {
    return LessonStudyAccessStatus(
      status: optimisticUnlocked
          ? LessonSheetAccessVisualStatus.unlocked
          : LessonSheetAccessVisualStatus.blocked,
      badgeLabel: optimisticUnlocked ? 'Sbloccata' : 'Bloccata',
      subtitle: optimisticUnlocked
          ? 'Tutte le schede disponibili'
          : 'Lezione non accessibile',
    );
  }

  var anyTrue = false;
  var anyFalse = false;
  for (var s = 1; s <= quizSheets; s++) {
    final on = _sheetUnlockedInList(
      sheetUnlocks,
      categoryId,
      lessonNumber,
      s,
    );
    if (on) {
      anyTrue = true;
    } else {
      anyFalse = true;
    }
  }

  if (anyTrue && anyFalse) {
    return const LessonStudyAccessStatus(
      status: LessonSheetAccessVisualStatus.partial,
      badgeLabel: 'Parziale',
      subtitle: 'Alcune schede disponibili — uniforma con un’azione',
    );
  }
  if (anyTrue) {
    return const LessonStudyAccessStatus(
      status: LessonSheetAccessVisualStatus.unlocked,
      badgeLabel: 'Sbloccata',
      subtitle: 'Tutte le schede disponibili',
    );
  }
  return const LessonStudyAccessStatus(
    status: LessonSheetAccessVisualStatus.blocked,
    badgeLabel: 'Bloccata',
    subtitle: 'Lezione non accessibile',
  );
}

bool _sheetUnlockedInList(
  Iterable<LessonQuizSheetUnlock> sheetUnlocks,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int sheetNumber,
) {
  for (final e in sheetUnlocks) {
    if (e.categoryId == categoryId &&
        e.lessonNumber == lessonNumber &&
        e.sheetNumber == sheetNumber) {
      return e.unlocked;
    }
  }
  return false;
}

/// Card lezione per Accessi studio / dialog gestione schede.
class LessonStudyAccessLessonCard extends StatelessWidget {
  const LessonStudyAccessLessonCard({
    super.key,
    required this.lessonTitle,
    required this.status,
    this.saving = false,
    this.onPrimaryAction,
  });

  final String lessonTitle;
  final LessonStudyAccessStatus status;
  final bool saving;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    lessonTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppVisual.ink,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: status, saving: saving),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: AppVisual.ink.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            if (onPrimaryAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saving ? null : onPrimaryAction,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        status.isUnlockedForAction
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 18,
                      ),
                label: Text(
                  saving ? 'Salvataggio…' : status.primaryActionLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.saving});

  final LessonStudyAccessStatus status;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: status.badgeColor,
              ),
            )
          else
            Icon(status.badgeIcon, size: 14, color: status.badgeColor),
          const SizedBox(width: 6),
          Text(
            saving ? 'Salvataggio' : status.badgeLabel,
            style: textTheme.labelMedium?.copyWith(
              color: status.badgeColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pillole riepilogo lezioni (sbloccate / bloccate / parziali).
class LessonStudyAccessSummaryPills extends StatelessWidget {
  const LessonStudyAccessSummaryPills({
    super.key,
    required this.sheetUnlocks,
    required this.categoryId,
  });

  final List<LessonQuizSheetUnlock> sheetUnlocks;
  final LicenseCategoryId categoryId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = LicenseCatalog.byId(categoryId);
    final lessons =
        category.lessons.where((l) => l.quizSheets > 0).toList(growable: false);

    var unlocked = 0;
    var blocked = 0;
    var partial = 0;
    for (final lesson in lessons) {
      final st = resolveLessonSheetAccessStatus(
        sheetUnlocks: sheetUnlocks,
        categoryId: categoryId,
        lessonNumber: lesson.number,
        quizSheets: lesson.quizSheets,
      );
      switch (st.status) {
        case LessonSheetAccessVisualStatus.unlocked:
          unlocked++;
        case LessonSheetAccessVisualStatus.blocked:
          blocked++;
        case LessonSheetAccessVisualStatus.partial:
          partial++;
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryPill(
          label: 'Sbloccate',
          count: unlocked,
          color: const Color(0xFF2E9E5B),
          textTheme: textTheme,
        ),
        _SummaryPill(
          label: 'Bloccate',
          count: blocked,
          color: const Color(0xFFC62828),
          textTheme: textTheme,
        ),
        if (partial > 0)
          _SummaryPill(
            label: 'Parziali',
            count: partial,
            color: const Color(0xFFC27C1C),
            textTheme: textTheme,
          ),
      ],
    );
  }
}

/// Riepilogo read-only per Scheda 360 → Studio.
class LessonStudyAccessSummaryList extends StatelessWidget {
  const LessonStudyAccessSummaryList({
    super.key,
    required this.sheetUnlocks,
    required this.categoryId,
  });

  final List<LessonQuizSheetUnlock> sheetUnlocks;
  final LicenseCategoryId categoryId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = LicenseCatalog.byId(categoryId);
    final lessons =
        category.lessons.where((l) => l.quizSheets > 0).toList(growable: false);

    if (!category.isAvailable || lessons.isEmpty) {
      return Text(
        'Nessuna lezione nel catalogo per questa categoria.',
        style: textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LessonStudyAccessSummaryPills(
          sheetUnlocks: sheetUnlocks,
          categoryId: categoryId,
        ),
        const SizedBox(height: 12),
        ...lessons.map((lesson) {
          final st = resolveLessonSheetAccessStatus(
            sheetUnlocks: sheetUnlocks,
            categoryId: categoryId,
            lessonNumber: lesson.number,
            quizSheets: lesson.quizSheets,
          );
          return LessonStudyAccessLessonCard(
            lessonTitle: lesson.title,
            status: st,
          );
        }),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.count,
    required this.color,
    required this.textTheme,
  });

  final String label;
  final int count;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.72)),
      ),
      child: Text(
        '$label: $count',
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppVisual.ink,
        ),
      ),
    );
  }
}
