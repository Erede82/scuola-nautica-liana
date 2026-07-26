// P9C.3-B / P9F-D1.3-B — Piano dry-run seed quiz_sets / quiz_set_items (NON esegue INSERT).
//
// Allineato a:
//   - lib/data/license_catalog.dart (conteggio schede per lezione)
//   - lib/domain/quiz_sheet_slicing.dart (rotazione deterministica)
//   - lib/domain/lesson_quiz_rules.dart (domande per scheda: A12=20, D1=15)
//   - supabase/seed/quiz_lesson_sets.sql (seed SQL idempotente)
//
// Uso:
//   dart run tool/seed_quiz_lesson_sets.dart
//   dart run tool/seed_quiz_lesson_sets.dart --pools-from=path/questions_export.json
//
// Il tool NON si connette al DB e NON scrive dati remoti.
// Per applicare il seed in futuro (solo dopo approvazione):
//   1. supabase db push   (migration)
//   2. psql / supabase db query --file supabase/seed/quiz_lesson_sets.sql

import 'dart:convert';
import 'dart:io';

import 'package:scuola_nautica_liana/domain/quiz_sheet_slicing.dart';

/// Schede per lezione — deve restare allineato a LicenseCatalog.patenteMotore.lessons.
const _lessonSheetCounts = <int, int>{
  1: 24,
  2: 24,
  3: 24,
  4: 28,
  5: 20,
  6: 20,
  7: 36,
  8: 20,
  9: 20,
  10: 16,
  11: 28,
  12: 16,
  13: 16,
  14: 36,
};

const _seedLicenseCategories = ['A12', 'D1'];

/// Pool A12 da P9C.1 (read-only). Usato per stima items senza export JSON.
const _a12PoolSizesP9C1 = <int, int>{
  1: 101,
  2: 101,
  3: 88,
  4: 116,
  5: 80,
  6: 100,
  7: 167,
  8: 120,
  9: 62,
  10: 60,
  11: 103,
  12: 98,
  13: 63,
  14: 165,
};

/// Lezioni D1 senza domande nel catalogo operativo (0 set / 0 item).
const _d1LessonsWithoutPool = <int>{11, 12, 13, 14};

void main(List<String> args) {
  final poolsPath = _argValue(args, '--pools-from');
  final poolsByCategoryLesson = poolsPath == null
      ? null
      : _loadPoolsFromExport(poolsPath);

  var totalSets = 0;
  var totalItems = 0;
  var skippedSetsNoPool = 0;

  stdout.writeln(
    'P9C.3-B / P9F-D1.3-B — Piano seed quiz_sets (dry-run, nessun INSERT)\n',
  );

  for (final licenseCategory in _seedLicenseCategories) {
    final questionsPerSheet = _questionsPerSheetForDbCategory(licenseCategory);
    var categorySets = 0;
    var categoryItems = 0;

    for (final entry in _lessonSheetCounts.entries) {
      final lessonNumber = entry.key;
      final sheetCount = entry.value;
      final poolSize = _estimatedPoolSize(
        licenseCategory: licenseCategory,
        lessonNumber: lessonNumber,
        poolsByCategoryLesson: poolsByCategoryLesson,
      );

      if (poolSize == 0) {
        skippedSetsNoPool += sheetCount;
        continue;
      }

      categorySets += sheetCount;

      for (var sheetNumber = 1; sheetNumber <= sheetCount; sheetNumber++) {
        final indices = sliceLessonSheetQuestionIndices(
          poolLength: poolSize,
          sheetNumber: sheetNumber,
          limit: questionsPerSheet,
        );
        categoryItems += indices.length;

        final uniqueInSheet = indices.toSet().length;
        if (poolSize >= questionsPerSheet && uniqueInSheet != indices.length) {
          stderr.writeln(
            'WARN: duplicato in scheda $licenseCategory L$lessonNumber '
            'S$sheetNumber (pool=$poolSize; $licenseCategory richiede almeno '
            '$questionsPerSheet domande)',
          );
        }
      }
    }

    stdout.writeln(
      '$licenseCategory: $categorySets quiz_sets, $categoryItems quiz_set_items '
      'stimati ($questionsPerSheet item per set)',
    );
    totalSets += categorySets;
    totalItems += categoryItems;
  }

  final catalogSheetsPerCategory = _lessonSheetCounts.values.fold<int>(
    0,
    (a, b) => a + b,
  );

  stdout.writeln('\n--- Riepilogo ---');
  stdout.writeln(
    'Schede per categoria (catalogo Flutter): $catalogSheetsPerCategory',
  );
  stdout.writeln('Categorie seed: ${_seedLicenseCategories.length}');
  stdout.writeln('quiz_sets stimati: $totalSets');
  stdout.writeln('quiz_set_items stimati: $totalItems');
  if (skippedSetsNoPool > 0) {
    stdout.writeln('Set saltati (pool vuoto): $skippedSetsNoPool');
  }

  stdout.writeln('\nSeed preparato: supabase/seed/quiz_lesson_sets.sql');
  stdout.writeln('\nNON eseguito: db push, INSERT, seed live.');
}

/// Domande per scheda allineate a `LessonQuizRules` (motore/A12=20, d1/D1=15).
///
/// Non importa `lib/domain/lesson_quiz_rules.dart` direttamente: quella API
/// dipende da `license_models.dart` → `package:flutter/material.dart`,
/// incompatibile con `dart run tool/...` (CLI senza binding Flutter).
int _questionsPerSheetForDbCategory(String licenseCategory) {
  switch (licenseCategory) {
    case 'A12':
      return 20; // LessonQuizRules.a12 / LicenseCategoryId.motore
    case 'D1':
      return 15; // LessonQuizRules.d1 / LicenseCategoryId.d1
    default:
      throw StateError(
        'Categoria seed non supportata: $licenseCategory '
        '(attese esplicite: A12, D1; nessun fallback)',
      );
  }
}

/// Stima dimensione pool domande per (categoria, lezione).
///
/// Non confondere con [_questionsPerSheetForDbCategory]: qui si stima quante
/// domande esistono nel pool della lezione, non quante ne vanno in una scheda.
int _estimatedPoolSize({
  required String licenseCategory,
  required int lessonNumber,
  required Map<String, Map<int, int>>? poolsByCategoryLesson,
}) {
  if (poolsByCategoryLesson != null) {
    return poolsByCategoryLesson[licenseCategory]?[lessonNumber] ?? 0;
  }
  if (licenseCategory == 'A12') {
    return _a12PoolSizesP9C1[lessonNumber] ?? 0;
  }
  if (licenseCategory == 'D1') {
    // Senza export: lezioni 11–14 restano senza domande (0 set), come nel seed.
    // Per lezioni 1–10 si usa una stima = domande per scheda (pool >= 15).
    if (_d1LessonsWithoutPool.contains(lessonNumber)) return 0;
    return _questionsPerSheetForDbCategory('D1');
  }
  throw StateError(
    'Categoria seed non supportata per stima pool: $licenseCategory',
  );
}

Map<String, Map<int, int>> _loadPoolsFromExport(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('ERRORE: file non trovato: $path');
    exit(2);
  }

  final raw = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  final counts = <String, Map<int, int>>{};

  for (final row in raw) {
    final map = Map<String, dynamic>.from(row as Map);
    final category = map['license_category'] as String?;
    final lesson = map['lesson_number'];
    if (category == null || lesson == null) continue;
    final lessonNumber = lesson is int ? lesson : int.parse('$lesson');
    counts.putIfAbsent(category, () => {});
    counts[category]![lessonNumber] =
        (counts[category]![lessonNumber] ?? 0) + 1;
  }

  return counts;
}

String? _argValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$name=')) {
      return args[i].substring(name.length + 1);
    }
  }
  return null;
}
