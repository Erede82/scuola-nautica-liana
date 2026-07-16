/// Stati e policy del modulo Quiz assegnati dalla scuola.
library;

/// Stato assegnazione (`assigned_quizzes.status`).
enum AssignedQuizStatus {
  draft,
  assigned,
  archived;

  static AssignedQuizStatus? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'draft':
        return AssignedQuizStatus.draft;
      case 'assigned':
        return AssignedQuizStatus.assigned;
      case 'archived':
        return AssignedQuizStatus.archived;
      default:
        return null;
    }
  }

  String get dbValue {
    switch (this) {
      case AssignedQuizStatus.draft:
        return 'draft';
      case AssignedQuizStatus.assigned:
        return 'assigned';
      case AssignedQuizStatus.archived:
        return 'archived';
    }
  }
}

/// Policy ripetizione tentativi (`assigned_quizzes.repeat_policy`).
enum AssignedQuizRepeatPolicy {
  unlimited,
  limited;

  static AssignedQuizRepeatPolicy? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'unlimited':
        return AssignedQuizRepeatPolicy.unlimited;
      case 'limited':
        return AssignedQuizRepeatPolicy.limited;
      default:
        return null;
    }
  }

  String get dbValue {
    switch (this) {
      case AssignedQuizRepeatPolicy.unlimited:
        return 'unlimited';
      case AssignedQuizRepeatPolicy.limited:
        return 'limited';
    }
  }
}

/// Stato tentativo (`assigned_quiz_attempts.status`).
enum AssignedQuizAttemptStatus {
  inProgress,
  submitted,
  abandoned;

  static AssignedQuizAttemptStatus? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'in_progress':
        return AssignedQuizAttemptStatus.inProgress;
      case 'submitted':
        return AssignedQuizAttemptStatus.submitted;
      case 'abandoned':
        return AssignedQuizAttemptStatus.abandoned;
      default:
        return null;
    }
  }

  String get dbValue {
    switch (this) {
      case AssignedQuizAttemptStatus.inProgress:
        return 'in_progress';
      case AssignedQuizAttemptStatus.submitted:
        return 'submitted';
      case AssignedQuizAttemptStatus.abandoned:
        return 'abandoned';
    }
  }
}

/// Filtro lezioni in generazione (`lesson_filter_mode`).
enum AssignedQuizLessonFilterMode {
  allLessons,
  selectedLessons;

  static AssignedQuizLessonFilterMode? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'all_lessons':
        return AssignedQuizLessonFilterMode.allLessons;
      case 'selected_lessons':
        return AssignedQuizLessonFilterMode.selectedLessons;
      default:
        return null;
    }
  }

  String get dbValue {
    switch (this) {
      case AssignedQuizLessonFilterMode.allLessons:
        return 'all_lessons';
      case AssignedQuizLessonFilterMode.selectedLessons:
        return 'selected_lessons';
    }
  }
}

/// Ordinamento selezione errori (`sort_mode`).
enum AssignedQuizSortMode {
  mostWrong,
  mostRecent;

  static AssignedQuizSortMode? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'most_wrong':
        return AssignedQuizSortMode.mostWrong;
      case 'most_recent':
        return AssignedQuizSortMode.mostRecent;
      default:
        return null;
    }
  }

  String get dbValue {
    switch (this) {
      case AssignedQuizSortMode.mostWrong:
        return 'most_wrong';
      case AssignedQuizSortMode.mostRecent:
        return 'most_recent';
    }
  }
}
