# Backoffice Scuola — fondazione Supabase

Questo documento descrive lo schema SQL, il mapping verso il dominio Flutter (`lib/domain/backoffice/`) e il percorso di migrazione dal mock attuale.

## Migrazione SQL

- **File:** `supabase/migrations/20260320000000_backoffice_foundation.sql`
- Applica con Supabase CLI (`supabase db push` / pipeline remota) o incolla nel SQL Editor del progetto.

### Tabelle principali

| Tabella Postgres | Dominio Dart (riferimento) |
|------------------|----------------------------|
| `students` | `StudentProfile` |
| `student_financial_summaries` | `StudentFinancialSummary` |
| `lesson_quiz_sheet_unlocks` | `LessonQuizSheetUnlock` |
| `exam_quiz_access` | `ExamQuizAccess` |
| `error_review_topic_assignments` | `ErrorReviewTopicAssignment` |
| `guidance_appointments` | `GuidanceAppointment` |
| `exam_attempts` | `ExamAttempt` |
| `payments` | `PaymentReceived` |
| `practice_dossiers` | `PracticeLicenseDossier` |
| `staff_internal_notes` | `StaffInternalNote` |
| `backoffice_activity_events` | `BackofficeActivityEvent` |
| `school_user_roles` | ruoli JWT / RLS (non ancora modello Dart dedicato) |

### Convenzioni

- **ID:** UUID (`gen_random_uuid()`).
- **Importi:** `amount_cents`, `registration_fee_cents`, ecc. (allineato al dominio).
- **Patente / enum testuali:** valori stringa uguali a `Enum.name` in Dart (`motore`, `pending`, `paymentAdded`, …).
- **Indirizzo:** `students.address` JSONB mappabile a `PostalAddress` (chiavi snake_case o camelCase supportate nel mapper).

## RLS (indicazioni)

- Funzioni helper: `is_school_staff()`, `is_own_student(student_id)`.
- **Studente:** lettura dati legati al proprio `students.id` / `auth_user_id` (con policy per tabella; pagamenti in prima versione solo staff).
- **Staff:** CRUD sulle tabelle operative; `school_user_roles` assegna `school_admin` | `staff` | `instructor`.

Vedi commenti `TODO` nella migration per ricevute studente, fascicolo pratica lato studente, ecc.

## Layer repository Flutter

| Componente | Ruolo |
|------------|--------|
| `lib/repositories/backoffice/backoffice_repository.dart` | Contratto async (UI-agnostico). |
| `lib/repositories/backoffice/backoffice_repository_mock.dart` | Delega a `BackofficeDemoStore` (fallback / scritture demo). |
| `lib/repositories/backoffice/backoffice_repository_supabase.dart` | Lettura e scrittura PostgREST (vedi `docs/BACKOFFICE_READS.md`). |
| `lib/repositories/backoffice/backoffice_registry.dart` | `backofficeRepository` — sceglie Supabase vs mock in base a `SupabaseConfig`. |

**Oggi:** la shell backoffice (`SchoolManagementShellPage`) usa `backofficeRepository` per elenco e scheda 360°. Vedi **`docs/BACKOFFICE_READS.md`**.

Implementazione `BackofficeRepositorySupabase`:
1. `supabase_flutter` + PostgREST;
2. righe → DTO `lib/data/supabase/dto/backoffice_rows.dart`;
3. dominio con `lib/data/supabase/mappers/backoffice_row_mappers.dart` e `study_progress_row_mappers.dart`;
4. `getStudentAdmin360` compone più query in parallelo come `BackofficeDemoStore.aggregateFor`.

### Accessi studio (app allievo)

Il percorso **studio/quiz** resta su `StudyAccessRepository` / `MutableMockStudyAccessRepository`. In produzione:

- o si **sincronizza** dalle stesse tabelle `lesson_quiz_sheet_unlocks`, `exam_quiz_access`, `error_review_topic_assignments` tramite un adapter che implementa `StudyAccessRepository`;
- o si mantiene un **edge function** che espone snapshot compatibile con il contratto esistente.

Non è obbligatorio unificare in questo step.

## Dipendenze

Il progetto include `supabase_flutter` (vedi `pubspec.yaml`) per auth studente e lettura backoffice.

## Checklist migrazione mock → live

1. Applicare migration su progetto Supabase.
2. Popolare `school_user_roles` e collegare `students.auth_user_id`.
3. Importare seed o migrare dati demo.
4. ~~Implementare `BackofficeRepositorySupabase`.~~ **Fatto (lettura + scrittura principali).**
5. (Opzionale) RPC transazionali, affinare RLS, policy pagamenti lato studente.
6. (Opzionale) `Provider` / `get_it` per injection esplicita in test.
