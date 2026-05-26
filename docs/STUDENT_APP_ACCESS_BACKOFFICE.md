# Accesso app allievo creato dalla scuola (backoffice)

## Due flussi separati

### 1. Registrazione autonoma (app studente)

- Schermata: `StudentRegistrationPage`
- Repository: `studentAuthRepository.register()`
- Il dispositivo esegue `auth.signUp` come **futuro allievo**, poi RPC `register_student_app`, che **inserisce** una nuova riga in `public.students` e una in `public.school_user_roles` con `role = 'student'`.

Questo flusso **non** usa l’Edge Function descritta sotto e resta l’unico percorso “mi iscrivo da solo”.

### 2. Nuova pratica + accesso app (segreteria)

- **Anagrafica**: `createBackofficeStudent` (client backoffice) — nessun `signUp`, nessuna modifica sessione admin.
- **Credenziali app**: solo tramite **`create-student-app-access`** (Edge Function), che usa **Admin API** con **service role** lato server (mai nel client Flutter).

**Divieti**

- Non usare `auth.signUp` dal client Flutter **admin** per creare l’account allievo (rischio cambio sessione e violazione modello staff-safe).
- Non embedding della **service role** nell’app Flutter: resta solo nell’ambiente della Edge Function.
- **Password temporanea**: non viene mai salvata in `public.students` né in altre tabelle; è restituita **solo** nel JSON di risposta HTTP della function.

### Sincronizzazione email anagrafica (PATCH 5B1-bis)

L’RPC `link_student_app_access` accetta un terzo argomento opzionale **`p_email`**:

- Se `p_email` è valorizzato (dopo `btrim`), viene normalizzato in **minuscolo** e scritto in **`public.students.email`**, allineando l’anagrafica all’email usata per l’account Supabase Auth creato dalla function.
- Se `p_email` è `NULL` o stringa vuota, la colonna **`students.email` non viene modificata** (comportamento idempotente / chiamate dirette service_role senza aggiornamento email).

La Edge Function **normalizza** l’email nel body (`trim`, `lowercase`, controlli minimi: `@`, dominio con `.`) e passa sempre **`p_email`** uguale all’email usata per `admin.createUser`, così Auth e anagrafica restano coerenti.

## Componenti tecnici

| Componente | Ruolo |
|------------|--------|
| `public.link_student_app_access(p_student_id, p_user_id, p_email)` | RPC `SECURITY DEFINER`: aggiorna `students.user_id`, opz. `students.email`, `auth_user_id` se colonna esiste; inserisce/valida `school_user_roles` con `role = 'student'`. **Eseguibile solo da `service_role`**. |
| `supabase/functions/create-student-app-access` | Verifica JWT staff (`school_user_roles`), crea utente Auth, chiama RPC con email normalizzata, eventuale rollback utente se il link DB fallisce. Risposta JSON con `email` normalizzata e `temporaryPassword` **solo in risposta HTTP**. |

## Configurazione e deploy (manuale)

1. Applicare la migration SQL sul progetto Supabase (es. `supabase db push` o SQL Editor) quando pronti — **non** è incluso deploy automatico in questa patch.
2. Deploy function:  
   `supabase functions deploy create-student-app-access`  
   Valutare `--no-verify-jwt` se la function valida lei il Bearer (come in questo template).
3. Variabili: su hosting Supabase, `SUPABASE_SERVICE_ROLE_KEY` e `SUPABASE_URL` sono tipicamente già disponibili; la function usa anche `SUPABASE_ANON_KEY` per risolvere il chiamante con lo stesso JWT del client.

## Collegamento Flutter (futuro)

- Non usare `functions.invoke` dal client finché non definita UX/policy (es. checkbox “Crea accesso app”, invio email obbligatoria).
- Il client invierà `Authorization: Bearer <JWT staff>` + JSON `{ studentId, email, password? }`.
