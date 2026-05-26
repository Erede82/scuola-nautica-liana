# Sessione app: studente, staff e avvio

## Modello

- **Autenticazione Supabase** (`auth.users`): JWT condiviso da tutti gli account che usano email/password.
- **Profilo studente** (`students`): opzionale; caricato solo se esiste `auth_user_id` corrispondente.
- **Ruolo scuola** (`school_user_roles`): indipendente dalla tabella `students`; solo `school_admin`, `staff`, `instructor` abilitano il backoffice UI (ruolo `student` in tabella non dà accesso staff).

Aggregazione UI: [`AppAuthSummary`](../lib/models/app_auth_summary.dart) combina `studentSession` + [`StaffAccessSnapshot`](../lib/services/staff_access_service.dart).

## Avvio (`main.dart`)

1. `SupabaseConfig.initialize()`
2. [`bootstrapAppAuth()`](../lib/services/app_auth_bootstrap.dart):
   - `StudentAuthRepository.restoreSessionIfAvailable()` — se c’è JWT, tenta caricamento profilo studente; assenza di riga **non** invalida il JWT.
   - `initializeStaffAccess()` — risolve ruolo staff da `school_user_roles`.

## Login Supabase

Dopo `signInWithPassword`:

- Se esiste riga `students` → `applyStudentSession`.
- Altrimenti → `clearStudentSession`.
- Poi `refreshStaffAccess()`.
- Se **né** studente **né** ruolo staff operativo → `signOut` e messaggio di errore user-facing (account orfano).

## Logout

`StudentAuthRepository.signOut()` esegue `auth.signOut()`, `clearStudentSession()` e `refreshStaffAccess()`.

## Mock locale

Senza Supabase, la “sessione auth” è simulata da `studentSession`; il backoffice in debug può usare comportamenti semplificati.
