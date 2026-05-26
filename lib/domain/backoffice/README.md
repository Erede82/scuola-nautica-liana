# Backoffice domain (Scuola Nautica Liana)

Modelli di dominio per la **gestione scolastica** e per l’allineamento con il **backend unico**
condiviso con l’app mobile studente.

## Principi

1. **Single source of truth** — stessi concetti (allievo, sblocchi, pagamenti) in DB; l’app e il pannello sono viste diverse.
2. **Nessuna UI qui** — solo entity/DTO; schermate admin Flutter/web saranno in altri package/progetti.
3. **Supabase-ready** — tipi pensati per colonne relazionali (`*_id` UUID), importi in centesimi, date esplicite.

## Mappa concettuale

| Dominio | Entity principali | Uso app studente | Uso backoffice |
|--------|-------------------|------------------|----------------|
| Anagrafica | `StudentProfile` | Profilo limitato post-login | CRUD completo, note interne |
| Percorso | `AssignedLesson`, `LessonQuizSheetUnlock`, `ExamQuizAccess`, `ErrorReviewTopicAssignment` | Oggi mock locale `StudyAccessRepository` → domani fetch per studente | Griglia sblocchi, assegnazioni |
| Guida | `GuidanceAppointment` | Lista promemoria / prossime lezioni | Calendario, docente, esiti |
| Esami | `ExamAttempt`, `StudentExamSummary` | Stato “amminssibile” opzionale | Storico tentativi, verbalizzazione |
| Contabilità | `StudentFinancialSummary`, `PaymentReceived` | (Opzionale) saldo sintetico se autorizzato | Incassi, solleciti |
| Documenti | `PracticeLicenseDossier` | (Futuro) stato patente | Gestione pratiche |
| Accessi | `BackofficeUser`, `BackofficeRole` | Ruolo `student` | Admin / staff / instructor |

## Percorso iscrizione vs moduli contenuto

- **`StudentProfile.enrolledCoursePath`** (`EnrollmentCoursePath`): scelta in segreteria / iscrizione (es. Entro 12 miglia, D1, Entro 12 + Vela).
- **`enrolledLicenseCategory`** resta come *getter* di compatibilità: categoria catalogo “principale” derivata dal percorso.
- I **moduli app** (`ContentModuleId`) e la visibilità categorie si derivano con **`EnrollmentContentMapping`** in `lib/domain/enrollment_content_mapping.dart`.
- Dettaglio prodotto: `docs/COURSE_TAXONOMY.md`. Colonna SQL: `students.enrolled_course_path`.

## Allineamento con l’app attuale

- `LicenseCategoryId` è importato da `lib/models/license_models.dart` per non duplicare il catalogo patente.
- Le chiavi “scheda L7-S3” nel dominio (`LessonQuizSheetUnlock`) corrispondono alla logica già usata in
  `StudyAccessRepository` (`lesson:{n}:sheet:{s}`): in migrazione, il repository leggerà le righe per `student_id`.

## Prossimi passi tecnici

- Definire schema SQL / migrations Supabase (tabelle, RLS: studente legge solo `student_id = auth.jwt()`).
- Sostituire mock accessi con query `lesson_quiz_sheet_unlocks` filtrate per studente.
- Progetto UI admin separato (o flavor) che importa `package:.../domain/backoffice/`.
