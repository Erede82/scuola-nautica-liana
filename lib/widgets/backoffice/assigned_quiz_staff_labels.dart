import '../../models/assigned_quiz_models.dart';

/// Etichette IT per la UI staff dei quiz assegnati.
abstract final class AssignedQuizStaffLabels {
  static String status(AssignedQuizStatus status) {
    switch (status) {
      case AssignedQuizStatus.draft:
        return 'Bozza';
      case AssignedQuizStatus.assigned:
        return 'Assegnato';
      case AssignedQuizStatus.archived:
        return 'Archiviato';
    }
  }

  static String attemptStatus(AssignedQuizAttemptStatus status) {
    switch (status) {
      case AssignedQuizAttemptStatus.inProgress:
        return 'In corso';
      case AssignedQuizAttemptStatus.submitted:
        return 'Inviato';
      case AssignedQuizAttemptStatus.abandoned:
        return 'Abbandonato';
    }
  }

  static String repeatPolicy(
    AssignedQuizRepeatPolicy policy,
    int? maxAttempts,
  ) {
    switch (policy) {
      case AssignedQuizRepeatPolicy.unlimited:
        return 'Tentativi illimitati';
      case AssignedQuizRepeatPolicy.limited:
        final n = maxAttempts ?? 0;
        return 'Massimo $n tentativ${n == 1 ? 'o' : 'i'}';
    }
  }

  static String categoryBadge(String licenseCategory) {
    final raw = licenseCategory.trim().toUpperCase();
    if (raw == 'A12' || raw == 'D1') return raw;
    return raw.isEmpty ? '—' : raw;
  }

  static String formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    return '$dd/$mm/$yyyy';
  }

  static String formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  static String formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static bool isExpired(DateTime? expiresAt, {DateTime? now}) {
    if (expiresAt == null) return false;
    return !expiresAt.toUtc().isAfter((now ?? DateTime.now()).toUtc());
  }

  static String generationSuccessSnack(AssignedQuizGenerationResult result) {
    final stato = status(result.status).toLowerCase();
    return 'Quiz ${result.publicCode} $stato con ${result.itemCount} domande.';
  }
}
