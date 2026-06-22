import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/study_progress_row_mappers.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/backoffice/backoffice.dart';
import '../repositories/study_access_repository.dart';

const Duration _kSyncStudyAccessTimeout = Duration(seconds: 25);

/// Allinea il repository accessi studio in memoria con le tabelle Supabase
/// (`lesson_quiz_sheet_unlocks`, `exam_quiz_access`, `error_review_topic_assignments`)
/// per lo studente indicato — necessario perché D1/motore usano `license_category` in DB.
///
/// Chiamare dopo login / ripristino sessione JWT così le abilitazioni della segreteria
/// (incluso percorso D1) si riflettono subito nell’app.
Future<void> syncStudyAccessFromSupabaseForStudent(StudentId studentId) async {
  if (!SupabaseConfig.isConfigured) {
    if (kDebugMode) {
      qfLog('Supabase sync: skip (not configured) studentId=$studentId');
    }
    return;
  }

  if (kDebugMode) {
    qfLog('Supabase sync: start (3 parallel SELECT) studentId=$studentId');
  }

  // A failed remote sync must not leave another account's in-memory grants active.
  studyAccessWritableRepository.resetDemoAssignments();

  try {
    final client = Supabase.instance.client;
    final batch = await Future.wait<dynamic>([
      client.from('lesson_quiz_sheet_unlocks').select().eq('student_id', studentId),
      client.from('exam_quiz_access').select().eq('student_id', studentId),
      client.from('error_review_topic_assignments').select().eq('student_id', studentId),
    ]).timeout(_kSyncStudyAccessTimeout);

    if (kDebugMode) {
      final n0 = (batch[0] as List<dynamic>).length;
      final n1 = (batch[1] as List<dynamic>).length;
      final n2 = (batch[2] as List<dynamic>).length;
      qfLog(
        'Supabase sync: batch OK — lesson_quiz_sheet_unlocks=$n0, '
        'exam_quiz_access=$n1, error_review_topic_assignments=$n2',
      );
    }

    final sheets = (batch[0] as List<dynamic>)
        .map(
          (e) => mapLessonQuizSheetUnlockFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);

    final exams = (batch[1] as List<dynamic>)
        .map(
          (e) => mapExamQuizAccessFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);

    final errs = (batch[2] as List<dynamic>)
        .map(
          (e) => mapErrorReviewTopicFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);

    if (kDebugMode) {
      qfLog(
        'Supabase sync: mapped records — sheetUnlocks=${sheets.length}, '
        'exams=${exams.length}, errReview=${errs.length} → hydrating repo',
      );
    }

    final bundle = StudentStudyProgressBundle(
      studentId: studentId,
      assignedLessons: const [],
      sheetUnlocks: sheets,
      examAccessByCategory: exams,
      errorReviewAssignments: errs,
    );

    studyAccessWritableRepository.hydrateFromRemoteStudyProgress(bundle);
    if (kDebugMode) {
      qfLog('Supabase sync: done (UI may rebuild via studyAccessListenable)');
    }
  } on TimeoutException catch (e, st) {
    if (kDebugMode) {
      qfLog(
        'Supabase sync: TIMEOUT after ${_kSyncStudyAccessTimeout.inSeconds}s '
        '(hung network?)',
        e,
        st,
      );
    }
    // Best-effort: non bloccare login / quiz con cache precedente
  } catch (e, st) {
    if (kDebugMode) {
      qfLog('Supabase sync: error (best-effort, ignored)', e, st);
    }
  }
}
