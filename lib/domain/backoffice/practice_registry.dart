import 'ids.dart';
import 'student_profile.dart';

/// Esito RPC [assign_practice_registry_number] (jsonb).
class PracticeRegistryAssignment {
  const PracticeRegistryAssignment({
    required this.practiceDossierId,
    required this.registrationDate,
    required this.registryYear,
    required this.registryNumber,
    required this.registryCode,
  });

  final PracticeDossierId practiceDossierId;
  final DateTime registrationDate;
  final int registryYear;
  final int registryNumber;
  final String registryCode;

  factory PracticeRegistryAssignment.fromRpc(dynamic raw) {
    if (raw is! Map) {
      throw StateError('Risposta RPC registro pratica non valida.');
    }
    final m = Map<String, dynamic>.from(raw);
    final id = m['practice_dossier_id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Risposta RPC registro pratica: id mancante.');
    }
    final regRaw = m['registration_date'];
    final DateTime regDate = switch (regRaw) {
      final String s => DateTime.parse(s),
      final DateTime d => d,
      _ => throw StateError('Risposta RPC: registration_date non valida.'),
    };
    final yRaw = m['registry_year'];
    final nRaw = m['registry_number'];
    final y = yRaw is int ? yRaw : (yRaw is num ? yRaw.toInt() : null);
    final n = nRaw is int ? nRaw : (nRaw is num ? nRaw.toInt() : null);
    final code = m['registry_code'] as String?;
    if (y == null || n == null || code == null || code.isEmpty) {
      throw StateError('Risposta RPC: campi registro incompleti.');
    }
    return PracticeRegistryAssignment(
      practiceDossierId: id,
      registrationDate: regDate,
      registryYear: y,
      registryNumber: n,
      registryCode: code,
    );
  }
}

/// Risultato creazione allievo da backoffice (anagrafica + opz. numero registro).
class BackofficeNewStudentOutcome {
  const BackofficeNewStudentOutcome({
    required this.profile,
    this.assignedRegistryCode,
    this.registryAssignmentNote,
  });

  final StudentProfile profile;
  final String? assignedRegistryCode;
  final String? registryAssignmentNote;
}
