# Autenticazione Supabase (app studente)

## Configurazione Flutter

1. Crea un progetto su [Supabase](https://supabase.com) e applica le migrazioni in `supabase/migrations/`.
2. Leggi **URL** e **anon public key** da *Project Settings → API*.
3. Avvia l’app con:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon_key>
```

Se `SUPABASE_URL` o `SUPABASE_ANON_KEY` sono vuoti, l’app usa **`StudentAuthRepositoryMock`** (nessun backend). Vedi `lib/config/supabase_config.dart` e `lib/repositories/student_auth_registry.dart`.

## Flusso registrazione (signup)

1. Client: `supabase.auth.signUp(email, password)`.
2. Se **non** c’è sessione JWT (es. **email confirmation** attiva in Auth), l’app **non** può chiamare la RPC profilo: viene mostrato un messaggio che invita a confermare l’email. In quel caso **non** esiste ancora riga in `public.students` finché non si completa un flusso alternativo (es. conferma + login + completamento manuale da segreteria, o conferma disattivata in dev).
3. Con sessione attiva (tipico se **Confirm email** è **disattivato** in *Authentication → Providers → Email* per ambienti di test):
4. Client chiama la RPC **`register_student_app`** (`supabase/migrations/20260321120000_student_app_registration_rpc.sql`):
   - inserisce `public.students` (`auth_user_id`, dati anagrafici, `enrolled_course_path`, `enrolled_license_category`, `registration_status = pending`);
   - inserisce `public.school_user_roles` (`user_id`, `role = student`, `student_id`).
5. In caso di errore sulla RPC, l’app esegue **`signOut()`** sull’utente appena creato per evitare account “orfani” senza profilo caricabile (recovery: ripetere registrazione o cancellare l’utente da *Authentication* in dashboard).

## Flusso login (sign in)

1. `supabase.auth.signInWithPassword(email, password)`.
2. Select su `public.students` con `auth_user_id = auth.uid()` (RLS: lettura consentita se `is_own_student`).
3. Se non esiste riga studente: logout e messaggio “Profilo studente non trovato…”.

## Mappatura Auth → DB

| Supabase Auth | `public.students` | `public.school_user_roles` |
|---------------|-------------------|------------------------------|
| `auth.users.id` | `students.auth_user_id` | `school_user_roles.user_id` |
| — | `students.id` (UUID) | `school_user_roles.student_id` |

Ruolo applicativo: **`student`**.

## Sessione app (Flutter)

- `StudentAuthRepository.restoreSessionIfAvailable()` all’avvio (`main.dart`): se c’è sessione JWT valida, ricarica il profilo e aggiorna `studentSession` + `demoStudentEnrollmentPath`.
- Logout: `signOut()` + `clearStudentSession()` (`lib/services/demo_student_enrollment.dart`).

## Assunzioni email / conferma

- **Sviluppo:** disattivare la conferma email in Supabase per testare signup + RPC in un solo passo.
- **Produzione:** con conferma email attiva, pianificare conferma utente poi accesso, oppure Edge Function con `service_role`, oppure trigger su `auth.users` — non incluso in questa v1 client-only.

## Contenuti e percorso

Il percorso prodotto resta `enrolled_course_path` + mapping in `lib/domain/enrollment_content_mapping.dart` (vedi `docs/COURSE_TAXONOMY.md`).
