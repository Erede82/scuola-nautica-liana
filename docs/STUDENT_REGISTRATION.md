# Registrazione studente (app)

## Flusso attuale (v1)

1. **UI:** `lib/pages/student_registration_page.dart` — form con dati anagrafici, password e scelta **percorso di iscrizione** (`EnrollmentCoursePath`).
2. **Repository:** `StudentAuthRepository` (`lib/repositories/student_auth_repository.dart`).
3. **Selezione implementazione:** `studentAuthRepository` in `lib/repositories/student_auth_registry.dart`:
   - **Supabase** se `SUPABASE_URL` + `SUPABASE_ANON_KEY` sono definiti (`--dart-define`);
   - altrimenti **`StudentAuthRepositoryMock`** (locale).
4. **Mock:** crea `StudentProfile` in `BackofficeDemoStore` e aggiorna `studentSession` / `demoStudentEnrollmentPath`.
5. **Supabase:** `signUp` + RPC `register_student_app` + fetch profilo — vedi **`docs/SUPABASE_AUTH.md`**.

## Stato iniziale

- `StudentRegistrationStatus.pending` — in attesa conferma segreteria.

## Evoluzione

- Sostituire solo l’implementazione dietro `StudentAuthRepository` o estendere la registry per flavor (staging/prod).
