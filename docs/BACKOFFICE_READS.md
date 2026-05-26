# Backoffice: Supabase vs mock

## Switch centralizzato

`lib/repositories/backoffice/backoffice_registry.dart` espone:

- **`backofficeRepository`** → [`BackofficeRepositorySupabase`](lib/repositories/backoffice/backoffice_repository_supabase.dart) se `SUPABASE_URL` e `SUPABASE_ANON_KEY` sono definiti (`SupabaseConfig.isConfigured`).
- Altrimenti → [`BackofficeRepositoryMock`](lib/repositories/backoffice/backoffice_repository_mock.dart) (dati in `BackofficeDemoStore`).

L’ingresso UI è [`BackofficeEntryPage`](lib/pages/backoffice/backoffice_entry_page.dart) ([`StaffAccessGate`](lib/widgets/staff/staff_access_gate.dart)); la shell [`SchoolManagementShellPage`](lib/pages/backoffice/school_management_shell_page.dart) usa **solo** `backofficeRepository` per elenco, scheda 360° e mutazioni. Vedi anche **`docs/STAFF_ACCESS.md`**.

## Lettura (live su Supabase)

Con Supabase configurato e JWT con permessi adeguati (tipicamente **staff** via `school_user_roles` + `is_school_staff()`):

| Area | Fonte |
|------|--------|
| Elenco allievi | `students` ordinato per cognome |
| Riga secondaria (saldo / ultimo esame) | `getStudentAdmin360` in batch dopo l’elenco |
| Scheda 360° | Stesse tabelle della migration foundation |
| Percorso studio | `lesson_quiz_sheet_unlocks`, `exam_quiz_access`, `error_review_topic_assignments`; **lezioni assegnate** (`assignedLessons`) restano vuote senza tabella dedicata |

Se manca `student_financial_summaries`, la lettura costruisce comunque un riepilogo a zero; al **primo pagamento** viene creata la riga se assente.

## Scrittura (live su Supabase)

Con Supabase configurato, [`BackofficeRepositorySupabase`](lib/repositories/backoffice/backoffice_repository_supabase.dart) persiste su Postgres:

| Operazione | Tabelle / note |
|------------|------------------|
| Note interne staff | `staff_internal_notes` + evento in `backoffice_activity_events` |
| Pagamenti | `payments` + aggiornamento `student_financial_summaries` (centesimi) |
| Guide | `guidance_appointments` |
| Esami | `exam_attempts` (numero tentativo calcolato se non in conflitto con vincolo UNIQUE) |
| Pratica / documenti | `practice_dossiers` (upsert su `student_id`) |
| Accessi studio | `lesson_quiz_sheet_unlocks`, `exam_quiz_access`, `error_review_topic_assignments` |
| Note anagrafiche legacy | `students.internal_notes` + evento attività |
| Evento audit manuale | `appendActivityEvent` → `backoffice_activity_events` (tipi non presenti nel CHECK SQL, es. `studentRegisteredFromApp`, vengono ignorati) |

Dopo ogni salvataggio, la UI ricarica la scheda tramite `onRefreshDetail` / `getStudentAdmin360`.

**Allineamento app demo:** per `SchoolBackofficeDemoData.demoStudentLucia`, le modifiche agli accessi studio aggiornano anche `studyAccessWritableRepository` (come nel mock).

## Modalità mock (nessun Supabase)

- Tutte le operazioni passano ancora da [`BackofficeRepositoryMock`](lib/repositories/backoffice/backoffice_repository_mock.dart) → `BackofficeDemoStore` in memoria.

## RLS e ruoli

Le policy della migration foundation richiedono `is_school_staff()` per INSERT/UPDATE sulle tabelle backoffice. L’utente deve avere un record in `school_user_roles` con `school_admin`, `staff` o `instructor` collegato al proprio `auth.uid()`.

## Prossimi passi possibili

- Transazioni server-side (RPC) per pagamento + riepilogo in un solo round-trip.
- Esposizione controllata di movimenti pagamenti lato studente (policy dedicate).
- Tabella `assigned_lessons` e popolamento `StudentStudyProgressBundle.assignedLessons`.
