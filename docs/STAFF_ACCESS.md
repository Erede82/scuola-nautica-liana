# Accesso staff (backoffice)

## Componenti

| File | Ruolo |
|------|--------|
| [`lib/repositories/staff_role_repository.dart`](../lib/repositories/staff_role_repository.dart) | Contratto: ruolo da `school_user_roles` |
| [`lib/repositories/staff_role_repository_supabase.dart`](../lib/repositories/staff_role_repository_supabase.dart) | Query PostgREST per `auth.uid()` |
| [`lib/repositories/staff_role_registry.dart`](../lib/repositories/staff_role_registry.dart) | Singleton repository |
| [`lib/services/staff_access_service.dart`](../lib/services/staff_access_service.dart) | `staffAccessNotifier`, `initializeStaffAccess()`, `refreshStaffAccess()` |
| [`lib/widgets/staff/staff_access_gate.dart`](../lib/widgets/staff/staff_access_gate.dart) | UI: caricamento / login richiesto / non autorizzato / contenuto |
| [`lib/pages/backoffice/backoffice_entry_page.dart`](../lib/pages/backoffice/backoffice_entry_page.dart) | Gate + `SchoolManagementShellPage` |

## Comportamento

1. All’avvio (`main.dart`), dopo `restoreSessionIfAvailable`, viene chiamato `initializeStaffAccess()` che esegue la prima `refreshStaffAccess()`.
2. Con **Supabase** attivo: ascolto `auth.onAuthStateChange` e aggiornamenti a `studentSession` (login mock / idratazione profilo).
3. Ruoli che aprono il backoffice: `school_admin`, `staff`, `instructor` in `public.school_user_roles.role`. Il ruolo `student` non consente l’accesso UI staff.
4. **Senza Supabase** (solo mock): in **release** nessun accesso staff; in **debug**, con sessione studente mock attiva, viene concesso un ruolo fittizio per sviluppo locale.

## RLS

La policy `school_roles_select_own` consente a ogni utente autenticato di leggere la propria riga in `school_user_roles`, necessaria per la risoluzione del ruolo.

## Messaggi UI (italiano)

- Verifica permessi in corso…
- Accesso staff richiesto
- Non sei autorizzato ad accedere a questa area.
- Accesso effettuato come staff · …
